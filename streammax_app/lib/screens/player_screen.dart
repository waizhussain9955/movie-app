import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import '../services/netmirror_service.dart';

class PlayerScreen extends StatefulWidget {
  final Movie movie;
  final List<StreamServer> servers;
  final String? localFilePath;
  final String? episodeTitle;
  final int? seasonNumber;
  final int? episodeNumber;
  final bool initialHindiAudio;

  const PlayerScreen({
    super.key,
    required this.movie,
    required this.servers,
    this.localFilePath,
    this.episodeTitle,
    this.seasonNumber,
    this.episodeNumber,
    this.initialHindiAudio = false,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late int _selectedServerIndex;
  late List<StreamServer> _currentServers;
  late final WebViewController _webController;
  bool _isLoading = true;
  bool _hasLoadedSuccessfully = false;
  bool _isOfflineMode = false;
  bool _isLandscape = false;
  bool _isHindiAudio = false;
  int _fallbackAttempts = 0;
  // The NetMirror HLS (.m3u8) URL is the ONLY server with a real dual-audio
  // picker. Remember it so a language switch never drops it (the old code
  // regenerated the server list without it).
  String? _netMirrorStreamUrl;

  @override
  void initState() {
    super.initState();
    _selectedServerIndex = 0;
    _currentServers = List.from(widget.servers);
    _isHindiAudio = widget.initialHindiAudio ||
        widget.movie.isHindi ||
        widget.movie.isHindiDubbed;
    // Find the NetMirror dual-audio HLS server (if the detail screen
    // resolved one). In Hindi mode start on it — the embed servers all
    // default to English audio.
    for (var i = 0; i < _currentServers.length; i++) {
      if (_currentServers[i].url.contains('.m3u8')) {
        _netMirrorStreamUrl = _currentServers[i].url;
        if (_isHindiAudio) _selectedServerIndex = i;
        break;
      }
    }
    _isOfflineMode = widget.localFilePath != null && File(widget.localFilePath!).existsSync();

    // Enable device sensor rotation (Portrait & Landscape)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _initPlayer();
  }

  @override
  void dispose() {
    // 1. Immediately kill video/audio playback so sound doesn't leak into background
    _webController.loadRequest(Uri.parse('about:blank'));
    // 2. Restore system orientation to portrait
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // 3. Restore status/navigation system bars
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _initPlayer() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      )
      ..setBackgroundColor(Colors.black);

    if (Platform.isAndroid && controller.platform is AndroidWebViewController) {
      final androidCtrl = controller.platform as AndroidWebViewController;
      androidCtrl.setMediaPlaybackRequiresUserGesture(false);
    }
    _webController = controller;

    if (_isOfflineMode) {
      // Offline mode: Load local video HTML5 player
      final localUri = Uri.file(widget.localFilePath!).toString();
      final offlineHtml = '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            body { margin: 0; background-color: #000; display: flex; align-items: center; justify-content: center; height: 100vh; overflow: hidden; }
            video { width: 100%; height: 100%; max-height: 100vh; object-fit: contain; }
          </style>
        </head>
        <body>
          <video controls autoplay playsinline controlsList="nodownload">
            <source src="$localUri" type="video/mp4">
            Your device does not support offline video playback.
          </video>
        </body>
        </html>
      ''';
      _webController
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) setState(() => _isLoading = true);
            },
            onPageFinished: (_) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasLoadedSuccessfully = true;
                });
              }
            },
          ),
        )
        ..loadHtmlString(offlineHtml);
    } else {
      // Online mode with ad-blocking and auto-mirror failover
      _setupStreamingController();
    }
  }

  void _setupStreamingController() {
    final activeUrl = _currentServers.isNotEmpty
        ? _currentServers[_selectedServerIndex].url
        : 'https://vidlink.pro/movie/${widget.movie.id}';

    _webController.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
            _injectAdBlocker();
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasLoadedSuccessfully = true;
              });
            }
            _injectAdBlocker();
            // Force 100% volume and unmuted playback on any video elements in page
            _webController.runJavaScript('''
              try {
                function unmuteMedia() {
                  var els = document.querySelectorAll('video, audio');
                  for (var i = 0; i < els.length; i++) {
                    els[i].muted = false;
                    els[i].volume = 1.0;
                    els[i].defaultMuted = false;
                  }
                }
                unmuteMedia();
                setInterval(unmuteMedia, 1000);
                window.addEventListener('click', unmuteMedia);
                window.addEventListener('touchstart', unmuteMedia);
              } catch(e) {}
            ''').catchError((_) {});
          },
          onWebResourceError: (WebResourceError error) {
            // CRITICAL FIX: Only handle fallback if MAIN frame failed during INITIAL load.
            // When user seeks/forwards video, HTML5 player aborts byte-range requests (net::ERR_ABORTED).
            // Subresource errors must never trigger fallback or switch servers!
            if (error.isForMainFrame == true && _isLoading && !_hasLoadedSuccessfully) {
              _handleAutoFallback('Main frame connection error');
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();

            // 1. AIRTIGHT ADULT & MALICIOUS CONTENT FILTER
            final blockedKeywords = [
              'sex', 'porn', 'xxx', 'milf', 'anal', 'adult', 'erotic', 'dating',
              'teen', 'blowjob', 'tits', 'dick', 'pussy', 'cum', 'horny',
              'nude', 'strip', 'escort', 'cam', 'playboy', 'xvideos', 'xnxx',
              'redtube', 'youporn', 'brazzers', 'stripchat', 'fetish',
              '1xbet', 'melbet', 'parimatch', 'bet365', 'mostbet', 'linebet', '1win',
              'casino', 'gambl', 'poker', 'roulette', 'spin-wheel',
              'adsterra', 'popads', 'monetag', 'propellerads', 'exoclick',
              'trafficjunky', 'hilltopads', 'clickadu', 'richpush',
              'linkvertise', 'lootlinks', 'shortlink',
              'apk-download', '.apk', 'whatsapp://', 'tg://', 'intent://',
              'market://', 'play.google.com/store/apps',
            ];

            for (final keyword in blockedKeywords) {
              if (url.contains(keyword) && !url.contains('vidlink') && !url.contains('vidsrc')) {
                debugPrint('🛡️ [AdBlocker] Blocked ad/adult redirect: $url');
                return NavigationDecision.prevent;
              }
            }

            // 2. STRICT WHITELIST: Only verified movie stream hosts and CDNs can navigate
            final allowedHosts = [
              'vidlink.pro',
              'vidsrc.to',
              'vidsrc.sh',
              'vidsrc.me',
              'vidsrc.xyz',
              'vidsrc.icu',
              'vidsrc.cc',
              'videasy.net',
              'autoembed.me',
              'autoembed.co',
              '2embed.cc',
              'smashystream.com',
              'anyembed.xyz',
              'cinesrc.st',
              'superembed.stream',
              'embed.su',
              'vidcloud',
              'megacloud',
              'rabbitstream',
              'cloudflare',
              'm3u8',
              'mp4',
              'blob:',
              'about:blank',
              'net52.cc',
              'net77.cc',
              'netmirror',
              'imgcdn.kim',
              'freecdn4.top',
              'freecdn51.top',
              'freecdn',
              'subscdn.top',
              'jsdelivr.net',
            ];

            final isAllowed = allowedHosts.any((host) => url.contains(host));
            if (!isAllowed) {
              debugPrint('🛡️ [AdBlocker] Blocked unverified domain: $url');
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      );

    _loadActiveStream(activeUrl);
  }

  void _loadActiveStream(String url) {
    if (url.contains('.m3u8')) {
      String streamUrl = url;
      String referer = 'https://net52.cc/';
      if (url.contains('#referer=')) {
        final parts = url.split('#referer=');
        streamUrl = parts[0];
        referer = parts[1];
        if (!referer.endsWith('/')) referer = '$referer/';
      }
      _webController.loadHtmlString(
        _buildHlsPlayerHtml(streamUrl, referer: referer),
        baseUrl: referer,
      );
    } else {
      _webController.loadRequest(Uri.parse(url));
    }
  }

  String _buildHlsPlayerHtml(String m3u8Url, {String referer = 'https://net52.cc/'}) {
    final preferHindi = _isHindiAudio ? 'true' : 'false';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta name="referrer" content="always">
  <script src="https://cdn.jsdelivr.net/npm/hls.js@1.5.8/dist/hls.min.js"></script>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { background: #000; color: #fff; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; overflow: hidden; height: 100vh; display: flex; flex-direction: column; justify-content: center; align-items: center; }
    #videoContainer { position: relative; width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; }
    video { width: 100%; height: 100%; max-height: 100vh; object-fit: contain; }
    .audio-pill {
      position: absolute; top: 14px; right: 14px;
      background: rgba(229, 9, 20, 0.95);
      color: white; border: 1px solid rgba(255,255,255,0.3);
      padding: 7px 14px; border-radius: 20px;
      font-size: 13px; font-weight: bold;
      display: flex; align-items: center; gap: 6px;
      cursor: pointer; z-index: 100;
      box-shadow: 0 4px 12px rgba(0,0,0,0.6);
    }
    #audioModal {
      display: none; position: absolute; inset: 0;
      background: rgba(0,0,0,0.85); z-index: 200;
      flex-direction: column; align-items: center; justify-content: center;
      padding: 20px;
    }
    #audioModal.active { display: flex; }
    .modal-box {
      background: #181818; border: 1px solid #333;
      border-radius: 14px; padding: 18px; max-width: 320px; width: 100%;
      max-height: 75vh; overflow-y: auto;
    }
    .modal-title { font-size: 16px; font-weight: bold; margin-bottom: 12px; display: flex; justify-content: space-between; align-items: center; }
    .track-item {
      padding: 10px 14px; border-radius: 8px; margin-bottom: 6px;
      background: #242424; font-size: 14px; cursor: pointer;
      display: flex; justify-content: space-between; align-items: center;
    }
    .track-item.selected { background: #e50914; font-weight: bold; }
    .toast {
      position: absolute; bottom: 60px; left: 50%; transform: translateX(-50%);
      background: rgba(20,20,20,0.9); border: 1px solid #e50914; border-radius: 20px;
      padding: 8px 18px; font-size: 13px; color: #fff; z-index: 300; display: none;
    }
  </style>
</head>
<body>
  <div id="videoContainer">
    <video id="videoPlayer" controls autoplay playsinline controlsList="nodownload"></video>
    <button class="audio-pill" onclick="openAudioModal()">
      <span>🎧 Audio: <span id="currentAudioName">Original / Dual Audio</span></span>
    </button>
    <button id="unmuteOverlay" style="display:none; position:absolute; bottom:80px; left:50%; transform:translateX(-50%); background:rgba(229,9,20,0.95); color:white; border:none; padding:10px 22px; border-radius:24px; font-size:14px; font-weight:bold; cursor:pointer; z-index:150; box-shadow:0 4px 15px rgba(0,0,0,0.7);" onclick="unmuteAudio()">
      🔊 Tap to Unmute & Max Volume
    </button>
    <div id="toast" class="toast"></div>
    <div id="audioModal">
      <div class="modal-box">
        <div class="modal-title">
          <span>Choose Audio Language</span>
          <span style="cursor:pointer;font-size:20px;" onclick="closeAudioModal()">✕</span>
        </div>
        <div id="trackList"></div>
      </div>
    </div>
  </div>
  <script>
    var video = document.getElementById('videoPlayer');
    var currentAudioLabel = document.getElementById('currentAudioName');
    var trackListEl = document.getElementById('trackList');
    var modalEl = document.getElementById('audioModal');
    var toastEl = document.getElementById('toast');
    var unmuteBtn = document.getElementById('unmuteOverlay');
    var m3u8Url = '$m3u8Url';
    var preferHindi = $preferHindi;
    var hls = null;

    function showToast(msg) {
      toastEl.innerText = msg;
      toastEl.style.display = 'block';
      setTimeout(function() { toastEl.style.display = 'none'; }, 3000);
    }

    function unmuteAudio() {
      if (video) {
        video.muted = false;
        video.volume = 1.0;
        if (unmuteBtn) unmuteBtn.style.display = 'none';
        showToast('🔊 Volume 100% Unmuted');
      }
    }

    video.muted = false;
    video.volume = 1.0;
    video.defaultMuted = false;

    video.addEventListener('volumechange', function() {
      if (unmuteBtn) {
        unmuteBtn.style.display = (video.muted || video.volume === 0) ? 'block' : 'none';
      }
    });

    window.addEventListener('click', unmuteAudio);
    window.addEventListener('touchstart', unmuteAudio);
    document.addEventListener('DOMContentLoaded', unmuteAudio);

    video.addEventListener('loadedmetadata', function() {
      if (!hls || !hls.audioTracks || hls.audioTracks.length === 0) {
        currentAudioLabel.innerText = preferHindi ? 'Hindi / Original' : 'Standard Audio';
      }
    });

    function openAudioModal() {
      renderTrackList();
      modalEl.classList.add('active');
    }

    function closeAudioModal() {
      modalEl.classList.remove('active');
    }

    function renderTrackList() {
      trackListEl.innerHTML = '';
      if (!hls || !hls.audioTracks || hls.audioTracks.length === 0) {
        trackListEl.innerHTML = '<div style="color:grey;padding:10px;">Default Audio Track Active</div>';
        return;
      }
      for (var i = 0; i < hls.audioTracks.length; i++) {
        var t = hls.audioTracks[i];
        var isSel = (hls.audioTrack === i);
        var div = document.createElement('div');
        div.className = 'track-item' + (isSel ? ' selected' : '');
        var flag = '🎧';
        var nameLower = (t.name || '').toLowerCase();
        var langLower = (t.lang || '').toLowerCase();
        if (langLower.includes('hin') || nameLower.includes('hindi')) flag = '🇮🇳';
        else if (langLower.includes('eng') || nameLower.includes('english')) flag = '🇬🇧';
        else if (langLower.includes('spa') || nameLower.includes('spanish')) flag = '🇪🇸';
        else if (langLower.includes('tam') || nameLower.includes('tamil')) flag = '🇮🇳';
        else if (langLower.includes('tel') || nameLower.includes('telugu')) flag = '🇮🇳';
        else if (langLower.includes('fra') || nameLower.includes('french')) flag = '🇫🇷';
        else if (langLower.includes('deu') || nameLower.includes('german')) flag = '🇩🇪';

        div.innerHTML = '<span>' + flag + ' ' + (t.name || ('Audio ' + (i+1))) + '</span>' + (isSel ? '<span>✓</span>' : '');
        div.setAttribute('data-idx', i);
        div.onclick = (function(idx) {
          return function() {
            setAudioTrack(idx);
            closeAudioModal();
          };
        })(i);
        trackListEl.appendChild(div);
      }
    }

    function setAudioTrack(idx) {
      if (hls && hls.audioTracks && hls.audioTracks[idx]) {
        hls.audioTrack = idx;
        var selectedTrack = hls.audioTracks[idx];
        currentAudioLabel.innerText = selectedTrack.name || 'Track ' + idx;
        showToast('Switched to: ' + (selectedTrack.name || 'Audio ' + idx));
      }
    }

    window.selectAudioByLang = function(langPrefix) {
      if (!hls || !hls.audioTracks) return false;
      for (var i = 0; i < hls.audioTracks.length; i++) {
        var t = hls.audioTracks[i];
        var lang = (t.lang || '').toLowerCase();
        var name = (t.name || '').toLowerCase();
        if (lang.includes(langPrefix.toLowerCase()) || name.includes(langPrefix.toLowerCase())) {
          setAudioTrack(i);
          return true;
        }
      }
      return false;
    };

    if (Hls.isSupported()) {
      hls = new Hls({
        enableWorker: true,
        xhrSetup: function(xhr, url) {
          xhr.withCredentials = false;
        }
      });
      hls.loadSource(m3u8Url);
      hls.attachMedia(video);

      hls.on(Hls.Events.ERROR, function(event, data) {
        console.log("HLS Event Error:", data.type, data.details, data.fatal);
        if (data.fatal) {
          switch(data.type) {
            case Hls.ErrorTypes.NETWORK_ERROR:
              console.log("Network error, attempting recovery...");
              hls.startLoad();
              break;
            case Hls.ErrorTypes.MEDIA_ERROR:
              console.log("Media error, attempting recovery...");
              hls.recoverMediaError();
              break;
            default:
              break;
          }
        }
      });

      hls.on(Hls.Events.MANIFEST_PARSED, function() {
        var tracks = hls.audioTracks || [];
        var switched = false;
        if (preferHindi && tracks.length > 0) {
          for (var i = 0; i < tracks.length; i++) {
            var t = tracks[i];
            var lang = (t.lang || '').toLowerCase();
            var name = (t.name || '').toLowerCase();
            if (lang.includes('hin') || name.includes('hindi')) {
              setAudioTrack(i);
              switched = true;
              break;
            }
          }
        }
        if (!switched) {
          if (tracks.length > 0) {
            currentAudioLabel.innerText = tracks[hls.audioTrack >= 0 ? hls.audioTrack : 0].name || 'Audio Track';
          } else {
            currentAudioLabel.innerText = preferHindi ? 'Hindi / Original' : 'Standard Audio';
          }
        }
        video.muted = false;
        video.volume = 1.0;
        var playPromise = video.play();
        if (playPromise !== undefined) {
          playPromise.then(function() {
            video.muted = false;
            video.volume = 1.0;
            if (unmuteBtn) unmuteBtn.style.display = 'none';
          }).catch(function(e) {
            console.log("Autoplay unmuted blocked by browser, trying muted autoplay with unmute banner:", e);
            video.muted = true;
            video.play().then(function() {
              if (unmuteBtn) unmuteBtn.style.display = 'block';
            }).catch(function(){});
          });
        }
      });
    } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
      video.src = m3u8Url;
      video.play().catch(function(){});
    }

    video.addEventListener('click', function() {
      unmuteAudio();
      if (video.paused) {
        video.play().catch(function(){});
      }
    });
  </script>
</body>
</html>
''';
  }

  void _injectAdBlocker() {
    const adScript = '''
      (function() {
        // 1. Permanently block all window popups and tab redirects
        window.open = function() { console.log('AdBlock: Blocked window.open'); return null; };
        window.alert = function() {};
        window.confirm = function() { return false; };
        window.prompt = function() { return null; };

        // 2. Click-Jacking Interceptor: Block hidden ad anchor overlays
        document.addEventListener('click', function(e) {
          var target = e.target;
          while (target && target.tagName !== 'A') {
            target = target.parentElement;
          }
          if (target && target.tagName === 'A') {
            var href = (target.getAttribute('href') || '').toLowerCase();
            if (href.startsWith('http') && 
                !href.includes('vidlink') && 
                !href.includes('vidsrc') && 
                !href.includes('videasy') && 
                !href.includes('2embed') && 
                !href.includes('autoembed') && 
                !href.includes('smashy')) {
              e.preventDefault();
              e.stopPropagation();
              console.log('Blocked clickjacking ad redirect:', href);
              return false;
            }
          }
        }, true);

        // 3. Force 100% volume and unmute on all video elements
        var unmuteAllMedia = function() {
          try {
            var media = document.querySelectorAll('video, audio');
            for (var i = 0; i < media.length; i++) {
              media[i].muted = false;
              media[i].volume = 1.0;
              media[i].defaultMuted = false;
            }
          } catch(e) {}
        };
        unmuteAllMedia();
        setInterval(unmuteAllMedia, 1500);
        window.addEventListener('click', unmuteAllMedia);
        window.addEventListener('touchstart', unmuteAllMedia);

        // 4. Auto-detect and select Hindi audio track if available in HTML5 video element
        var trySelectHindiAudio = function() {
          var v = document.querySelector('video');
          if (v && v.audioTracks) {
            for (var i = 0; i < v.audioTracks.length; i++) {
              var track = v.audioTracks[i];
              var lang = (track.language || '').toLowerCase();
              var label = (track.label || '').toLowerCase();
              if (lang.includes('hi') || label.includes('hindi')) {
                track.enabled = true;
              }
            }
          }
        };
        setInterval(trySelectHindiAudio, 2000);
      })();
    ''';
    _webController.runJavaScript(adScript).catchError((_) {});
  }

  void _handleAutoFallback(String reason) {
    // Never auto-fallback once video has successfully loaded or during seeking
    if (_hasLoadedSuccessfully) return;
    if (_fallbackAttempts >= _currentServers.length) return;
    _fallbackAttempts++;

    final nextIndex = (_selectedServerIndex + 1) % _currentServers.length;
    if (nextIndex != _selectedServerIndex && mounted) {
      _switchServer(nextIndex, auto: true);
    }
  }

  void _switchServer(int index, {bool auto = false}) {
    if (index >= 0 && index < _currentServers.length) {
      setState(() {
        _selectedServerIndex = index;
        _isLoading = true;
        _hasLoadedSuccessfully = false;
      });
      _loadActiveStream(_currentServers[index].url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              auto
                  ? '⚡ Auto-switched to Mirror ${index + 1} for best speed'
                  : 'Switched to Mirror ${index + 1}',
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: const Color(0xFFE50914),
          ),
        );
      }
    }
  }

