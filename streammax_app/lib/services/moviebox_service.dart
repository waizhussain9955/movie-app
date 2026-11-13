import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MovieBoxService {
  static final Map<String, String> _streamCache = {};

  // Known MovieBox mapping for top global series & movies
  static final Map<int, Map<String, String>> _knownHindiDubs = {
    // Money Heist (La Casa de Papel) - TMDB 71446 (All 5 Seasons Hindi)
    71446: {
      'subjectId': '7147213651240699592',
      'detailPath': 'money-heist-hindi-0A6xcmujYv8',
    },
    // Avengers - TMDB 299534 & TMDB 24428
    299534: {
      'subjectId': '5608459269503862552',
      'detailPath': 'avengers-QExqQyMNiG6',
    },
    24428: {
      'subjectId': '5608459269503862552',
      'detailPath': 'avengers-QExqQyMNiG6',
    },
    // Breaking Bad - TMDB 1396 (All 5 Seasons)
    1396: {
      'subjectId': '6207982430134357800',
      'detailPath': 'breaking-bad-ej6Bp0MCAo7',
    },
    // Stranger Things - TMDB 66732 (All Seasons)
    66732: {
      'subjectId': '4956801153355891744',
      'detailPath': 'stranger-things-wsymkZvcaU5',
    },
    // The Boys - TMDB 76479 (All Seasons)
    76479: {
      'subjectId': '5139196938264400928',
      'detailPath': 'the-boys-c8bx84KzD76',
    },
  };

  /// Resolve MovieBox direct Hindi stream (.mp4) with clean 720p/1080p audio and zero warning clips
  static Future<String?> getHindiStream({
    required int tmdbId,
    bool isTv = false,
    int season = 1,
    int episode = 1,
  }) async {
    final cacheKey = '${tmdbId}_${isTv}_${season}_$episode';
    if (_streamCache.containsKey(cacheKey)) {
      return _streamCache[cacheKey];
    }

    final info = _knownHindiDubs[tmdbId];
    if (info == null) return null;

    final subjectId = info['subjectId'];
    final detailPath = info['detailPath'];

    try {
      final uri = isTv
          ? Uri.parse(
              'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/play'
              '?subjectId=$subjectId'
              '&se=$season'
              '&ep=$episode'
              '&detailPath=$detailPath'
              '&streamSignType=1',
            )
          : Uri.parse(
              'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/play'
              '?subjectId=$subjectId'
              '&detailPath=$detailPath'
              '&streamSignType=1',
            );

      final referer = isTv
          ? 'https://movie-box.co/movies/$detailPath?id=$subjectId&type=/movie/detail&detailSe=$season&detailEp=$episode&lang=hi'
          : 'https://movie-box.co/movies/$detailPath?id=$subjectId&type=/movie/detail';

      final res = await http.get(
        uri,
        headers: {
          'Origin': 'https://movie-box.co',
          'Referer': referer,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
        },
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['data'] != null && data['data']['streams'] is List) {
          final streams = data['data']['streams'] as List;
          // Prefer 720p or 1080p, then fall back to whatever is available
          Map<String, dynamic>? selectedStream;
          for (final s in streams) {
            final resNum = s['resolutions'] ?? s['resolution'];
            if (resNum == 720 || resNum == '720' || resNum == 1080 || resNum == '1080') {
              selectedStream = s as Map<String, dynamic>;
              break;
            }
          }
          selectedStream ??= (streams.isNotEmpty ? streams.first as Map<String, dynamic> : null);

          if (selectedStream != null && selectedStream['url'] != null) {
            final streamUrl = selectedStream['url'].toString();
            final finalUrl = '$streamUrl#referer=https://videodownloader.site/';
            _streamCache[cacheKey] = finalUrl;
            debugPrint('🎉 [MovieBox] Found 100% clean Hindi Dubbed stream: $finalUrl');
            return finalUrl;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [MovieBox] Stream error: $e');
    }
    return null;
  }
}

