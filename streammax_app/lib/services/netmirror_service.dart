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

