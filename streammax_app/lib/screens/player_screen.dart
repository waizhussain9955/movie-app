import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../services/netmirror_service.dart';
import '../services/moviebox_service.dart';
import '../services/firebase_service.dart';
import 'provider_search_screen.dart';

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
  bool _playbackStarted = false;
  bool _isOfflineMode = false;
  bool _isLandscape = false;
  bool _isHindiAudio = false;
  int _fallbackAttempts = 0;
  String? _netMirrorStreamUrl;
  String? _movieBoxStreamUrl;
  int? _currentEpisodeNumber;
  String? _currentEpisodeTitle;
  List<Episode>? _episodes;
  bool _isLoadingEpisodes = false;

  // Real Mobile System Volume & Hardware Button Sync
  static const MethodChannel _audioChannel = MethodChannel('com.waiz.streammax/audio');
  double _volumeLevel = 1.0;
  bool _showVolumeHud = false;
  Timer? _volumeHudTimer;

  // Movie-Only Screen Brightness (Overlay Dimmer — Mobile OS brightness stays untouched)
  double _movieBrightness = 1.0;
  bool _showBrightnessHud = false;
  Timer? _brightnessHudTimer;

  HttpServer? _offlineServer;
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;
  bool _contentNotFound = false;
  Timer? _loadWatchdogTimer;

  @override
  void initState() {
    super.initState();
    _initSystemVolume();
    _selectedServerIndex = 0;
    _currentServers = List.from(widget.servers);
    // Money Heist (71446) respects initialHindiAudio toggle. Bollywood is native Hindi.
    // All other series (Game of Thrones, etc.) & movies strictly default to English!
    if (widget.movie.id == 71446) {
      _isHindiAudio = widget.initialHindiAudio;
    } else if (widget.movie.isHindi) {
      _isHindiAudio = true;
    } else {
      _isHindiAudio = false;
    }
    _currentEpisodeNumber = widget.episodeNumber;
    _currentEpisodeTitle = widget.episodeTitle;
    _episodes = widget.allEpisodes != null ? List.from(widget.allEpisodes!) : null;

    // Pre-fetch episodes in background if opened directly into TV player
    if ((_episodes == null || _episodes!.isEmpty) && (widget.seasonNumber != null || widget.movie.mediaType == 'tv')) {
      ApiService.getSeasonEpisodes(widget.movie.id, widget.seasonNumber ?? 1).then((eps) {
        if (mounted && eps.isNotEmpty) {
          setState(() => _episodes = eps);
        }
      }).catchError((_) {});
    }

    // Only for Money Heist in Hindi mode: select MovieBox or NetMirror
    if (_isHindiAudio && widget.movie.id == 71446) {
      for (var i = 0; i < _currentServers.length; i++) {
        if (_currentServers[i].url.contains('hakunaymatata.com') || _currentServers[i].name.contains('MovieBox')) {
          _movieBoxStreamUrl = _currentServers[i].url;
          _selectedServerIndex = i;
          break;
        }
        if (_currentServers[i].url.contains('.m3u8') || _currentServers[i].name.contains('Hindi')) {
          _netMirrorStreamUrl = _currentServers[i].url;
          if (_movieBoxStreamUrl == null) {
            _selectedServerIndex = i;
          }
        }
      }
    }
    _isOfflineMode = widget.localFilePath != null && File(widget.localFilePath!).existsSync();

    FirebaseService().logStreamStart(
      title: widget.movie.title,
      server: _currentServers.isNotEmpty && _selectedServerIndex < _currentServers.length ? _currentServers[_selectedServerIndex].name : 'Default',
    );

    // Enable device sensor rotation (Portrait & Landscape)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _initPlayer();
  }

  void _resetControlsTimer() {
    _hideControlsTimer?.cancel();
    if (!_controlsVisible) {
      if (mounted) setState(() => _controlsVisible = true);
    }
    _hideControlsTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _isLandscape) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<void> _initSystemVolume() async {
    try {
      _audioChannel.setMethodCallHandler((call) async {
        if (call.method == 'onVolumeChanged') {
          final val = (call.arguments as num?)?.toDouble();
          if (val != null && mounted) {
            setState(() {
              _volumeLevel = val.clamp(0.0, 1.0);
              _showVolumeHud = true;
              _showBrightnessHud = false;
            });
            _volumeHudTimer?.cancel();
            _volumeHudTimer = Timer(const Duration(milliseconds: 1600), () {
              if (mounted) setState(() => _showVolumeHud = false);
            });
          }
        }
      });

      await _audioChannel.invokeMethod('setInterceptVolumeKeys', {'enabled': true});
      final currentVol = await _audioChannel.invokeMethod<double>('getVolume');
      if (currentVol != null && mounted) {
        setState(() {
          _volumeLevel = currentVol.clamp(0.0, 1.0);
        });
      }
    } catch (e) {
      debugPrint('Audio channel init error: $e');
    }
  }

  @override
  void dispose() {
    try {
      _audioChannel.invokeMethod('setInterceptVolumeKeys', {'enabled': false});
      _audioChannel.setMethodCallHandler(null);
    } catch (_) {}
    _hideControlsTimer?.cancel();
    _loadWatchdogTimer?.cancel();
    _volumeHudTimer?.cancel();
    _brightnessHudTimer?.cancel();
    _offlineServer?.close(force: true);
    _offlineServer = null;
    // 1. Immediately kill video/audio playback so sound doesn't leak into background
    _webController.loadRequest(Uri.parse('about:blank'));
    // 2. Restore system orientation to portrait
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // 3. Restore status/navigation system bars
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
      _controlsVisible = false; // Keep landscape cinema clean — zero overlays on rotate
    });
    if (_isLandscape) {
      _hideControlsTimer?.cancel();
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      // Auto-scale HTML5 video to fill full viewport without second user tap
      _webController.runJavaScript('''
        try {
          var v = document.querySelector('video');
          if (v) {
            v.style.width = '100vw';
            v.style.height = '100vh';
            v.style.objectFit = 'contain';
          }
          var fsBtn = document.querySelector('.vjs-fullscreen-control, button[title*="Fullscreen"], button[aria-label*="Fullscreen"], .jw-icon-fullscreen');
          if (fsBtn) fsBtn.click();
        } catch(e) {}
      ''').catchError((_) {});
    } else {
      _hideControlsTimer?.cancel();
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _webController.runJavaScript('''
        try {
          if (document.fullscreenElement || document.webkitFullscreenElement) {
            if (document.exitFullscreen) document.exitFullscreen();
            else if (document.webkitExitFullscreen) document.webkitExitFullscreen();
          }
          var v = document.querySelector('video');
          if (v) {
            v.style.width = '100%';
            v.style.height = '100%';
            v.style.objectFit = 'contain';
          }
        } catch(e) {}
      ''').catchError((_) {});
    }
  }

  void _initPlayer() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      )
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'StreamMaxBridge',
        onMessageReceived: (JavaScriptMessage msg) {
          if (msg.message == 'PLAYBACK_STARTED') {
            if (mounted) {
              setState(() {
                _playbackStarted = true;
                _hasLoadedSuccessfully = true;
                _contentNotFound = false;
                _isLoading = false;
              });
              _loadWatchdogTimer?.cancel();
            }
          } else if (msg.message == 'CONTENT_NOT_FOUND') {
            if (mounted) {
              if (!_playbackStarted) {
                // Auto-switch seamlessly during initial search
                _handleAutoFallback('Missing content on server');
              } else if (!_contentNotFound) {
                setState(() => _contentNotFound = true);
              }
            }
          } else if (msg.message == 'ENTER_FULLSCREEN') {
            if (mounted && !_isLandscape) {
              _toggleOrientation();
            }
          } else if (msg.message == 'EXIT_FULLSCREEN') {
            if (mounted && _isLandscape) {
              _toggleOrientation();
            }
          }
        },
      );

    if (Platform.isAndroid && controller.platform is AndroidWebViewController) {
      final androidCtrl = controller.platform as AndroidWebViewController;
      androidCtrl.setMediaPlaybackRequiresUserGesture(false);
      androidCtrl.setAllowFileAccess(true);
      androidCtrl.setAllowContentAccess(true);
    }
    _webController = controller;

    if (_isOfflineMode) {
      _startOfflineLoopbackPlayback();
      return;
    } else {
      // Online mode with ad-blocking and auto-mirror failover
      _setupStreamingController();
    }
  }

  Future<void> _startOfflineLoopbackPlayback() async {
    final localPath = widget.localFilePath!;
    final localFile = File(localPath);

    if (!localFile.existsSync()) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline file not found. Please redownload.'),
            backgroundColor: Color(0xFFE50914),
          ),
        );
      }
      return;
    }

    try {
      _offlineServer?.close(force: true);
      _offlineServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _offlineServer!.listen((HttpRequest request) async {
        if (!localFile.existsSync()) {
          request.response.statusCode = HttpStatus.notFound;
          request.response.close();
          return;
        }

        final totalBytes = localFile.lengthSync();
        final ext = localPath.toLowerCase().endsWith('.mkv') ? 'x-matroska' : 'mp4';
        request.response.headers.contentType = ContentType('video', ext);
        request.response.headers.set('Accept-Ranges', 'bytes');
        request.response.headers.set('Access-Control-Allow-Origin', '*');

        final rangeHeader = request.headers.value('range');
        if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
          final parts = rangeHeader.substring(6).split('-');
          final start = int.tryParse(parts[0]) ?? 0;
          final end = parts.length > 1 && parts[1].isNotEmpty
              ? (int.tryParse(parts[1]) ?? (totalBytes - 1))
              : (totalBytes - 1);
          final contentLength = (end - start + 1).clamp(0, totalBytes);

          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set('Content-Range', 'bytes $start-$end/$totalBytes');
          request.response.contentLength = contentLength;
          await localFile.openRead(start, end + 1).pipe(request.response);
        } else {
          request.response.contentLength = totalBytes;
          await localFile.openRead().pipe(request.response);
        }
      });

      final streamUrl = 'http://127.0.0.1:${_offlineServer!.port}/video.mp4';
      final playerHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>${widget.movie.title} (Offline)</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      margin: 0;
      background-color: #000;
      color: #fff;
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      overflow: hidden;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    video {
      width: 100%;
      height: 100%;
      max-height: 100vh;
      object-fit: contain;
      outline: none;
    }
  </style>
