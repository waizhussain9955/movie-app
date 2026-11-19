package com.example.streammax_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.view.KeyEvent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private val UPDATER_CHANNEL = "com.waiz.streammax/updater"
    private val AUDIO_CHANNEL = "com.waiz.streammax/audio"

    private var audioChannel: MethodChannel? = null
    private var interceptVolumeKeys = false
    private var volumeReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Updater channel (APK installation)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            if (file.exists()) {
                                val intent = Intent(Intent.ACTION_VIEW).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                                    val uri: Uri = FileProvider.getUriForFile(
                                        context,
                                        "${context.packageName}.fileprovider",
                                        file
                                    )
                                    setDataAndType(uri, "application/vnd.android.package-archive")
                                }
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.error("FILE_NOT_FOUND", "APK file does not exist at $filePath", null)
                            }
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.localizedMessage, null)
                        }
                    } else {
                        result.error("INVALID_ARG", "filePath is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 2. Hardware Audio & Volume channel
        val audioMgr = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getVolume" -> {
                        val current = audioMgr.getStreamVolume(AudioManager.STREAM_MUSIC)
                        val max = audioMgr.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        val percent = if (max > 0) current.toDouble() / max.toDouble() else 1.0
                        result.success(percent)
                    }
                    "setVolume" -> {
                        val vol = call.argument<Double>("volume") ?: 1.0
                        val max = audioMgr.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        val target = (vol.coerceIn(0.0, 1.0) * max).roundToInt()
                        audioMgr.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
                        val current = audioMgr.getStreamVolume(AudioManager.STREAM_MUSIC)
                        val percent = if (max > 0) current.toDouble() / max.toDouble() else 1.0
                        result.success(percent)
                    }
                    "setInterceptVolumeKeys" -> {
                        interceptVolumeKeys = call.argument<Boolean>("enabled") ?: false
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        registerVolumeReceiver()
    }

    private fun registerVolumeReceiver() {
        if (volumeReceiver != null) return
        volumeReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "android.media.VOLUME_CHANGED_ACTION") {
                    val audioMgr = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
                    val current = audioMgr.getStreamVolume(AudioManager.STREAM_MUSIC)
                    val max = audioMgr.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val percent = if (max > 0) current.toDouble() / max.toDouble() else 1.0
                    runOnUiThread {
                        audioChannel?.invokeMethod("onVolumeChanged", percent)
                    }
                }
            }
        }
        val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(volumeReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(volumeReceiver, filter)
            }
        } catch (e: Exception) {
            try {
                registerReceiver(volumeReceiver, filter)
            } catch (e2: Exception) {}
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (interceptVolumeKeys) {
            val keyCode = event.keyCode
            if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    val audioMgr = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val direction = if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) AudioManager.ADJUST_RAISE else AudioManager.ADJUST_LOWER
                    audioMgr.adjustStreamVolume(AudioManager.STREAM_MUSIC, direction, 0)
                    val current = audioMgr.getStreamVolume(AudioManager.STREAM_MUSIC)
                    val max = audioMgr.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val percent = if (max > 0) current.toDouble() / max.toDouble() else 1.0
                    runOnUiThread {
                        audioChannel?.invokeMethod("onVolumeChanged", percent)
                    }
                }
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onDestroy() {
        volumeReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {}
            volumeReceiver = null
        }
        super.onDestroy()
    }
}
