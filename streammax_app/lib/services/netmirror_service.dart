import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NetMirrorService {
  static String? _resolvedApiUrl;
  static DateTime? _apiResolvedAt;
  static final Map<String, String> _streamCache = {};

  static const List<String> _discoveryDomains = [
    'https://mobiledetects.com',
    'https://mobiledetect.app',
    'https://mobidetect.store',
    'https://mobidetect.cc',
    'https://mobidetect.art',
    'https://mobidetect.live',
    'https://mobidetect.pro',
    'https://mobidetect.xyz',
  ];

  static const Map<String, String> _headers = {
    'X-Requested-With': 'NetmirrorNewTV v1.0',
    'Ott': 'nf',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/124 Mobile Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
  };

  /// Resolve active NewTV backend URL (with 1-hour cache)
  static Future<String?> getApiUrl() async {
    if (_resolvedApiUrl != null && _apiResolvedAt != null) {
      if (DateTime.now().difference(_apiResolvedAt!).inMinutes < 60) {
        return _resolvedApiUrl;
      }
    }

    for (final domain in _discoveryDomains) {
      try {
        final res = await http.get(
          Uri.parse('$domain/checknewtv.php'),
          headers: _headers,
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['token_hash'] != null) {
            final decoded = utf8.decode(base64.decode(data['token_hash'].toString()));
            _resolvedApiUrl = decoded.replaceAll(RegExp(r'/+$'), '');
            _apiResolvedAt = DateTime.now();
            debugPrint('✅ [NetMirror] Resolved active API: $_resolvedApiUrl');
            return _resolvedApiUrl;
          }
        }
      } catch (_) {}
    }

    // Default known reliable fallback
    _resolvedApiUrl = 'https://tv.imgcdn.kim';
    _apiResolvedAt = DateTime.now();
    return _resolvedApiUrl;
  }

  static const List<String> _abuseMarkers = [
    '220884',
    'veed',
    'abuse',
    'ratelimit',
    'stop_abuse',
    'too many requests',
    'wait few minutes',
  ];

  static bool _looksAbusive(String text) {
    final lower = text.toLowerCase();
    return _abuseMarkers.any(lower.contains);
  }

  /// Check whether a resolved HLS link is actually the NetMirror
  /// abuse / rate-limit clip ("STOP — Too Many Requests").
  /// The audio rendition stays clean, so only a playlist check can catch it.
  /// Returns true when the stream must be rejected (caller falls back to a
  /// clean embed server and must NOT cache the flagged URL).
  static Future<bool> _isAbuseStream(String videoLink, String referer) async {
    // 1. The link itself sometimes carries the marker.
    if (_looksAbusive(videoLink)) return true;

    try {
      // 2. Master playlist. The CDN needs the Referer header here —
      //    without it the request answers 404 and the check silently passes
      //    (that is why the old filter, which sent no Referer, never caught
      //    anything even before it was removed).
      final masterRes = await http.get(
        Uri.parse(videoLink),
        headers: {..._headers, 'Referer': referer},
      ).timeout(const Duration(seconds: 4));
      if (masterRes.statusCode != 200) return false;
      final master = masterRes.body;
      if (_looksAbusive(master)) return true;

      // 3. Video rendition playlist. The abuse clip usually hides here —
      //    the master only lists rendition URIs. Check the first (default)
      //    video level; when the IP is rate-limited every level carries the
      //    same clip, so one check is representative.
      final lines = master.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('#EXT-X-STREAM-INF')) {
          var j = i + 1;
          while (j < lines.length &&
              (lines[j].trim().isEmpty || lines[j].trim().startsWith('#'))) {
            j++;
          }
          if (j >= lines.length) break;
          final renditionUri = lines[j].trim();
          final renditionUrl = renditionUri.startsWith('http')
              ? renditionUri
              : Uri.parse(videoLink).resolve(renditionUri).toString();
          try {
            final renditionRes = await http.get(
              Uri.parse(renditionUrl),
              headers: {..._headers, 'Referer': referer},
            ).timeout(const Duration(seconds: 4));
            if (renditionRes.statusCode == 200 &&
                _looksAbusive(renditionRes.body)) {
              return true;
            }
          } catch (_) {}
          break;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Search and resolve direct HLS stream (.m3u8) with Multi-Audio (Hindi, English, etc.)
  static Future<String?> resolveStream(
    String title, {
    bool isTv = false,
    int season = 1,
    int episode = 1,
  }) async {
    final cacheKey = '${title.trim().toLowerCase()}_${isTv}_${season}_$episode';
    if (_streamCache.containsKey(cacheKey)) {
      final cached = _streamCache[cacheKey]!;
      debugPrint('⚡ [NetMirror] Cache hit for $cacheKey: $cached');
      return cached;
    }

    try {
      final api = await getApiUrl();
      if (api == null) return null;

      // 1. Clean title for search (e.g. remove year or extra text)
      final cleanTitle = title.split('(').first.split(':').first.trim();

      // Search across OTT providers:
      // nf = Netflix, hs = Hotstar / HBO (Game of Thrones, Avengers, Marvel), pv = Prime Video (Mirzapur, The Boys)
      final ottList = ['nf', 'hs', 'pv'];
      List results = [];
      String activeOtt = 'nf';

      for (final ott in ottList) {
        try {
          final searchRes = await http.get(
            Uri.parse('$api/newtv/search.php?s=${Uri.encodeComponent(cleanTitle)}'),
            headers: {..._headers, 'Ott': ott},
          ).timeout(const Duration(seconds: 4));

          if (searchRes.statusCode == 200) {
            final searchData = json.decode(searchRes.body);
            final r = searchData['searchResult'] as List? ?? [];
            if (r.isNotEmpty) {
              results = r;
              activeOtt = ott;
              break;
            }
          }
        } catch (_) {}
      }

      if (results.isEmpty) return null;

      final ottHeaders = {..._headers, 'Ott': activeOtt};

      // Find best title match (exact -> clean -> contains -> first)
      Map<String, dynamic>? match;
      final fullLower = title.toLowerCase().trim();
      final cleanLower = cleanTitle.toLowerCase().trim();

      for (final r in results) {
        final t = (r['t'] ?? '').toString().toLowerCase().trim();
        if (t == fullLower) {
          match = r as Map<String, dynamic>;
          break;
        }
      }
      if (match == null) {
        for (final r in results) {
          final t = (r['t'] ?? '').toString().toLowerCase().trim();
          if (t == cleanLower) {
            match = r as Map<String, dynamic>;
            break;
          }
        }
      }
      if (match == null) {
        for (final r in results) {
          final t = (r['t'] ?? '').toString().toLowerCase().trim();
          if (t.contains(cleanLower) || cleanLower.contains(t)) {
            match = r as Map<String, dynamic>;
            break;
          }
        }
      }
      match ??= results.first as Map<String, dynamic>;
      final targetShowId = match['id']?.toString();
      if (targetShowId == null) return null;

      // 2. Fetch Post Details (seasons & episodes)
      final postRes = await http.get(
        Uri.parse('$api/newtv/post.php?id=$targetShowId'),
        headers: {...ottHeaders, 'Lastep': '', 'Usertoken': ''},
      ).timeout(const Duration(seconds: 6));

      if (postRes.statusCode != 200) return null;
      final postData = json.decode(postRes.body);

      String? targetEpisodeId;

      if (isTv) {
        bool matchesSeasonInfo(List info) {
          final sStr = 's$season';
          return info.any((i) {
            final str = i.toString().toLowerCase();
            return str == sStr || str.contains(sStr) || str.contains('season $season');
          });
        }

        bool matchesEpInfo(int? epNum, List info) {
          if (epNum == episode) return true;
          final epStr = 'e$episode';
          return info.any((i) {
            final str = i.toString().toLowerCase();
            return str == epStr || str.startsWith('$epStr:') || str.contains(epStr);
          });
        }

        final episodes = (postData['episodes'] as List? ?? []).cast<Map<String, dynamic>>();

        // Try to find matching episode in initial list
        for (final ep in episodes) {
          final epNum = int.tryParse(ep['ep']?.toString() ?? '');
          final infoList = (ep['info'] as List? ?? []);
          if (matchesSeasonInfo(infoList) && matchesEpInfo(epNum, infoList)) {
            targetEpisodeId = ep['id']?.toString();
            break;
          }
        }

        // If not found in page 1, fetch season-specific episodes
        if (targetEpisodeId == null && postData['season'] is List) {
          final seasons = (postData['season'] as List).cast<Map<String, dynamic>>();
          Map<String, dynamic>? seasonObj;
          for (final s in seasons) {
            final sLabel = (s['s'] ?? '').toString().toLowerCase();
            if (sLabel.contains('season $season') || sLabel.contains('s$season')) {
              seasonObj = s;
              break;
            }
          }
          seasonObj ??= (season - 1 >= 0 && season - 1 < seasons.length)
              ? seasons[season - 1]
              : (seasons.isNotEmpty ? seasons.first : null);

          if (seasonObj != null) {
            final seasonId = seasonObj['id']?.toString();
            if (seasonId != null) {
              final epRes = await http.get(
                Uri.parse('$api/newtv/episodes.php?id=${Uri.encodeComponent(seasonId)}'),
                headers: ottHeaders,
              ).timeout(const Duration(seconds: 8));

              if (epRes.statusCode == 200) {
                final epData = json.decode(epRes.body);
                final sEpisodes = (epData['episodes'] as List? ?? []).cast<Map<String, dynamic>>();
                for (final ep in sEpisodes) {
                  final epNum = int.tryParse(ep['ep']?.toString() ?? '');
                  final infoList = (ep['info'] as List? ?? []);
                  if (matchesEpInfo(epNum, infoList)) {
                    targetEpisodeId = ep['id']?.toString();
                    break;
                  }
                }
              }
            }
          }
        }
      } else {
        // For Movies, use main_id or showId
        targetEpisodeId = postData['main_id']?.toString() ?? targetShowId;
      }

      if (targetEpisodeId == null) return null;

      // 3. Resolve Player Stream URL
      final playerRes = await http.get(
        Uri.parse('$api/newtv/player.php?id=$targetEpisodeId'),
        headers: {...ottHeaders, 'Usertoken': ''},
      ).timeout(const Duration(seconds: 8));

      if (playerRes.statusCode != 200) return null;
      final playerData = json.decode(playerRes.body);
      final videoLink = playerData['video_link']?.toString();
      final referer = playerData['referer']?.toString() ?? 'https://net52.cc';

      if (videoLink != null && videoLink.isNotEmpty) {
        // Abuse filter: reject the rate-limit clip so the player falls back
        // to a clean embed server. Never cache a flagged stream — the cache
        // has no expiry, so one bad resolve would poison the whole session.
        if (await _isAbuseStream(videoLink, referer)) {
          debugPrint(
              '⚠️ [NetMirror] Abuse/rate-limit stream detected, falling back to clean embed server');
          return null;
        }

        final fullStream = '$videoLink#referer=$referer';
        _streamCache[cacheKey] = fullStream;
        debugPrint('🎯 [NetMirror] Found dual-audio HLS stream: $fullStream');
        return fullStream;
      }
    } catch (e) {
      debugPrint('⚠️ [NetMirror] Stream resolution error: $e');
    }
    return null;
  }
}

