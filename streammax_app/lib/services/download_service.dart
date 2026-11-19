import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';
import '../providers/provider.dart';
import 'firebase_service.dart';

class DownloadItem {
  final Movie movie;
  double progress; // 0.0 to 1.0
  bool isCompleted;
  String speed;
  String size;
  String? localPath;

  DownloadItem({
    required this.movie,
    this.progress = 0.0,
    this.isCompleted = false,
    this.speed = '3.5 MB/s',
    this.size = '1.4 GB',
    this.localPath,
  });

  Map<String, dynamic> toJson() => {
    'movie': movie.toJson(),
    'progress': progress,
    'isCompleted': isCompleted,
    'speed': speed,
    'size': size,
    'localPath': localPath,
  };

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    final isDone = json['isCompleted'] ?? true;
    return DownloadItem(
      movie: Movie.fromJson(json['movie'] as Map<String, dynamic>),
      progress: isDone ? 1.0 : ((json['progress'] as num?)?.toDouble() ?? 1.0),
      isCompleted: isDone,
      speed: json['speed'] ?? 'Completed',
      size: json['size'] ?? '1.4 GB',
      localPath: json['localPath'],
    );
  }
}

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final ValueNotifier<List<DownloadItem>> downloadsNotifier = ValueNotifier<List<DownloadItem>>([]);
  List<DownloadItem> get items => downloadsNotifier.value;
  bool _isInitialized = false;

  /// Initialize and load saved downloads from local persistent storage
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedList = prefs.getStringList('streammax_offline_downloads') ?? [];
      final loadedItems = <DownloadItem>[];

      for (final raw in savedList) {
        try {
          final item = DownloadItem.fromJson(json.decode(raw));
          // If marked completed, verify file exists or recover gracefully
          if (item.localPath != null && File(item.localPath!).existsSync()) {
            loadedItems.add(item);
          } else if (item.isCompleted) {
            loadedItems.add(item);
          }
        } catch (_) {}
      }

      downloadsNotifier.value = loadedItems;
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error loading persistent downloads: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = items.map((i) => json.encode(i.toJson())).toList();
      await prefs.setStringList('streammax_offline_downloads', list);
    } catch (e) {
      debugPrint('Error saving downloads: $e');
    }
  }

  static final Map<String, String> _webHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  /// Resolves shorteners / host landing pages (hblinks, hubcdn, hubdrive, hubcloud)
  /// into the real Cloudflare R2 / direct high-speed video download URL.
  static Future<String?> resolveDirectMediaUrl(String pageUrl) async {
    try {
      // Direct media file already
      if (pageUrl.contains('.r2.dev/') ||
          pageUrl.endsWith('.mp4') ||
          pageUrl.endsWith('.mkv')) {
        return pageUrl;
      }

      final client = http.Client();

      // Step 1: hblinks.lol/archives/...
      if (pageUrl.contains('hblinks.')) {
        final res = await client
            .get(Uri.parse(pageUrl), headers: _webHeaders)
            .timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          final hubcdnMatch = RegExp(r'href="(https://hubcdn\.club/file/[^"]+)"').firstMatch(res.body);
          if (hubcdnMatch != null) {
            final resolved = await resolveDirectMediaUrl(hubcdnMatch.group(1)!);
            if (resolved != null) return resolved;
          }
          final hubdriveMatch = RegExp(r'href="(https://hubdrive\.blog/file/[^"]+)"').firstMatch(res.body);
          if (hubdriveMatch != null) {
            final resolved = await resolveDirectMediaUrl(hubdriveMatch.group(1)!);
            if (resolved != null) return resolved;
          }
          final hubcloudMatch = RegExp(r'href="(https://hubcloud\.[^/]+/drive/[^"]+)"').firstMatch(res.body);
          if (hubcloudMatch != null) {
            final resolved = await resolveDirectMediaUrl(hubcloudMatch.group(1)!);
            if (resolved != null) return resolved;
          }
        }
      }

      // Step 2: hubcdn.club/file/...
      if (pageUrl.contains('hubcdn.club/file/')) {
        final res = await client
            .get(Uri.parse(pageUrl), headers: _webHeaders)
            .timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          final base64Match = RegExp(r'inventoryidea\.com/\?r=([A-Za-z0-9+/=]+)').firstMatch(res.body);
          if (base64Match != null) {
            final decoded = utf8.decode(base64.decode(base64Match.group(1)!));
            final uri = Uri.tryParse(decoded);
            final link = uri?.queryParameters['link'];
            if (link != null && link.startsWith('http')) {
              return link;
            }
            if (decoded.startsWith('http')) return decoded;
          }
        }
      }

      // Step 3: hubdrive.blog/file/...
      if (pageUrl.contains('hubdrive.blog/file/')) {
        final res = await client
            .get(Uri.parse(pageUrl), headers: _webHeaders)
            .timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          final driveMatch = RegExp(r'href="(https://hubcloud\.[^/]+/drive/[^"]+)"').firstMatch(res.body);
          if (driveMatch != null) {
            final resolved = await resolveDirectMediaUrl(driveMatch.group(1)!);
            if (resolved != null) return resolved;
          }
        }
      }

      // Step 4: hubcloud drive / download
      if (pageUrl.contains('hubcloud.')) {
        final res = await client
            .get(Uri.parse(pageUrl), headers: _webHeaders)
            .timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          final r2Match = RegExp(r'href="([^"]+\.r2\.dev/[^"]+)"').firstMatch(res.body);
          if (r2Match != null) return r2Match.group(1)!;

          final gamerMatch = RegExp(r'href="(https://gamerxyt\.com/hubcloud\.php[^"]+)"').firstMatch(res.body);
          if (gamerMatch != null) {
            final gamerRes = await client.get(Uri.parse(gamerMatch.group(1)!), headers: _webHeaders).timeout(const Duration(seconds: 10));
            final finalR2 = RegExp(r'href="([^"]+\.r2\.dev/[^"]+)"').firstMatch(gamerRes.body);
            if (finalR2 != null) return finalR2.group(1)!;
          }
        }
      }

      // Step 5: Direct dl link parameter
      if (pageUrl.contains('/dl/?link=')) {
        final uri = Uri.tryParse(pageUrl);
        final link = uri?.queryParameters['link'];
        if (link != null && link.isNotEmpty) return link;
      }
    } catch (_) {}
    return null;
  }

  /// Start real persistent download
  Future<void> startDownload(
    Movie movie, {
    String? downloadUrl,
    String? customTitle,
    String? customSize,
  }) async {
    // If already downloaded and file size is > 5MB, keep it
    final existing = items.where((item) => item.movie.id == movie.id).firstOrNull;
    if (existing != null) {
      if (existing.isCompleted &&
          existing.localPath != null &&
          File(existing.localPath!).existsSync() &&
          File(existing.localPath!).lengthSync() > 5000000) {
        return;
      }
      // Clean up old stub/failed download to restart cleanly
      await removeDownload(movie.id);
    }

    final displayMovie = customTitle != null
        ? movie.copyWith(title: customTitle)
        : movie;

    final newItem = DownloadItem(
      movie: displayMovie,
      size: customSize ?? 'Resolving download...',
    );
    downloadsNotifier.value = [...items, newItem];
    await _saveToStorage();

    try {
      FirebaseService().analytics?.logEvent(
        name: 'download_start',
        parameters: {
          'movie_title': displayMovie.title,
          'movie_id': displayMovie.id.toString(),
        },
      );
    } catch (_) {}

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${docsDir.path}/streammax_downloads');
      if (!saveDir.existsSync()) {
        await saveDir.create(recursive: true);
      }

      String? videoSource = downloadUrl;

      // Filter out iframe embed URLs from raw downloading so we never save HTML files
      if (videoSource != null &&
          (videoSource.contains('vidlink.pro') ||
           videoSource.contains('videasy.net') ||
           videoSource.contains('vidsrc.') ||
           videoSource.contains('autoembed.cc') ||
           videoSource.contains('2embed.cc') ||
           videoSource.contains('smashystream.com') ||
           videoSource.contains('multiembed.mov'))) {
        videoSource = null;
      }

      // 1. Resolve direct media URL if an intermediate page was provided
      if (videoSource != null && videoSource.isNotEmpty) {
        newItem.speed = 'Connecting to high-speed mirror...';
        downloadsNotifier.value = List.from(items);
        final resolved = await resolveDirectMediaUrl(videoSource);
        if (resolved != null && resolved.isNotEmpty) {
          videoSource = resolved;
        } else if (!videoSource.endsWith('.mp4') && !videoSource.endsWith('.mkv') && !videoSource.contains('.r2.dev/')) {
          videoSource = null; // Do not download unresolvable HTML page!
        }
      }

      // 2. If videoSource is still empty, search HDHub4u provider for the movie
      if (videoSource == null || videoSource.isEmpty) {
        newItem.speed = 'Searching HDHub4u Dual Audio...';
        downloadsNotifier.value = List.from(items);

        try {
          final cleanTitle = movie.title.replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
          final hdhub = ProviderRegistry.byId('hdhub4u');
          if (hdhub != null) {
            final listings = await hdhub.search(cleanTitle).timeout(const Duration(seconds: 15));
            if (listings.isNotEmpty) {
              final links = await hdhub.fetchLinks(listings.first).timeout(const Duration(seconds: 10));
              if (links.isNotEmpty) {
                for (final link in links) {
                  final resolved = await resolveDirectMediaUrl(link.url);
                  if (resolved != null && resolved.isNotEmpty) {
                    videoSource = resolved;
                    newItem.size = link.label;
                    break;
                  }
                }
              }
            }
          }
        } catch (_) {}
      }

      // 3. Fallback to direct video servers if available
      if (videoSource == null || videoSource.isEmpty) {
        for (final s in movie.servers) {
          if (s.url.contains('.mp4') || s.url.contains('r2.dev') || s.url.contains('.mkv')) {
            videoSource = s.url;
            break;
          }
        }
      }

      // If no valid video stream could be resolved, inform user without fake 1.1MB dummy
      if (videoSource == null ||
          videoSource.isEmpty ||
          (!videoSource.startsWith('http://') && !videoSource.startsWith('https://'))) {
        newItem.progress = 0.0;
        newItem.isCompleted = false;
        newItem.speed = 'Pick link in Dual Audio Search';
        downloadsNotifier.value = List.from(items);
        await _saveToStorage();
        return;
      }

      final ext = videoSource.toLowerCase().contains('.mkv') ? 'mkv' : 'mp4';
      final filePath = '${saveDir.path}/movie_${movie.id}.$ext';
      final file = File(filePath);

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(videoSource));
      request.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

      final response = await client.send(request);

      final totalBytes = response.contentLength ?? 1500000000;
      var receivedBytes = 0;
      final sink = file.openWrite();

      var lastUpdate = DateTime.now();
      var bytesSinceLastUpdate = 0;

      response.stream.listen(
        (chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          bytesSinceLastUpdate += chunk.length;

          final now = DateTime.now();
          final diff = now.difference(lastUpdate).inMilliseconds;
          if (diff >= 500) {
            final prog = (receivedBytes / totalBytes).clamp(0.0, 0.99);
            newItem.progress = prog;
            final speedKb = (bytesSinceLastUpdate / (diff / 1000)) / 1024;
            if (speedKb > 1024) {
              newItem.speed = '${(speedKb / 1024).toStringAsFixed(1)} MB/s';
            } else {
              newItem.speed = '${speedKb.toStringAsFixed(0)} KB/s';
            }
            newItem.size = '${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
            downloadsNotifier.value = List.from(items);
            lastUpdate = now;
            bytesSinceLastUpdate = 0;
          }
        },
        onDone: () async {
          try {
            await sink.flush();
            await sink.close();
          } catch (_) {}
          client.close();

          newItem.progress = 1.0;
          newItem.isCompleted = true;
          newItem.speed = 'Completed';
          newItem.size = '${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
          newItem.localPath = filePath;

          downloadsNotifier.value = List.from(items);
          await _saveToStorage();
        },
        onError: (e) async {
          try {
            await sink.close();
          } catch (_) {}
          client.close();

          newItem.speed = 'Download Interrupted';
          downloadsNotifier.value = List.from(items);
          await _saveToStorage();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Download error: $e');
      newItem.speed = 'Failed';
      downloadsNotifier.value = List.from(items);
      await _saveToStorage();
    }
  }

  /// Remove downloaded item and clean up storage
  Future<void> removeDownload(int movieId) async {
    final itemToRemove = items.where((item) => item.movie.id == movieId).firstOrNull;
    if (itemToRemove?.localPath != null) {
      try {
        final f = File(itemToRemove!.localPath!);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }

    downloadsNotifier.value = items.where((item) => item.movie.id != movieId).toList();
    await _saveToStorage();
  }
}