</head>
<body>
  <video id="vPlayer" src="$streamUrl" controls autoplay playsinline></video>
  <script>
    window.addEventListener('DOMContentLoaded', function() {
      var v = document.getElementById('vPlayer');
      if (v) {
        v.play().catch(function(){});
      }
    });
  </script>
</body>
</html>
''';

      _webController
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) setState(() => _isLoading = false);
            },
            onPageFinished: (_) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasLoadedSuccessfully = true;
                });
              }
            },
            onWebResourceError: (_) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasLoadedSuccessfully = true;
                });
              }
            },
          ),
        )
        ..loadHtmlString(playerHtml, baseUrl: 'http://127.0.0.1:${_offlineServer!.port}/');

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _isLoading) {
          setState(() => _isLoading = false);
        }
      });
    } catch (e) {
      debugPrint('Error starting offline loopback playback: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupStreamingController() {
    _contentNotFound = false;
    _playbackStarted = false;
    _loadWatchdogTimer?.cancel();
    // Resilient watchdog: If server takes over 15s to respond, present the manual switch banner
    _loadWatchdogTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_playbackStarted && !_hasLoadedSuccessfully) {
        setState(() => _contentNotFound = true);
      }
    });

    final activeUrl = _currentServers.isNotEmpty
        ? _currentServers[_selectedServerIndex].url
        : 'https://vidlink.pro/movie/${widget.movie.id}?primaryColor=e50914';

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
              });
            }
            _injectAdBlocker();

            // Continuous video monitoring, kickstart & missing content detector
            _webController.runJavaScript('''
              try {
                // 1. Kickstart playback if paused/stalled
                function kickstart() {
                  var v = document.querySelector('video');
                  if (v && v.paused && v.currentTime === 0) {
                    v.play().catch(function() {
                      v.muted = true;
                      v.play().catch(function(){});
                    });
                  }
                  var btn = document.querySelector('.jw-display-icon-container, .vjs-big-play-button, button[aria-label="Play"], .play-icon, svg.lucide-play');
                  if (btn) {
                    try { btn.click(); } catch(e) {}
                  }
                }
                setTimeout(kickstart, 1000);
                setTimeout(kickstart, 2200);

                // 2. Continuous playback tracker
                function monitorPlay() {
                  var videos = document.querySelectorAll('video');
                  for (var i = 0; i < videos.length; i++) {
                    var v = videos[i];
                    if (!v._smTracked) {
                      v._smTracked = true;
                      v.addEventListener('playing', function() {
                        if (window.StreamMaxBridge) window.StreamMaxBridge.postMessage('PLAYBACK_STARTED');
                      });
                      v.addEventListener('timeupdate', function() {
                        if (v.currentTime > 0.5) {
                          if (window.StreamMaxBridge) window.StreamMaxBridge.postMessage('PLAYBACK_STARTED');
                        }
                      });
                    }
                    if (!v.paused && v.currentTime > 0) {
                      if (window.StreamMaxBridge) window.StreamMaxBridge.postMessage('PLAYBACK_STARTED');
                    }
                  }
                }
                setInterval(monitorPlay, 800);

                // 3. Check for content missing or 404 in iframe DOM
                function checkContent() {
                  var b = document.body ? (document.body.innerText || '') : '';
                  var t = document.title || '';
                  if (b.includes("We Couldn't Find This Content") ||
                      b.includes("Please check back another time") ||
                      b.includes("Video not found") ||
                      b.includes("404 Not Found") ||
                      b.includes("Cannot GET /") ||
                      b.includes("Episode Is Not Available") ||
                      b.includes("Media not found") ||
                      t.includes("Media not found")) {
                    if (window.StreamMaxBridge) {
                      window.StreamMaxBridge.postMessage("CONTENT_NOT_FOUND");
                    }
                  }
                }
                setTimeout(checkContent, 1200);
                setTimeout(checkContent, 2800);
              } catch(e) {}
            ''').catchError((_) {});

            // Unmute media on first user touch to comply with Android Autoplay Policy
            _webController.runJavaScript('''
              try {
                function unmuteMedia() {
                  var els = document.querySelectorAll('video, audio');
                  for (var i = 0; i < els.length; i++) {
                    els[i].muted = false;
                    els[i].defaultMuted = false;
                  }
                }
                window.addEventListener('click', unmuteMedia, { once: true });
                window.addEventListener('touchstart', unmuteMedia, { once: true });
              } catch(e) {}
            ''').catchError((_) {});
          },
          onWebResourceError: (WebResourceError error) {
            // CRITICAL FIX: Only handle fallback if MAIN frame failed during INITIAL load.
            // When user seeks/forwards video, HTML5 player aborts byte-range requests (net::ERR_ABORTED).
            // Subresource errors must never trigger fallback or switch servers!
            if (error.isForMainFrame == true && !_playbackStarted && !_hasLoadedSuccessfully) {
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

            // 2. STRICT WHITELIST: Verified movie stream hosts, CDNs, and media players
            final allowedHosts = [
              'vidlink.pro',
              'vidsrc.net',
              'vidsrc.me',
              'vidsrc.to',
              'vidsrc.rip',
              'vidsrc.xyz',
              'vidsrc.icu',
              'vidsrc.cc',
              'vidsrc.in',
              'vidsrc.pm',
              'autoembed.to',
              'autoembed.me',
              'autoembed.co',
              'multiembed.mov',
              'multiembed',
              '2embed.skin',
              '2embed.cc',
              'smashystream.com',
              'anyembed.xyz',
              'cinesrc.st',
              'superembed.stream',
              'embed.su',
              'jwplayer.com',
              'jwplatform.com',
              'cloudflare',
              'vidcloud',
              'megacloud',
              'rabbitstream',
              'upcloud',
              'filemoon',
              'streamtape',
              'streamwish',
              'vidstream',
              'rapid-cloud',
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
              // Provider system (MLSBD + HDHub4u)
              'mlsbd.co',
              'savelinks.me',
              'hdhubinfo.com',
              'hubcdn.club',
              'hubdrive.blog',
              'hblinks.lol',
              '4khdhub.one',
              'playdrive.vip',
              'hdstream4u.com',
              'hubcloud',
              'inventoryidea.com',
              'r2.dev',
              'drive.google.com',
              'googleusercontent.com',
              'pixeldrain',
              'fastcloud',
              'terabox',
              // MovieBox & Hakuna Matata CDN
              'hakunaymatata.com',
              'movie-box.co',
              'aoneroom.com',
              'videodownloader.site',
            ];

            final isAllowed = allowedHosts.any((host) => url.contains(host));
            if (!isAllowed) {
              debugPrint('🛡️ [AdBlocker] Blocked unverified domain: $url');
              return NavigationDecision.prevent;
            }

            // Direct video download interceptor
            if (url.endsWith('.mp4') ||
                url.endsWith('.mkv') ||
                url.contains('/dl/?link=') ||
                (url.contains('.r2.dev') && !url.contains('.html'))) {
              DownloadService().startDownload(
                widget.movie,
                downloadUrl: request.url,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '⬇️ Video download captured for "${widget.movie.title}"! Saving to "Downloads" tab.',
                  ),
                  backgroundColor: const Color(0xFFE50914),
                  duration: const Duration(seconds: 4),
                ),
              );
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
    } else if (url.contains('.mp4')) {
      String streamUrl = url;
      String referer = 'https://videodownloader.site/';
      if (url.contains('#referer=')) {
        final parts = url.split('#referer=');
        streamUrl = parts[0];
        referer = parts[1];
        if (!referer.endsWith('/')) referer = '$referer/';
      }
      _webController.loadHtmlString(
        _buildDirectMp4PlayerHtml(streamUrl, referer: referer),
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
  <meta name="referrer" content="origin">
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
      if (window.StreamMaxBridge) window.StreamMaxBridge.postMessage('PLAYBACK_STARTED');
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

    window.setPlayerVolume = function(vol) {
      if (video) {
        video.muted = (vol <= 0.01);
        video.defaultMuted = false;
        video.volume = Math.max(0, Math.min(1, vol));
        if (unmuteBtn) unmuteBtn.style.display = (video.muted) ? 'block' : 'none';
      }
    };

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
          if (url.indexOf('/hs/') !== -1) {
            xhr.setRequestHeader('Ott', 'hs');
          } else if (url.indexOf('/pv/') !== -1) {
            xhr.setRequestHeader('Ott', 'pv');
          } else if (url.indexOf('/nf/') !== -1) {
            xhr.setRequestHeader('Ott', 'nf');
          }
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

  String _buildDirectMp4PlayerHtml(String mp4Url, {String referer = 'https://videodownloader.site/'}) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta name="referrer" content="origin">
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
      background: rgba(35, 134, 54, 0.92);
      color: white; border: 1px solid rgba(255,255,255,0.25);
      padding: 6px 14px; border-radius: 20px;
      font-size: 12px; font-weight: bold;
      display: flex; align-items: center; gap: 6px;
      z-index: 100;
      box-shadow: 0 4px 14px rgba(0,0,0,0.6);
      backdrop-filter: blur(6px);
    }
    #unmuteBtn {
      position: absolute; bottom: 65px; left: 50%; transform: translateX(-50%);
      background: rgba(229, 9, 20, 0.95); color: #fff;
      padding: 10px 20px; border-radius: 25px;
      font-size: 14px; font-weight: bold;
      cursor: pointer; z-index: 150;
      box-shadow: 0 4px 20px rgba(0,0,0,0.8);
      display: none;
    }
  </style>
</head>
<body>
  <div id="videoContainer">
    <div class="video-wrapper">
      <video id="videoPlayer" src="$mp4Url" controls autoplay playsinline controlsList="nodownload"></video>
      <div id="playOverlay" onclick="togglePlayPause()">
        <svg width="30" height="30" viewBox="0 0 24 24" fill="white" style="margin-left: 3px;">
          <path d="M8 5v14l11-7z"/>
        </svg>
      </div>
      <div class="audio-pill">
        <span>🇮🇳 MovieBox VIP (Hindi Dubbed)</span>
      </div>
      <div id="unmuteBtn" onclick="unmuteAudio()">🔊 Tap to Unmute</div>
    </div>
  </div>
  <script>
    var video = document.getElementById('videoPlayer');
    var overlay = document.getElementById('playOverlay');
    var unmuteBtn = document.getElementById('unmuteBtn');

    function togglePlayPause() {
      if (video.paused) {
        video.muted = false;
        video.play().catch(function() {
          video.muted = true;
          video.play();
        });
      } else {
        video.pause();
      }
    }

    function unmuteAudio() {
      video.muted = false;
      video.volume = 1.0;
      if (unmuteBtn) unmuteBtn.style.display = 'none';
    }

    video.addEventListener('play', function() {
      overlay.classList.add('hidden');
      if (window.StreamMaxBridge) window.StreamMaxBridge.postMessage('PLAYBACK_STARTED');
    });
    video.addEventListener('pause', function() {
      overlay.classList.remove('hidden');
    });

    video.addEventListener('loadedmetadata', function() {
      video.muted = false;
      video.volume = 1.0;
      var p = video.play();
      if (p !== undefined) {
        p.catch(function() {
          video.muted = true;
          video.play();
          if (unmuteBtn) unmuteBtn.style.display = 'block';
        });
      }
    });

    window.addEventListener('click', unmuteAudio, { once: true });
    window.addEventListener('touchstart', unmuteAudio, { once: true });
  </script>
</body>
</html>
''';
  }

  void _injectAdBlocker() {
    final adScript = '''
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
            var isSafeMedia = href.includes('vidlink') || 
                              href.includes('vidsrc') || 
                              href.includes('autoembed') || 
                              href.includes('multiembed') || 
                              href.includes('2embed') || 
                              href.includes('smashy');
            if (href.startsWith('http') && !isSafeMedia) {
              e.preventDefault();
              e.stopPropagation();
              console.log('Blocked clickjacking ad redirect:', href);
              return false;
            }
          }
        }, true);

        // 4. Unmute media on first user touch to comply with Android Autoplay Policy
        var unmuteAllMedia = function() {
          try {
            var media = document.querySelectorAll('video, audio');
            for (var i = 0; i < media.length; i++) {
              media[i].muted = false;
              media[i].defaultMuted = false;
            }
          } catch(e) {}
        };
        window.addEventListener('click', unmuteAllMedia, { once: true });
        window.addEventListener('touchstart', unmuteAllMedia, { once: true });

        // 5. Auto-detect and select Hindi audio track ONLY if user requested Hindi audio
        ${_isHindiAudio ? '''
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
        ''' : ''}

        // 6. Seamless Fullscreen Sync between HTML5 Player and Flutter Orientation
        var handleFsChange = function() {
          try {
            var isFs = !!(document.fullscreenElement || document.webkitFullscreenElement || document.mozFullScreenElement);
            if (window.StreamMaxBridge) {
              window.StreamMaxBridge.postMessage(isFs ? 'ENTER_FULLSCREEN' : 'EXIT_FULLSCREEN');
            }
          } catch(e) {}
        };
        document.addEventListener('fullscreenchange', handleFsChange);
        document.addEventListener('webkitfullscreenchange', handleFsChange);
      })();
    ''';
    _webController.runJavaScript(adScript).catchError((_) {});
  }

  void _handleAutoFallback(String reason) {
    // STRICT RULE: Never auto-fallback once video has started playing or during network buffering!
    if (_playbackStarted) return;
    if (_fallbackAttempts >= _currentServers.length) {
      if (mounted && !_contentNotFound) {
        setState(() => _contentNotFound = true);
      }
      return;
    }
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
        _playbackStarted = false;
        _contentNotFound = false;
      });
      _loadWatchdogTimer?.cancel();
      _loadWatchdogTimer = Timer(const Duration(seconds: 15), () {
        if (mounted && !_playbackStarted && !_hasLoadedSuccessfully) {
          setState(() => _contentNotFound = true);
        }
      });
      _loadActiveStream(_currentServers[index].url);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: const Color(0xFFE50914).withValues(alpha: 0.5), width: 1.0),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            backgroundColor: const Color(0xF0131720),
            content: Text(
              auto
                  ? '⚡ Auto-connecting: Server ${index + 1}...'
                  : 'Switched to Server ${index + 1}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            duration: const Duration(seconds: 2),
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
      _playbackStarted = false;
      _fallbackAttempts = 0;
      _contentNotFound = false;
    });

    String? movieBoxUrl;
    if (_isHindiAudio || widget.movie.isHindi || widget.movie.isHindiDubbed || widget.movie.id == 71446) {
      try {
        movieBoxUrl = await MovieBoxService.getHindiStream(
          tmdbId: widget.movie.id,
          isTv: true,
          season: ep.seasonNumber,
          episode: ep.episodeNumber,
        );
      } catch (_) {}
    }

    String? netmirrorUrl;
    try {
      netmirrorUrl = await NetMirrorService.resolveStream(
        widget.movie.title,
        isTv: true,
        season: ep.seasonNumber,
        episode: ep.episodeNumber,
      ).timeout(const Duration(seconds: 15), onTimeout: () => null);
    } catch (_) {}

    final servers = ApiService.generateServers(
      widget.movie.id,
      isTv: true,
      season: ep.seasonNumber,
      episode: ep.episodeNumber,
      isHindiAudio: _isHindiAudio,
      netMirrorStreamUrl: netmirrorUrl,
      movieBoxStreamUrl: movieBoxUrl,
      originalLanguage: widget.movie.originalLanguage,
    );

    setState(() {
      _currentServers = servers;
      _netMirrorStreamUrl = netmirrorUrl;
      _movieBoxStreamUrl = movieBoxUrl;
      _selectedServerIndex = 0;
    });

    _loadWatchdogTimer?.cancel();
    _loadWatchdogTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_playbackStarted && !_hasLoadedSuccessfully) {
        setState(() => _contentNotFound = true);
      }
    });

    _loadActiveStream(servers.first.url);
  }

  void _showEpisodesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131720),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            // If episodes list is empty, trigger load inside the modal
            if ((_episodes == null || _episodes!.isEmpty) && !_isLoadingEpisodes) {
              _isLoadingEpisodes = true;
              ApiService.getSeasonEpisodes(widget.movie.id, widget.seasonNumber ?? 1).then((eps) {
                if (mounted) {
                  setState(() {
                    _episodes = eps;
                    _isLoadingEpisodes = false;
                  });
                  setModalState(() {});
                }
              }).catchError((_) {
                if (mounted) {
                  setState(() => _isLoadingEpisodes = false);
                  setModalState(() {});
                }
              });
            }

            final eps = _episodes ?? [];

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.75,
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
                          'Season ${widget.seasonNumber ?? 1} Episodes (${eps.length})',
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
                    if (_isLoadingEpisodes && eps.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Color(0xFFE50914)),
                              SizedBox(height: 14),
                              Text('Loading episodes...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    else if (eps.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text('No episodes found for this season', style: TextStyle(color: Color(0xFF9EA3AE), fontSize: 13)),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: eps.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final ep = eps[idx];
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
      },
    );
  }

  void _setVolume(double vol) {
    final clamped = vol.clamp(0.0, 1.0);
    setState(() {
      _volumeLevel = clamped;
      _showVolumeHud = true;
      _showBrightnessHud = false;
    });
    _audioChannel.invokeMethod('setVolume', {'volume': clamped}).catchError((_) {});
    _volumeHudTimer?.cancel();
    _volumeHudTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showVolumeHud = false);
    });
  }

  void _setBrightness(double level) {
    final clamped = level.clamp(0.15, 1.0);
    setState(() {
      _movieBrightness = clamped;
      _showBrightnessHud = true;
      _showVolumeHud = false;
    });
    _brightnessHudTimer?.cancel();
    _brightnessHudTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showBrightnessHud = false);
    });
  }

  void _showVolumeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131720),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final volPct = (_volumeLevel * 100).round();
            final brightPct = (_movieBrightness * 100).round();
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B3244),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Player Controls',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // SECTION 1: Mobile Media Volume
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _volumeLevel <= 0.01
                                  ? Icons.volume_off_rounded
                                  : (_volumeLevel < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                              color: const Color(0xFFE50914),
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Device Volume',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE50914), width: 0.8),
                          ),
                          child: Text(
                            '$volPct%',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFFE50914),
                        inactiveTrackColor: const Color(0xFF2B3244),
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        overlayColor: const Color(0xFFE50914).withValues(alpha: 0.2),
                        trackHeight: 6,
                      ),
                      child: Slider(
                        value: _volumeLevel,
                        min: 0.0,
                        max: 1.0,
                        divisions: 100,
                        onChanged: (val) {
                          setModalState(() {});
                          _setVolume(val);
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [0.0, 0.25, 0.5, 0.75, 1.0].map((v) {
                        final label = v == 0.0 ? 'Mute' : '${(v * 100).round()}%';
                        final isSel = (_volumeLevel - v).abs() < 0.05;
                        return InkWell(
                          onTap: () {
                            setModalState(() {});
                            _setVolume(v);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFFE50914) : const Color(0xFF1B202B),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isSel ? const Color(0xFFE50914) : const Color(0xFF2B3244)),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isSel ? Colors.white : const Color(0xFF9EA3AE),
                                fontSize: 11.5,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),
                    const Divider(color: Color(0xFF202634), height: 1),
                    const SizedBox(height: 20),

                    // SECTION 2: Movie-Only Screen Brightness
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _movieBrightness <= 0.35
                                  ? Icons.brightness_low_rounded
                                  : (_movieBrightness < 0.75 ? Icons.brightness_medium_rounded : Icons.brightness_high_rounded),
                              color: const Color(0xFFFFB300),
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Movie Screen Brightness',
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Movie display only • Mobile brightness unchanged',
                                  style: TextStyle(color: Color(0xFF8E95A5), fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFB300), width: 0.8),
                          ),
                          child: Text(
                            '$brightPct%',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFFFFB300),
                        inactiveTrackColor: const Color(0xFF2B3244),
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        overlayColor: const Color(0xFFFFB300).withValues(alpha: 0.2),
                        trackHeight: 6,
                      ),
                      child: Slider(
                        value: _movieBrightness,
                        min: 0.15,
                        max: 1.0,
                        divisions: 85,
                        onChanged: (val) {
                          setModalState(() {});
                          _setBrightness(val);
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [0.25, 0.5, 0.75, 1.0].map((v) {
                        final label = '${(v * 100).round()}%';
                        final isSel = (_movieBrightness - v).abs() < 0.05;
                        return InkWell(
                          onTap: () {
                            setModalState(() {});
                            _setBrightness(v);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFFFFB300) : const Color(0xFF1B202B),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isSel ? const Color(0xFFFFB300) : const Color(0xFF2B3244)),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isSel ? Colors.black : const Color(0xFF9EA3AE),
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            );
          },
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
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131720),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: SafeArea(
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
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ..._currentServers.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final s = entry.value;
                            final isSelected = idx == _selectedServerIndex;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFE50914).withValues(alpha: 0.15)
                                    : const Color(0xFF1A1F2C),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFE50914) : const Color(0xFF202634),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 12,
                                  backgroundColor:
                                      isSelected ? const Color(0xFFE50914) : const Color(0xFF2B3244),
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
                                    ? const Icon(Icons.check_circle_rounded,
                                        color: Color(0xFFE50914), size: 18)
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
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1F2C),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF2B3244)),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '• Server 1 (NetMirror VIP): Direct Hindi Dubbed Audio track.\n• Server 2 (VidLink Pro) & Server 3: Clean, uninterrupted 1080p full video.\n• Agar Server 1 par NetMirror ka warning clip aaye, to full movie video ke liye Server 2 ya 3 select karein.',
                                    style: TextStyle(
                                        color: Color(0xFF9EA3AE), fontSize: 11.5, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: const Color(0xFFE50914).withValues(alpha: 0.5), width: 1.0),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          backgroundColor: const Color(0xF0131720),
          content: Text(
            isHindi ? '🇮🇳 Hindi Dubbed track activated!' : '🇬🇧 English Original Audio active',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Case 2: Resolve true Hindi sources: MovieBox (clean 100% Hindi dub MP4) and NetMirror (Dual-Audio HLS)
    // ONLY for Money Heist (71446) or genuine Bollywood (isHindi)!
    if (isHindi && _movieBoxStreamUrl == null && (widget.movie.id == 71446 || widget.movie.isHindi)) {
      setState(() => _isLoading = true);
      try {
        final resolved = await MovieBoxService.getHindiStream(
          tmdbId: widget.movie.id,
          isTv: widget.movie.mediaType == 'tv',
          season: widget.seasonNumber ?? 1,
          episode: widget.episodeNumber ?? 1,
        );
        if (resolved != null && resolved.isNotEmpty) {
          _movieBoxStreamUrl = resolved;
        }
      } catch (_) {}
    }

    if (isHindi && _netMirrorStreamUrl == null && (widget.movie.id == 71446 || widget.movie.isHindi)) {
      setState(() => _isLoading = true);
      try {
        final resolved = await NetMirrorService.resolveStream(
          widget.movie.title,
          isTv: widget.movie.mediaType == 'tv',
          season: widget.seasonNumber ?? 1,
          episode: widget.episodeNumber ?? 1,
        ).timeout(const Duration(seconds: 15), onTimeout: () => null);
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
        netMirrorStreamUrl: _netMirrorStreamUrl,
        movieBoxStreamUrl: _movieBoxStreamUrl,
        originalLanguage: widget.movie.originalLanguage,
      );
      _selectedServerIndex = 0;
    });

    _loadActiveStream(_currentServers.first.url);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: const Color(0xFFE50914).withValues(alpha: 0.5), width: 1.0),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          backgroundColor: const Color(0xF0131720),
          content: Text(
            isHindi
                ? (_netMirrorStreamUrl != null
                    ? '🇮🇳 Hindi Dual Audio stream loaded'
                    : '🇮🇳 Hindi mode active! VidLink Pro / Videasy me player ⚙️ settings se audio check karein')
                : '🇬🇧 Switched to English Original Audio',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
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
          canPop: !isLandscape,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            // When in landscape fullscreen, back button/gesture minimizes to portrait!
            if (isLandscape) {
              _toggleOrientation();
            }
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
                    leadingWidth: 56,
                    leading: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    titleSpacing: 4,
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
                          '${_currentServers.isNotEmpty && _selectedServerIndex < _currentServers.length ? _currentServers[_selectedServerIndex].name.split(' (')[0] : 'Mirror 1'} • ${_isHindiAudio ? "Hindi Dubbed 🇮🇳" : (widget.movie.originalLanguage == "ur" ? "Urdu Audio 🇵🇰" : "English Audio 🇬🇧")}',
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
                      // Episodes Drawer (for TV Series)
                      if (widget.movie.mediaType == 'tv' || widget.seasonNumber != null || (_episodes != null && _episodes!.isNotEmpty))
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          icon: const Icon(Icons.video_library_rounded, color: Colors.white, size: 22),
                          tooltip: 'Episodes',
                          onPressed: _showEpisodesSheet,
                        ),
                      // Cinema Mode (Rotate)
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        icon: const Icon(Icons.crop_rotate_rounded, color: Colors.white, size: 22),
                        tooltip: 'Cinema Mode',
                        onPressed: _toggleOrientation,
                      ),
                      // More / Settings Popup Menu (Volume, Reload, Downloads)
                      PopupMenuButton<String>(
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF9EA3AE), size: 20),
                        color: const Color(0xFF131720),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF202634)),
                        ),
                        onSelected: (val) {
                          if (val == 'audio') {
                            _showAudioLanguageDialog();
                          } else if (val == 'volume') {
                            _showVolumeDialog();
                          } else if (val == 'server') {
                            _showServerSelectionSheet();
                          } else if (val == 'download') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProviderSearchScreen(
                                  initialQuery: widget.movie.title,
                                  movie: widget.movie,
                                ),
                              ),
                            );
                          } else if (val == 'reload') {
                            _webController.reload();
                          }
                        },
                        itemBuilder: (ctx) => [
                          if (!_isOfflineMode && (widget.movie.id == 71446 || widget.movie.isHindi))
                            PopupMenuItem(
                              value: 'audio',
                              child: Row(
                                children: [
                                  const Icon(Icons.multitrack_audio_rounded, color: Color(0xFFE50914), size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isHindiAudio ? 'Audio: Hindi Dubbed 🇮🇳' : 'Audio: English 🇬🇧',
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            value: 'volume',
                            child: Row(
                              children: [
                                const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 10),
                                Text('Volume & Brightness (${(_volumeLevel * 100).round()}%)', style: const TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          if (!_isOfflineMode)
                            const PopupMenuItem(
                              value: 'server',
                              child: Row(
                                children: [
                                  Icon(Icons.dns_rounded, color: Color(0xFFE50914), size: 18),
                                  SizedBox(width: 10),
                                  Text('Change Mirror', style: TextStyle(color: Colors.white, fontSize: 13)),
                                ],
                              ),
                            ),
                          if (!_isOfflineMode)
                            const PopupMenuItem(
                              value: 'download',
                              child: Row(
                                children: [
                                  Icon(Icons.file_download_outlined, color: Color(0xFF00E676), size: 18),
                                  SizedBox(width: 10),
                                  Text('Dual Audio Downloads', style: TextStyle(color: Colors.white, fontSize: 13)),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'reload',
                            child: Row(
                              children: [
                                Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 10),
                                Text('Reload Stream', style: TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
            body: SafeArea(
              top: false,
              bottom: !isLandscape,
              child: Stack(
                children: [
                  // Full Screen Video Stream with tap handler for landscape auto-hide
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (isLandscape) {
                          setState(() => _controlsVisible = !_controlsVisible);
                          if (_controlsVisible) {
                            _resetControlsTimer();
                          } else {
                            _hideControlsTimer?.cancel();
                          }
                        }
                      },
                      child: WebViewWidget(controller: _webController),
                    ),
                  ),

                  // Movie Screen Local Dimmer (Adjusts ONLY movie brightness, never touches mobile system brightness)
                  if (_movieBrightness < 0.99)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: Colors.black.withValues(
                            alpha: (1.0 - _movieBrightness).clamp(0.0, 0.85),
                          ),
                        ),
                      ),
                    ),

                // Floating Controls Overlay in Landscape Cinema Mode (Auto-Hides after 3.5s)
                if (isLandscape)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: IgnorePointer(
                        ignoring: !_controlsVisible,
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
                                  tooltip: 'Minimize to Portrait',
                                  onPressed: _toggleOrientation,
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
                                        _currentServers.isNotEmpty && _selectedServerIndex < _currentServers.length ? _currentServers[_selectedServerIndex].name : 'Mirror 1',
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
                                // Quick Audio Selector Button (ONLY for Money Heist or genuine Bollywood)
                                if (!_isOfflineMode && (widget.movie.id == 71446 || widget.movie.isHindi)) ...[
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
                                ],
                                // Quick Episode Selector in Landscape
                                if (widget.movie.mediaType == 'tv' || widget.seasonNumber != null || (_episodes != null && _episodes!.isNotEmpty)) ...[
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
                                // Volume Slider in Landscape
                                InkWell(
                                  onTap: _showVolumeDialog,
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
                                        Icon(
                                          _volumeLevel <= 0.01
                                              ? Icons.volume_off_rounded
                                              : (_volumeLevel < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                                          color: Colors.white70,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '${(_volumeLevel * 100).round()}%',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Movie Screen Brightness in Landscape
                                InkWell(
                                  onTap: _showVolumeDialog,
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
                                        const Icon(
                                          Icons.brightness_6_rounded,
                                          color: Color(0xFFFFB300),
                                          size: 14,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '${(_movieBrightness * 100).round()}%',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white38),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.fullscreen_exit_rounded, size: 18),
                                  label: const Text('Minimize', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: _toggleOrientation,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Content Not Found / Slow Server Failover Banner
                if (_contentNotFound && !_isOfflineMode)
                  Positioned(
                    top: isLandscape ? 12 : 8,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xF0131720),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.5), width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentServers.isNotEmpty && _selectedServerIndex < _currentServers.length
                                      ? 'Server ${_selectedServerIndex + 1} slow / not responding'
                                      : 'Server slow / not responding',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                Text(
                                  _currentServers.length > 1
                                      ? 'Tap Switch ⚡ for Server ${((_selectedServerIndex + 1) % _currentServers.length) + 1}'
                                      : 'Tap Switch ⚡ to choose another mirror',
                                  style: const TextStyle(color: Color(0xFF9EA3AE), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE50914),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              if (_currentServers.length > 1) {
                                final nextIdx = (_selectedServerIndex + 1) % _currentServers.length;
                                _switchServer(nextIdx);
                              } else {
                                _showServerSelectionSheet();
                              }
                              setState(() => _contentNotFound = false);
                            },
                            child: const Text('Switch ⚡', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Swipe on left side to smoothly control movie screen brightness up/down
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width * 0.45,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragUpdate: (details) {
                          final delta = -details.delta.dy / 200.0;
                          _setBrightness(_movieBrightness + delta);
                        },
                      ),
                    ),
                  ),
                ),

                // Swipe on right side to smoothly control mobile media volume up/down
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width * 0.45,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragUpdate: (details) {
                          final delta = -details.delta.dy / 200.0;
                          _setVolume(_volumeLevel + delta);
                        },
                      ),
                    ),
                  ),
                ),

                // Smooth Volume HUD Indicator (Center of screen)
                if (_showVolumeHud)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE50914), width: 1.5),
                        boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 12)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _volumeLevel <= 0.01
                                ? Icons.volume_off_rounded
                                : (_volumeLevel < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                            color: const Color(0xFFE50914),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Volume: ${(_volumeLevel * 100).round()}%',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Smooth Movie Screen Brightness HUD Indicator (Center of screen)
                if (_showBrightnessHud)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
                        boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 12)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _movieBrightness <= 0.35
                                ? Icons.brightness_low_rounded
                                : (_movieBrightness < 0.75
                                    ? Icons.brightness_medium_rounded
                                    : Icons.brightness_high_rounded),
                            color: const Color(0xFFFFB300),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Brightness: ${(_movieBrightness * 100).round()}%',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
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
          ),
        );
      },
    );
  }
}