  void _showAudioLanguageDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.volume_up, color: Color(0xFFE50914), size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Select Audio Language',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),

                // English Option
                ListTile(
                  leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
                  title: const Text('English (Original Audio)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Default original multi-channel audio', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: !_isHindiAudio
                      ? const Icon(Icons.check_circle, color: Color(0xFFE50914))
                      : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  tileColor: !_isHindiAudio ? const Color(0xFF2B2B2B) : Colors.transparent,
                  onTap: () {
                    Navigator.pop(ctx);
                    _changeAudioLanguage(false);
                  },
                ),
                const SizedBox(height: 8),

                // Hindi Option
                ListTile(
                  leading: const Text('🇮🇳', style: TextStyle(fontSize: 24)),
                  title: Text(
                    widget.movie.isHindi ? 'Hindi (Original Audio)' : 'Hindi Dubbed (Dual Audio)',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Official Netflix Hindi dubbed audio track', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: _isHindiAudio
                      ? const Icon(Icons.check_circle, color: Color(0xFFE50914))
                      : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  tileColor: _isHindiAudio ? const Color(0xFF2B2B2B) : Colors.transparent,
                  onTap: () {
                    Navigator.pop(ctx);
                    _changeAudioLanguage(true);
                  },
                ),
                const SizedBox(height: 6),

                // Spanish Option
                ListTile(
                  leading: const Text('🇪🇸', style: TextStyle(fontSize: 24)),
                  title: const Text('Spanish (Original)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Original Spanish European track', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _webController.runJavaScript('if(window.selectAudioByLang) window.selectAudioByLang("spa");');
                  },
                ),
                const SizedBox(height: 6),

                // Tamil Option
                ListTile(
                  leading: const Text('🇮🇳', style: TextStyle(fontSize: 24)),
                  title: const Text('Tamil (Dubbed)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Tamil regional dub', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _webController.runJavaScript('if(window.selectAudioByLang) window.selectAudioByLang("tam");');
                  },
                ),
                const SizedBox(height: 6),

                // Telugu Option
                ListTile(
                  leading: const Text('🇮🇳', style: TextStyle(fontSize: 24)),
                  title: const Text('Telugu (Dubbed)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Telugu regional dub', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _webController.runJavaScript('if(window.selectAudioByLang) window.selectAudioByLang("tel");');
                  },
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Player Tip: Inside the player, you can also tap ⚙️ (Settings) or 💬 (Audio Track) on the video bar to change language instantly.',
                          style: TextStyle(color: Colors.amber, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showServerSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.dns, color: Color(0xFFE50914), size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Choose Streaming Mirror',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                ..._currentServers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final s = entry.value;
                  final isSelected = idx == _selectedServerIndex;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: isSelected ? const Color(0xFFE50914) : const Color(0xFF333333),
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[300],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      s.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[200],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Quality: ${s.quality}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Color(0xFFE50914), size: 20)
                        : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tileColor: isSelected ? const Color(0xFF2A2A2A) : Colors.transparent,
                    onTap: () {
                      Navigator.pop(ctx);
                      _switchServer(idx);
                    },
                  );
                }),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.tips_and_updates_outlined, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'If video buffers or language is not matching, try switching between Server 1, Server 2, or Server 3.',
                          style: TextStyle(color: Colors.amber, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _changeAudioLanguage(bool isHindi) async {
    if (_isHindiAudio == isHindi) return;
    setState(() => _isHindiAudio = isHindi);

    final activeUrl = _currentServers.isNotEmpty ? _currentServers[_selectedServerIndex].url : '';

    // Case 1: Direct HLS .m3u8 stream, switch audio track in-player without reload
    if (activeUrl.contains('.m3u8')) {
      final langPrefix = isHindi ? 'hin' : 'eng';
      _webController.runJavaScript('if(window.selectAudioByLang) window.selectAudioByLang("$langPrefix");');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isHindi ? '🇮🇳 Hindi Dubbed track activated!' : '🇬🇧 English Original Audio active'),
          backgroundColor: const Color(0xFFE50914),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Case 2: Embed/iframe server. The embed URLs are IDENTICAL for Hindi
    // and English (only the labels change) — no embed provider takes an
    // audio-language parameter — so toggling here used to do nothing real.
    // The only true Hindi source is the NetMirror dual-audio HLS stream:
    // resolve it on demand if we don't already have it.
    if (isHindi && _netMirrorStreamUrl == null) {
      setState(() => _isLoading = true);
      try {
        final resolved = await NetMirrorService.resolveStream(
          widget.movie.title,
          isTv: widget.movie.mediaType == 'tv',
          season: widget.seasonNumber ?? 1,
          episode: widget.episodeNumber ?? 1,
        ).timeout(const Duration(seconds: 8), onTimeout: () => null);
        if (resolved != null && resolved.isNotEmpty) {
          _netMirrorStreamUrl = resolved;
        }
      } catch (_) {
        // NetMirror unreachable — fall through to the embed servers below.
      }
    }

    setState(() {
      _isLoading = true;
      _hasLoadedSuccessfully = false;
      _currentServers = ApiService.generateServers(
        widget.movie.id,
        isTv: widget.movie.mediaType == 'tv',
        season: widget.seasonNumber ?? 1,
        episode: widget.episodeNumber ?? 1,
        isHindiAudio: isHindi,
        // Pass the NetMirror URL through, otherwise regenerating the list
        // silently drops the only dual-audio server (old bug).
        netMirrorStreamUrl: _netMirrorStreamUrl,
      );
      // NetMirror is Server 1 when present — start on it for Hindi.
      _selectedServerIndex = 0;
    });

    _loadActiveStream(_currentServers.first.url);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isHindi
              ? (_netMirrorStreamUrl != null
                  ? '🇮🇳 Hindi Dual Audio stream loaded'
                  : '🇮🇳 Hindi mode active! VidLink Pro / Videasy me player ⚙️ settings se audio check karein')
              : '🇬🇧 Switched to English Original Audio'),
          backgroundColor: const Color(0xFFE50914),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.episodeTitle != null
        ? '${widget.movie.title} - ${widget.episodeTitle}'
        : widget.movie.title;

    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;

        // Auto-enable sticky immersive mode when rotated into landscape
        if (isLandscape) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, _) {
            // Restore portrait when popping back
            SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            // Hide standard 56dp AppBar in landscape for edge-to-edge cinema view
            appBar: isLandscape
                ? null
                : AppBar(
                    backgroundColor: Colors.black,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    actions: [
                      // Prominent Audio Selector Pill
                      InkWell(
                        onTap: _showAudioLanguageDialog,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isHindiAudio ? const Color(0xFFE50914).withValues(alpha: 0.25) : const Color(0xFF222222),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _isHindiAudio ? const Color(0xFFE50914) : Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.volume_up, color: _isHindiAudio ? const Color(0xFFE50914) : Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                _isHindiAudio ? 'Hindi 🇮🇳' : 'English 🇬🇧',
                                style: TextStyle(
                                  color: _isHindiAudio ? Colors.white : Colors.grey[200],
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Prominent Server Selector Pill
                      InkWell(
                        onTap: _showServerSelectionSheet,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF222222),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.dns_outlined, color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'S${_selectedServerIndex + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Orientation Toggle (Landscape cinema vs Portrait)
                      IconButton(
                        icon: const Icon(Icons.screen_lock_landscape, color: Colors.white),
                        tooltip: 'Landscape Cinema Mode',
                        onPressed: _toggleOrientation,
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        tooltip: 'Reload Stream',
                        onPressed: () => _webController.reload(),
                      ),
                    ],
                  ),
            body: Stack(
              children: [
                // Full Screen Edge-to-Edge Video Stream
                SizedBox.expand(
                  child: WebViewWidget(controller: _webController),
                ),

                // Floating Controls Overlay in Landscape Cinema Mode
                if (isLandscape)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Quick Audio Selector Button
                            InkWell(
                              onTap: _showAudioLanguageDialog,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _isHindiAudio ? const Color(0xFFE50914).withValues(alpha: 0.3) : Colors.black54,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _isHindiAudio ? const Color(0xFFE50914) : Colors.white24),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.volume_up, color: _isHindiAudio ? const Color(0xFFE50914) : Colors.amber, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isHindiAudio ? 'Hindi 🇮🇳' : 'English 🇬🇧',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Quick Server Switcher in Landscape
                            InkWell(
                              onTap: _showServerSelectionSheet,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.dns_outlined, color: Colors.white70, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Mirror ${_selectedServerIndex + 1}',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.screen_lock_portrait, color: Colors.white),
                              tooltip: 'Exit Landscape Cinema Mode',
                              onPressed: _toggleOrientation,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Clean Loading Indicator
                if (_isLoading)
                  Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Color(0xFFE50914)),
                          const SizedBox(height: 16),
                          Text(
                            _isOfflineMode
                                ? 'Loading local offline video...'
                                : 'Connecting to High-Speed Stream Mirror...',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Upcoming movie notice if applicable
                if (widget.movie.isUpcoming)
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Release Date: ${widget.movie.releaseDate ?? widget.movie.year}. Digital OTT stream will unlock upon official release.',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
