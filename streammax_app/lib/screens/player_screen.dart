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
  final List<Episode>? allEpisodes;

  const PlayerScreen({
    super.key,
    required this.movie,
    required this.servers,
    this.localFilePath,
    this.episodeTitle,
    this.seasonNumber,
    this.episodeNumber,
    this.initialHindiAudio = false,
    this.allEpisodes,
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
  String? _netMirrorStreamUrl;
  int? _currentEpisodeNumber;
  String? _currentEpisodeTitle;
  List<Episode>? _episodes;

  @override
  void initState() {
    super.initState();
    _selectedServerIndex = 0;
    _currentServers = List.from(widget.servers);
    _isHindiAudio = widget.initialHindiAudio ||
        widget.movie.isHindi ||
        widget.movie.isHindiDubbed;
    _currentEpisodeNumber = widget.episodeNumber;
    _currentEpisodeTitle = widget.episodeTitle;
    _episodes = widget.allEpisodes != null ? List.from(widget.allEpisodes!) : null;

    // Find the NetMirror dual-audio HLS server (if resolved). In Hindi mode start on it.
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
            // Unmute media on first playback without overriding user volume adjustments
            _webController.runJavaScript('''
              try {
                function unmuteMedia() {
                  var els = document.querySelectorAll('video, audio');
                  for (var i = 0; i < els.length; i++) {
                    if (els[i].muted) {
                      els[i].muted = false;
                      els[i].defaultMuted = false;
                    }
                  }
                }
                unmuteMedia();
                window.addEventListener('click', unmuteMedia, { once: true });
                window.addEventListener('touchstart', unmuteMedia, { once: true });
              } catch(e) {}
            ''').catchError((_) {});

            // Auto-detect NetMirror rate limit ("Too Many Requests" / "STOP Abuse") and switch to VidLink
            _webController.runJavaScriptReturningResult('document.body.innerText').then((result) {
              final text = result.toString().toLowerCase();
              if (text.contains('stop abuse') || text.contains('too many requests')) {
                if (mounted && _selectedServerIndex == 0 && _currentServers.length > 1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚡ NetMirror is busy. Auto-switched to Server 2 (VidLink Pro)'),
                      backgroundColor: Color(0xFFE50914),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  _switchServer(1, auto: true);
                }
              }
            }).catchError((_) {});
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
    html, body {
      background: #000;
      color: #fff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      overflow: hidden;
      width: 100vw;
      height: 100vh;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    #videoContainer {
      position: relative;
      width: 100%;
      height: 100%;
      max-width: 100vw;
      max-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #000;
    }
    /* Strictly enforce 16:9 aspect ratio container so Chromium never stretches the play button */
    .video-wrapper {
      position: relative;
      width: 100%;
      max-width: 100%;
      aspect-ratio: 16 / 9;
      max-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #000;
    }
    video {
      width: 100%;
      height: 100%;
      object-fit: contain;
      background: #000;
      outline: none;
    }
    /* Circular Netflix-Red Center Play Overlay */
    #playOverlay {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      width: 68px;
      height: 68px;
      border-radius: 50%;
      background: rgba(229, 9, 20, 0.95);
      box-shadow: 0 4px 25px rgba(229, 9, 20, 0.6), 0 0 0 3px rgba(255, 255, 255, 0.25);
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      z-index: 50;
      transition: transform 0.18s ease, opacity 0.22s ease;
    }
    #playOverlay:active {
      transform: translate(-50%, -50%) scale(0.92);
    }
    #playOverlay.hidden {
      opacity: 0;
      pointer-events: none;
    }
    .audio-pill {
      position: absolute; top: 14px; right: 14px;
      background: rgba(229, 9, 20, 0.92);
      color: white; border: 1px solid rgba(255,255,255,0.25);
      padding: 6px 14px; border-radius: 20px;
      font-size: 12px; font-weight: bold;
      display: flex; align-items: center; gap: 6px;
      cursor: pointer; z-index: 100;
      box-shadow: 0 4px 14px rgba(0,0,0,0.6);
      backdrop-filter: blur(6px);
    }
    #audioModal {
      display: none; position: absolute; inset: 0;
      background: rgba(10,12,16,0.92); z-index: 200;
      flex-direction: column; align-items: center; justify-content: center;
      padding: 20px;
    }
    #audioModal.active { display: flex; }
    .modal-box {
      background: #131720; border: 1px solid #202634;
      border-radius: 16px; padding: 18px; max-width: 330px; width: 100%;
      max-height: 75vh; overflow-y: auto;
      box-shadow: 0 10px 30px rgba(0,0,0,0.8);
    }
    .modal-title { font-size: 16px; font-weight: bold; margin-bottom: 14px; display: flex; justify-content: space-between; align-items: center; }
    .track-item {
      padding: 11px 14px; border-radius: 10px; margin-bottom: 8px;
      background: #1a1f2c; font-size: 13.5px; cursor: pointer;
      display: flex; justify-content: space-between; align-items: center;
      border: 1px solid #202634;
    }
    .track-item.selected { background: rgba(229, 9, 20, 0.18); border-color: #e50914; font-weight: bold; }
    .toast {
      position: absolute; bottom: 50px; left: 50%; transform: translateX(-50%);
      background: rgba(19, 23, 32, 0.95); border: 1px solid #e50914; border-radius: 20px;
      padding: 8px 18px; font-size: 12.5px; color: #fff; z-index: 300; display: none;
      box-shadow: 0 4px 16px rgba(0,0,0,0.6);
    }
  </style>
</head>
<body>
  <div id="videoContainer">
    <div class="video-wrapper">
      <video id="videoPlayer" controls autoplay playsinline controlsList="nodownload"></video>
      <div id="playOverlay" onclick="togglePlayPause()">
        <svg width="30" height="30" viewBox="0 0 24 24" fill="white" style="margin-left: 3px;">
          <path d="M8 5v14l11-7z"/>
        </svg>
      </div>
    </div>
    <button class="audio-pill" onclick="openAudioModal()">
      <span>🎧 Audio: <span id="currentAudioName">Dual Audio</span></span>
    </button>
    <button id="unmuteOverlay" style="display:none; position:absolute; bottom:65px; left:50%; transform:translateX(-50%); background:rgba(229,9,20,0.95); color:white; border:none; padding:10px 22px; border-radius:24px; font-size:13px; font-weight:bold; cursor:pointer; z-index:150; box-shadow:0 4px 15px rgba(0,0,0,0.7);" onclick="unmuteAudio()">
      🔊 Tap to Unmute & Max Volume
    </button>
    <div id="toast" class="toast"></div>
    <div id="audioModal">
      <div class="modal-box">
        <div class="modal-title">
          <span>Choose Audio Language</span>
          <span style="cursor:pointer;font-size:20px;color:#9ea3ae;" onclick="closeAudioModal()">✕</span>
        </div>
        <div id="trackList"></div>
      </div>
    </div>
  </div>
  <script>
    var video = document.getElementById('videoPlayer');
    var playOverlay = document.getElementById('playOverlay');
    var currentAudioLabel = document.getElementById('currentAudioName');
    var trackListEl = document.getElementById('trackList');
    var modalEl = document.getElementById('audioModal');
    var toastEl = document.getElementById('toast');
    var unmuteBtn = document.getElementById('unmuteOverlay');
    var m3u8Url = '$m3u8Url';
    var preferHindi = $preferHindi;
    var hls = null;

    function togglePlayPause() {
      if (video.paused) {
        video.play();
      } else {
        video.pause();
      }
      unmuteAudio();
    }

    video.addEventListener('play', function() {
      if (playOverlay) playOverlay.classList.add('hidden');
    });
    video.addEventListener('pause', function() {
      if (playOverlay) playOverlay.classList.remove('hidden');
    });

    function showToast(msg) {
      toastEl.innerText = msg;
      toastEl.style.display = 'block';
      setTimeout(function() { toastEl.style.display = 'none'; }, 3000);
    }

    function unmuteAudio() {
      if (video && video.muted) {
        video.muted = false;
        if (unmuteBtn) unmuteBtn.style.display = 'none';
      }
    }

    video.muted = false;
    video.defaultMuted = false;

    video.addEventListener('volumechange', function() {
      if (unmuteBtn) {
        unmuteBtn.style.display = (video.muted) ? 'block' : 'none';
      }
    });

    window.addEventListener('click', unmuteAudio, { once: true });
    window.addEventListener('touchstart', unmuteAudio, { once: true });
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

      function autoSelectPreferredAudio() {
        var tracks = hls.audioTracks || [];
        if (preferHindi && tracks.length > 0) {
          for (var i = 0; i < tracks.length; i++) {
            var t = tracks[i];
            var lang = (t.lang || '').toLowerCase();
            var name = (t.name || '').toLowerCase();
            if (lang.includes('hin') || name.includes('hindi')) {
              if (hls.audioTrack !== i) {
                setAudioTrack(i);
              }
              return true;
            }
          }
        }
        return false;
      }

      hls.on(Hls.Events.AUDIO_TRACKS_UPDATED, function() {
        autoSelectPreferredAudio();
      });

      hls.on(Hls.Events.MANIFEST_PARSED, function() {
        var didSwitch = autoSelectPreferredAudio();
        if (!didSwitch) {
          var tracks = hls.audioTracks || [];
          if (tracks.length > 0) {
            currentAudioLabel.innerText = tracks[hls.audioTrack >= 0 ? hls.audioTrack : 0].name || 'Audio Track';
          } else {
            currentAudioLabel.innerText = preferHindi ? 'Hindi Dubbed 🇮🇳' : 'Standard Audio';
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

        // 3. Unmute media on page load without overriding user volume adjustments
        var unmuteAllMedia = function() {
          try {
            var media = document.querySelectorAll('video, audio');
            for (var i = 0; i < media.length; i++) {
              if (media[i].muted) {
                media[i].muted = false;
                media[i].defaultMuted = false;
              }
            }
          } catch(e) {}
        };
        unmuteAllMedia();
        window.addEventListener('click', unmuteAllMedia, { once: true });
        window.addEventListener('touchstart', unmuteAllMedia, { once: true });

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

  Future<void> _switchEpisode(Episode ep) async {
    setState(() {
      _currentEpisodeNumber = ep.episodeNumber;
      _currentEpisodeTitle = 'S${ep.seasonNumber} E${ep.episodeNumber}: ${ep.name}';
      _isLoading = true;
      _hasLoadedSuccessfully = false;
    });

    String? netmirrorUrl;
    try {
      netmirrorUrl = await NetMirrorService.resolveStream(
        widget.movie.title,
        isTv: true,
        season: ep.seasonNumber,
        episode: ep.episodeNumber,
      ).timeout(const Duration(seconds: 8), onTimeout: () => null);
    } catch (_) {}

    final servers = ApiService.generateServers(
      widget.movie.id,
      isTv: true,
      season: ep.seasonNumber,
      episode: ep.episodeNumber,
      isHindiAudio: _isHindiAudio,
      netMirrorStreamUrl: netmirrorUrl,
    );

    setState(() {
      _currentServers = servers;
      _netMirrorStreamUrl = netmirrorUrl;
      _selectedServerIndex = 0;
    });

    _loadActiveStream(servers.first.url);
  }

  void _showEpisodesSheet() {
    if (_episodes == null || _episodes!.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131720),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B3244),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.video_library_rounded, color: Color(0xFFE50914), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Season ${widget.seasonNumber ?? 1} Episodes',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF9EA3AE), size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF202634), height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: _episodes!.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final ep = _episodes![idx];
                      final isCurrent = ep.episodeNumber == _currentEpisodeNumber;
                      return Container(
                        decoration: BoxDecoration(
                          color: isCurrent ? const Color(0xFFE50914).withValues(alpha: 0.15) : const Color(0xFF1A1F2C),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrent ? const Color(0xFFE50914) : const Color(0xFF202634),
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 13,
                            backgroundColor: isCurrent ? const Color(0xFFE50914) : const Color(0xFF2B3244),
                            child: Text(
                              '${ep.episodeNumber}',
                              style: TextStyle(
                                color: isCurrent ? Colors.white : const Color(0xFF9EA3AE),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            ep.name,
                            style: TextStyle(
                              color: isCurrent ? Colors.white : const Color(0xFFD0D4DC),
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            ep.overview.isNotEmpty ? ep.overview : 'Episode ${ep.episodeNumber}',
                            style: const TextStyle(color: Color(0xFF9EA3AE), fontSize: 10.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: isCurrent
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE50914),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('PLAYING', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                )
                              : const Icon(Icons.play_circle_outline, color: Colors.white54, size: 20),
                          onTap: () {
                            Navigator.pop(ctx);
                            _switchEpisode(ep);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAudioLanguageDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131720),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B3244),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.multitrack_audio_rounded, color: Color(0xFFE50914), size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Select Audio Language',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF9EA3AE), size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF202634), height: 16),
                const SizedBox(height: 6),

                // English Option
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: !_isHindiAudio ? const Color(0xFFE50914).withValues(alpha: 0.15) : const Color(0xFF1A1F2C),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: !_isHindiAudio ? const Color(0xFFE50914) : const Color(0xFF202634),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: const Text('🇬🇧', style: TextStyle(fontSize: 22)),
                    title: const Text('English (Original Audio)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: const Text('Default original multi-channel audio', style: TextStyle(color: Color(0xFF9EA3AE), fontSize: 11)),
                    trailing: !_isHindiAudio
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFFE50914), size: 20)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _changeAudioLanguage(false);
                    },
                  ),
                ),

                // Hindi Option
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: _isHindiAudio ? const Color(0xFFE50914).withValues(alpha: 0.15) : const Color(0xFF1A1F2C),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isHindiAudio ? const Color(0xFFE50914) : const Color(0xFF202634),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: const Text('🇮🇳', style: TextStyle(fontSize: 22)),
                    title: Text(
                      widget.movie.isHindi ? 'Hindi (Original Audio)' : 'Hindi Dubbed (Dual Audio)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    subtitle: const Text('Official Netflix Hindi dubbed audio track', style: TextStyle(color: Color(0xFF9EA3AE), fontSize: 11)),
                    trailing: _isHindiAudio
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFFE50914), size: 20)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _changeAudioLanguage(true);
                    },
                  ),
                ),

                // Spanish Option
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2C),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF202634)),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: const Text('🇪🇸', style: TextStyle(fontSize: 22)),
                    title: const Text('Spanish (Original)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: const Text('Original Spanish European track', style: TextStyle(color: Color(0xFF9EA3AE), fontSize: 11)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _webController.runJavaScript('if(window.selectAudioByLang) window.selectAudioByLang("spa");');
                    },
                  ),
                ),

                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2C),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2B3244)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.tips_and_updates_outlined, color: Colors.amber, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tip: On web mirrors, you can also tap ⚙️ Settings on the player bar to switch language.',
                          style: TextStyle(color: Color(0xFF9EA3AE), fontSize: 11),
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
      backgroundColor: const Color(0xFF131720),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B3244),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.dns_rounded, color: Color(0xFFE50914), size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Choose Streaming Mirror',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF9EA3AE), size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF202634), height: 16),
                const SizedBox(height: 4),
                ..._currentServers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final s = entry.value;
                  final isSelected = idx == _selectedServerIndex;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE50914).withValues(alpha: 0.15) : const Color(0xFF1A1F2C),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFE50914) : const Color(0xFF202634),
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: isSelected ? const Color(0xFFE50914) : const Color(0xFF2B3244),
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF9EA3AE),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        s.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFFD0D4DC),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        'Quality: ${s.quality}',
                        style: const TextStyle(color: Color(0xFF9EA3AE), fontSize: 10.5),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFFE50914), size: 18)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _switchServer(idx);
                      },
                    ),
                  );
                }),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2C),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2B3244)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.tips_and_updates_outlined, color: Colors.amber, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'If video buffers or audio differs, switch between Mirror 1 (NetMirror) and Mirror 2 (VidLink Pro).',
                          style: TextStyle(color: Color(0xFF9EA3AE), fontSize: 11),
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
    final title = _currentEpisodeTitle ??
        (widget.episodeTitle != null
            ? '${widget.movie.title} - ${widget.episodeTitle}'
            : widget.movie.title);

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
                    backgroundColor: const Color(0xFF0A0C10),
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    titleSpacing: 0,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_currentServers.isNotEmpty && _selectedServerIndex < _currentServers.length ? _currentServers[_selectedServerIndex].name.split(' (')[0] : 'Mirror 1'} • ${_isHindiAudio ? "Hindi Dubbed 🇮🇳" : "English Audio 🇬🇧"}',
                          style: const TextStyle(
                            color: Color(0xFF9EA3AE),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    actions: [
                      // Audio Language Icon
                      IconButton(
                        icon: Icon(
                          Icons.multitrack_audio_rounded,
                          color: _isHindiAudio ? const Color(0xFFE50914) : Colors.white,
                          size: 22,
                        ),
                        tooltip: 'Audio Language',
                        onPressed: _showAudioLanguageDialog,
                      ),
                      // Episodes Drawer (for TV Series)
                      if (_episodes != null && _episodes!.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.video_library_rounded, color: Colors.white, size: 20),
                          tooltip: 'Episodes',
                          onPressed: _showEpisodesSheet,
                        ),
                      // Server Mirror Switcher Icon
                      IconButton(
                        icon: const Icon(Icons.dns_rounded, color: Colors.white, size: 20),
                        tooltip: 'Switch Mirror',
                        onPressed: _showServerSelectionSheet,
                      ),
                      // Cinema Mode (Rotate)
                      IconButton(
                        icon: const Icon(Icons.crop_rotate_rounded, color: Colors.white, size: 20),
                        tooltip: 'Cinema Mode',
                        onPressed: _toggleOrientation,
                      ),
                      // Reload
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF9EA3AE), size: 20),
                        tooltip: 'Reload Stream',
                        onPressed: () => _webController.reload(),
                      ),
                      const SizedBox(width: 4),
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
                            Colors.black.withValues(alpha: 0.85),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
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
                                  Text(
                                    '${_currentServers.isNotEmpty && _selectedServerIndex < _currentServers.length ? _currentServers[_selectedServerIndex].name : 'Mirror 1'}',
                                    style: const TextStyle(
                                      color: Color(0xFF9EA3AE),
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Quick Audio Selector Button
                            InkWell(
                              onTap: _showAudioLanguageDialog,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _isHindiAudio ? const Color(0xFFE50914).withValues(alpha: 0.3) : const Color(0xFF131720),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _isHindiAudio ? const Color(0xFFE50914) : const Color(0xFF202634)),
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
                            // Quick Episode Selector in Landscape
                            if (_episodes != null && _episodes!.isNotEmpty) ...[
                              InkWell(
                                onTap: _showEpisodesSheet,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF131720),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF202634)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.video_library_rounded, color: Colors.white70, size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        _currentEpisodeNumber != null ? 'Ep $_currentEpisodeNumber' : 'Episodes',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            // Quick Server Switcher in Landscape
                            InkWell(
                              onTap: _showServerSelectionSheet,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131720),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF202634)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.dns_rounded, color: Colors.white70, size: 14),
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
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.crop_rotate_rounded, color: Colors.white),
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
