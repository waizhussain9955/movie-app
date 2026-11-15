

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String title;
  final List<String> changelog;
  final bool forceUpdate;
  final double? fileSizeMb;

  AppUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.title,
    required this.changelog,
    this.forceUpdate = false,
    this.fileSizeMb,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      versionCode: json['version_code'] as int? ?? 1,
      versionName: json['version_name'] as String? ?? '1.0.0',
      apkUrl: json['apk_url'] as String? ?? '',
      title: json['title'] as String? ?? 'New Update Available',
      changelog: (json['changelog'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      forceUpdate: json['force_update'] as bool? ?? false,
      fileSizeMb: (json['file_size_mb'] as num?)?.toDouble(),
    );
  }
}

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  static const String currentVersion = '1.0.0';
  static const int currentVersionCode = 1;

  static const MethodChannel _channel = MethodChannel('com.waiz.streammax/updater');

  // Primary update URL hosted on GitHub raw repository
  static const String updateConfigUrl =
      'https://raw.githubusercontent.com/waizhussain9955/movie-app/main/version.json';

  Future<AppUpdateInfo?> fetchLatestVersion() async {
    try {
      final response = await http
          .get(Uri.parse(updateConfigUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return AppUpdateInfo.fromJson(data);
      }
    } catch (e) {
      debugPrint('[UpdateService] Failed to check for update: $e');
    }
    return null;
  }

  Future<void> checkUpdate(BuildContext context, {bool silent = false}) async {
    final info = await fetchLatestVersion();

    if (!context.mounted) return;

    if (info != null && info.versionCode > currentVersionCode) {
      _showUpdateDialog(context, info);
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 10),
              Text(
                'StreamMax is up to date (v$currentVersion)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1B2230),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<bool> installApk(String filePath) async {
    try {
      final result = await _channel.invokeMethod<bool>('installApk', {'filePath': filePath});
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[UpdateService] Install error: ${e.message}');
      return false;
    }
  }

  void _showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (ctx) => UpdateDialogWidget(info: info),
    );
  }
}

class UpdateDialogWidget extends StatefulWidget {
  final AppUpdateInfo info;
  const UpdateDialogWidget({super.key, required this.info});

  @override
  State<UpdateDialogWidget> createState() => _UpdateDialogWidgetState();
}

class _UpdateDialogWidgetState extends State<UpdateDialogWidget> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _downloadSpeed = '';
  String _downloadStatus = '';
  String? _downloadedFilePath;

  Future<void> _startDownload() async {
    if (_downloadedFilePath != null && File(_downloadedFilePath!).existsSync()) {
      // Already downloaded, install directly
      await UpdateService().installApk(_downloadedFilePath!);
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _downloadStatus = 'Downloading update...';
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/StreamMax_v${widget.info.versionName}.apk');

      if (targetFile.existsSync()) {
        targetFile.deleteSync();
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.info.apkUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;
      final sink = targetFile.openWrite();

      var lastTime = DateTime.now();
      var bytesSinceLast = 0;

      await response.stream.listen((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        bytesSinceLast += chunk.length;

        final now = DateTime.now();
        final diff = now.difference(lastTime).inMilliseconds;
        if (diff > 500) {
          final speedMb = (bytesSinceLast / (diff / 1000)) / (1024 * 1024);
          setState(() {
            _progress = totalBytes > 0 ? (receivedBytes / totalBytes) : 0.0;
            _downloadSpeed = '${speedMb.toStringAsFixed(1)} MB/s';
            if (totalBytes > 0) {
              final recMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
              final totMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
              _downloadStatus = '$recMb MB / $totMb MB';
            }
          });
          lastTime = now;
          bytesSinceLast = 0;
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      setState(() {
        _isDownloading = false;
        _progress = 1.0;
        _downloadedFilePath = targetFile.path;
        _downloadStatus = 'Download Complete!';
      });

      // Launch native package installer
      await UpdateService().installApk(targetFile.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadStatus = 'Download failed. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update download failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;

    return PopScope(
      canPop: !info.forceUpdate && !_isDownloading,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF131720),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF262E3E), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE50914).withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Icon & Version Badges
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE50914), Color(0xFFB81D24)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE50914).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'New Update Available',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'v${UpdateService.currentVersion}',
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.arrow_forward_rounded, color: Colors.grey, size: 12),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE50914).withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE50914), width: 0.8),
                              ),
                              child: Text(
                                'v${info.versionName}',
                                style: const TextStyle(
                                  color: Color(0xFFFF5B5B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Title
              if (info.title.isNotEmpty)
                Text(
                  info.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),

              const SizedBox(height: 10),

              // Changelog Section
              if (info.changelog.isNotEmpty) ...[
                const Text(
                  "What's New:",
                  style: TextStyle(
                    color: Color(0xFF9EA3AE),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0C10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E2430)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: info.changelog.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.check_circle_rounded,
                                color: Color(0xFF00E676), size: 14),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              info.changelog[i],
                              style: const TextStyle(
                                color: Color(0xFFD0D5DD),
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Progress Bar if downloading
              if (_isDownloading || _downloadedFilePath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    backgroundColor: const Color(0xFF1F2633),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _downloadStatus,
                      style: const TextStyle(color: Color(0xFF9EA3AE), fontSize: 11),
                    ),
                    if (_downloadSpeed.isNotEmpty && _isDownloading)
                      Text(
                        _downloadSpeed,
                        style: const TextStyle(
                          color: Color(0xFF00E676),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Action Buttons
              Row(
                children: [
                  if (!info.forceUpdate && !_isDownloading)
                    Expanded(
                      flex: 1,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Later',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                    ),
                  if (!info.forceUpdate && !_isDownloading)
                    const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isDownloading ? null : _startDownload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF7A1519),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _downloadedFilePath != null
                                ? Icons.install_mobile_rounded
                                : Icons.download_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isDownloading
                                ? 'Downloading (${(_progress * 100).toInt()}%)'
                                : _downloadedFilePath != null
                                    ? 'Install Now'
                                    : 'Update Now',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
