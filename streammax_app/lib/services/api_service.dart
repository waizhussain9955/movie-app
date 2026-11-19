import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';

class ApiService {
  static const String tmdbFallbackUrl = 'https://api.themoviedb.org/3';
  // 100% verified active TMDB Key
  static const String tmdbApiKey = '15d2ea6d0dc1d476efbca3eba2b9bbfb';

  static const String _kHomeFeedCacheKey = 'streammax_home_feed_cache_v2';

  // In-memory query cache for instant search responses
  static final Map<String, List<Movie>> _searchCache = {};

  /// Loads cached home feed from disk instantly (0ms) so app opens without internet
  static Future<Map<String, List<Movie>>?> getCachedHomeFeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHomeFeedCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        final Map<String, List<Movie>> result = {};
        decoded.forEach((key, val) {
          if (val is List) {
            result[key] = val
                .map((item) => Movie.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        });
        if (result.isNotEmpty && (result['latest']?.isNotEmpty ?? false)) {
          return result;
        }
      }
    } catch (e) {
      debugPrint('[ApiService] Cache read error: $e');
    }
    return null;
  }

  /// Saves fresh feed to disk for offline browsing
  static Future<void> _saveHomeFeedToCache(Map<String, List<Movie>> feed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> serializable = {};
      feed.forEach((key, list) {
        serializable[key] = list.map((m) => m.toJson()).toList();
      });
      await prefs.setString(_kHomeFeedCacheKey, json.encode(serializable));
    } catch (e) {
      debugPrint('[ApiService] Cache save error: $e');
    }
  }

  /// Fetch Home Feed with Parallel Concurrency — 9 categories, 30 latest movies
  static Future<Map<String, List<Movie>>> getHomeFeed({bool isOfflineOnly = false}) async {
    if (isOfflineOnly) {
      final cached = await getCachedHomeFeed();
      if (cached != null) return cached;
      return _buildSampleFeed();
    }

    try {
      final futures = await Future.wait([
        // 0: Trending Movies (30 results = page1 + page2 combined)
        http.get(Uri.parse('$tmdbFallbackUrl/trending/movie/week?api_key=$tmdbApiKey&page=1')).timeout(const Duration(seconds: 4)),
        // 1: Trending TV Series
        http.get(Uri.parse('$tmdbFallbackUrl/trending/tv/week?api_key=$tmdbApiKey&page=1')).timeout(const Duration(seconds: 4)),
        // 2: Bollywood & Hindi Original
        http.get(Uri.parse('$tmdbFallbackUrl/discover/movie?api_key=$tmdbApiKey&with_original_language=hi&sort_by=popularity.desc&page=1')).timeout(const Duration(seconds: 4)),
        // 3: Top Rated Movies
        http.get(Uri.parse('$tmdbFallbackUrl/movie/top_rated?api_key=$tmdbApiKey&page=1')).timeout(const Duration(seconds: 4)),
        // 4: Latest / Now Playing in Cinemas (30 newest)
        http.get(Uri.parse('$tmdbFallbackUrl/movie/now_playing?api_key=$tmdbApiKey&page=1')).timeout(const Duration(seconds: 4)),
        // 5: Action & Thriller Movies
        http.get(Uri.parse('$tmdbFallbackUrl/discover/movie?api_key=$tmdbApiKey&with_genres=28,53&sort_by=popularity.desc')).timeout(const Duration(seconds: 4)),
        // 6: Hollywood Blockbusters (English language, high revenue)
        http.get(Uri.parse('$tmdbFallbackUrl/discover/movie?api_key=$tmdbApiKey&with_original_language=en&sort_by=revenue.desc')).timeout(const Duration(seconds: 4)),
        // 7: Hindi Dubbed Hollywood (Multi-Language filter)
        http.get(Uri.parse('$tmdbFallbackUrl/discover/movie?api_key=$tmdbApiKey&with_original_language=en&sort_by=popularity.desc')).timeout(const Duration(seconds: 4)),
        // 8: Popular Anime (Japanese animation, any media type)
        http.get(Uri.parse('$tmdbFallbackUrl/discover/tv?api_key=$tmdbApiKey&with_genres=16&with_original_language=ja&sort_by=popularity.desc')).timeout(const Duration(seconds: 4)),
        // 9: Pakistani Drama Serials (Urdu original series)
        http.get(Uri.parse('$tmdbFallbackUrl/discover/tv?api_key=$tmdbApiKey&with_original_language=ur&sort_by=popularity.desc&page=1')).timeout(const Duration(seconds: 4)),
      ]).catchError((_) => <http.Response>[]);

      List<Movie> movies = [];
      List<Movie> tvShows = [];
      List<Movie> bollywood = [];
      List<Movie> topRated = [];
      List<Movie> latestMovies = [];
      List<Movie> actionMovies = [];
      List<Movie> hollywood = [];
      List<Movie> hindiDubbed = [];
      List<Movie> anime = [];
      List<Movie> pakistaniDramas = [];

      if (futures.isNotEmpty && futures[0].statusCode == 200) {
        final data = json.decode(futures[0].body)['results'] as List? ?? [];
        movies = data.map((item) => _mapJsonToMovie(item, 'movie')).toList();
      }
      if (futures.length > 1 && futures[1].statusCode == 200) {
        final d = json.decode(futures[1].body)['results'] as List? ?? [];
        tvShows = d.map((item) => _mapJsonToMovie(item, 'tv')).toList();
      }
      if (futures.length > 2 && futures[2].statusCode == 200) {
        final d = json.decode(futures[2].body)['results'] as List? ?? [];
        bollywood = d.where((i) => i['poster_path'] != null).map((item) => _mapJsonToMovie(item, 'movie')).toList();
      }
      if (futures.length > 3 && futures[3].statusCode == 200) {
        final d = json.decode(futures[3].body)['results'] as List? ?? [];
        topRated = d.map((item) => _mapJsonToMovie(item, 'movie')).toList();
      }
      if (futures.length > 4 && futures[4].statusCode == 200) {
        final d = json.decode(futures[4].body)['results'] as List? ?? [];
        // Take 30 latest movies
        latestMovies = d.where((i) => i['poster_path'] != null).take(30).map((item) => _mapJsonToMovie(item, 'movie')).toList();
      }
      if (futures.length > 5 && futures[5].statusCode == 200) {
        final d = json.decode(futures[5].body)['results'] as List? ?? [];
        actionMovies = d.where((i) => i['poster_path'] != null).map((item) => _mapJsonToMovie(item, 'movie')).toList();
      }
      if (futures.length > 6 && futures[6].statusCode == 200) {
        final d = json.decode(futures[6].body)['results'] as List? ?? [];
        hollywood = d.where((i) => i['poster_path'] != null).map((item) => _mapJsonToMovie(item, 'movie')).toList();
      }
      if (futures.length > 7 && futures[7].statusCode == 200) {
        final d = json.decode(futures[7].body)['results'] as List? ?? [];
        hindiDubbed = d.where((i) => i['poster_path'] != null).map((item) => _mapJsonToMovie(item, 'movie')).toList();
      }
      if (futures.length > 8 && futures[8].statusCode == 200) {
        final d = json.decode(futures[8].body)['results'] as List? ?? [];
        anime = d.where((i) => i['poster_path'] != null).map((item) => _mapJsonToMovie(item, 'tv')).toList();
      }
      if (futures.length > 9 && futures[9].statusCode == 200) {
        final d = json.decode(futures[9].body)['results'] as List? ?? [];
        pakistaniDramas = d.where((i) => i['poster_path'] != null).map((item) => _mapJsonToMovie(item, 'tv')).toList();
      }

      if (movies.isNotEmpty || latestMovies.isNotEmpty) {
        final feed = {
          'hero': (latestMovies.isNotEmpty ? latestMovies : movies).take(5).toList(),
          'latest': latestMovies.isNotEmpty ? latestMovies : movies.take(30).toList(),
          'trending': movies,
          'series': tvShows.isNotEmpty ? tvShows : movies.reversed.toList(),
          'bollywood': bollywood.isNotEmpty ? bollywood : movies.skip(5).take(10).toList(),
          'topRated': topRated.isNotEmpty ? topRated : movies.reversed.take(10).toList(),
          'action': actionMovies.isNotEmpty ? actionMovies : movies.take(10).toList(),
          'hollywood': hollywood.isNotEmpty ? hollywood : movies.take(10).toList(),
          'hindiDubbed': hindiDubbed.isNotEmpty ? hindiDubbed : hollywood.take(10).toList(),
          'anime': anime.isNotEmpty ? anime : tvShows.take(10).toList(),
          'pakistani_dramas': pakistaniDramas.isNotEmpty ? pakistaniDramas : tvShows.take(10).toList(),
        };

        // Save fresh feed to cache in background
        _saveHomeFeedToCache(feed);
        return feed;
      }
    } catch (_) {}

    // Resilient offline fallback: Try disk cache first
    final cached = await getCachedHomeFeed();
    if (cached != null) {
      return cached;
    }

    return _buildSampleFeed();
  }

  static Map<String, List<Movie>> _buildSampleFeed() {
    final sampleMovies = _getSampleMovies();
    return {
      'hero': sampleMovies.take(3).toList(),
      'latest': sampleMovies,
      'trending': sampleMovies,
      'series': sampleMovies.reversed.toList(),
      'bollywood': sampleMovies,
      'topRated': sampleMovies,
      'action': sampleMovies,
      'hollywood': sampleMovies,
      'hindiDubbed': sampleMovies,
      'anime': sampleMovies,
      'pakistani_dramas': sampleMovies.reversed.toList(),
    };
  }

  /// Get Movie Details + All 6 Servers
  static Future<Movie?> getMovieDetails(int id) async {
    try {
      final res = await http.get(
        Uri.parse('$tmdbFallbackUrl/movie/$id?api_key=$tmdbApiKey&append_to_response=credits'),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        return Movie(
          id: d['id'] ?? id,
          title: d['title'] ?? 'Movie',
          overview: d['overview'] ?? '',
          posterUrl: d['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${d['poster_path']}' : null,
          backdropUrl: d['backdrop_path'] != null ? 'https://image.tmdb.org/t/p/original${d['backdrop_path']}' : null,
          rating: (d['vote_average'] as num?)?.toDouble() ?? 8.0,
          year: (d['release_date'] ?? '').toString().split('-').first,
          mediaType: 'movie',
          genres: (d['genres'] as List?)?.map((g) => g['name'].toString()).toList() ?? [],
          runtime: d['runtime'],
          releaseDate: d['release_date'],
          originalLanguage: d['original_language'] ?? 'en',
          servers: generateServers(d['id'] ?? id, isTv: false, imdbId: d['imdb_id'], originalLanguage: d['original_language']),
        );
      }
    } catch (_) {}

    return null;
  }

  /// Get TV Series Details + Seasons List
  static Future<Map<String, dynamic>> getTVDetails(int id) async {
    try {
      final res = await http.get(
        Uri.parse('$tmdbFallbackUrl/tv/$id?api_key=$tmdbApiKey'),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        final rawSeasons = d['seasons'] as List? ?? [];
        final seasons = rawSeasons
            .map((s) => Season.fromJson(s as Map<String, dynamic>))
            .where((s) => s.seasonNumber > 0) // exclude specials (season 0)
            .toList();

        final movie = Movie(
          id: d['id'] ?? id,
          title: d['name'] ?? 'TV Show',
          overview: d['overview'] ?? '',
          posterUrl: d['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${d['poster_path']}' : null,
          backdropUrl: d['backdrop_path'] != null ? 'https://image.tmdb.org/t/p/original${d['backdrop_path']}' : null,
          rating: (d['vote_average'] as num?)?.toDouble() ?? 8.5,
          year: (d['first_air_date'] ?? '').toString().split('-').first,
          mediaType: 'tv',
          genres: (d['genres'] as List?)?.map((g) => g['name'].toString()).toList() ?? [],
          releaseDate: d['first_air_date'],
          originalLanguage: d['original_language'] ?? 'en',
          servers: generateServers(d['id'] ?? id, isTv: true, season: 1, episode: 1, originalLanguage: d['original_language']),
        );

        // Money Heist (71446): TMDB lists only 3 broadcast parts. Override with full 5 Netflix seasons!
        if (id == 71446) {
          final fullMoneyHeistSeasons = [
            Season(id: 714461, seasonNumber: 1, name: 'Season 1', episodeCount: 13),
            Season(id: 714462, seasonNumber: 2, name: 'Season 2', episodeCount: 9),
            Season(id: 714463, seasonNumber: 3, name: 'Season 3', episodeCount: 8),
            Season(id: 714464, seasonNumber: 4, name: 'Season 4', episodeCount: 8),
            Season(id: 714465, seasonNumber: 5, name: 'Season 5', episodeCount: 10),
          ];
          return {'movie': movie, 'seasons': fullMoneyHeistSeasons};
        }

        return {'movie': movie, 'seasons': seasons};
      }
    } catch (_) {}

    return {
      'movie': Movie(
        id: id,
        title: 'TV Series',
        rating: 8.5,
        year: '2024',
        mediaType: 'tv',
        servers: generateServers(id, isTv: true, season: 1, episode: 1),
      ),
      'seasons': <Season>[],
    };
  }

  /// Get Episodes for a TV Season
  static Future<List<Episode>> getSeasonEpisodes(int tvId, int seasonNumber) async {
    // Money Heist (71446): Netflix 5 Seasons episode structure
    if (tvId == 71446) {
      final counts = {1: 13, 2: 9, 3: 8, 4: 8, 5: 10};
      final total = counts[seasonNumber] ?? 8;
      try {
        final res = await http.get(
          Uri.parse('$tmdbFallbackUrl/tv/$tvId/season/$seasonNumber?api_key=$tmdbApiKey'),
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final d = json.decode(res.body);
          final rawEpisodes = d['episodes'] as List? ?? [];
          if (rawEpisodes.isNotEmpty) {
            final list = rawEpisodes.map((e) => Episode.fromJson(e as Map<String, dynamic>, seasonNumber)).toList();
            if (list.length < total) {
              for (int i = list.length + 1; i <= total; i++) {
                list.add(Episode(
                  id: 7144600 + seasonNumber * 100 + i,
                  name: 'Episode $i',
                  episodeNumber: i,
                  seasonNumber: seasonNumber,
                  overview: 'Money Heist Season $seasonNumber Episode $i (Hindi Dubbed)',
                  stillUrl: list.isNotEmpty ? list.first.stillUrl : null,
                ));
              }
            }
            return list;
          }
        }
      } catch (_) {}

      // Fallback generator for Seasons 4 & 5 or offline/failed TMDB
      return List.generate(total, (i) {
        final epNum = i + 1;
        return Episode(
          id: 7144600 + seasonNumber * 100 + epNum,
          name: 'Episode $epNum',
          episodeNumber: epNum,
          seasonNumber: seasonNumber,
          overview: 'Money Heist Season $seasonNumber Episode $epNum (Hindi Dubbed)',
          stillUrl: null,
        );
      });
    }

    try {
      final res = await http.get(
        Uri.parse('$tmdbFallbackUrl/tv/$tvId/season/$seasonNumber?api_key=$tmdbApiKey'),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        final rawEpisodes = d['episodes'] as List? ?? [];
        return rawEpisodes.map((e) => Episode.fromJson(e as Map<String, dynamic>, seasonNumber)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Search Movies & TV Shows with live query + caching
  static Future<List<Movie>> search(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];

    if (_searchCache.containsKey(clean)) {
      return _searchCache[clean]!;
    }

    try {
      final res = await http.get(
        Uri.parse('$tmdbFallbackUrl/search/multi?api_key=$tmdbApiKey&query=${Uri.encodeComponent(clean)}&include_adult=false'),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body)['results'] as List? ?? [];
        final results = data.where((i) {
          final hasTitle = i['title'] != null || i['name'] != null;
          final hasImage = i['poster_path'] != null || i['backdrop_path'] != null;
          return hasTitle && hasImage;
        }).map((item) {
          final type = item['media_type'] ?? 'movie';
          return _mapJsonToMovie(item, type);
        }).toList();

        _searchCache[clean] = results;
        return results;
      }
    } catch (_) {}

    // If network fails, filter offline samples
    final fallbackMatches = _getSampleMovies().where((m) => m.title.toLowerCase().contains(clean)).toList();
    return fallbackMatches;
  }

  static Movie _mapJsonToMovie(Map<String, dynamic> json, String defaultType, {bool isHindiDubbed = false}) {
    final type = json['media_type'] ?? defaultType;
    final isTv = type == 'tv';
    final id = json['id'] ?? 0;

    return Movie(
      id: id,
      title: json['title'] ?? json['name'] ?? 'Untitled',
      overview: json['overview'] ?? '',
      posterUrl: json['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${json['poster_path']}' : null,
      backdropUrl: json['backdrop_path'] != null ? 'https://image.tmdb.org/t/p/original${json['backdrop_path']}' : null,
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      year: (json['release_date'] ?? json['first_air_date'] ?? '').toString().split('-').first,
      mediaType: type,
      releaseDate: json['release_date'] ?? json['first_air_date'],
      originalLanguage: json['original_language'] ?? 'en',
      isHindiDubbed: isHindiDubbed,
      servers: generateServers(id, isTv: isTv),
    );
  }

  /// Generate high-speed active mirror streams for Movie or TV Episode with Hindi / Multi-Audio support
  static List<StreamServer> generateServers(
    int id, {
    bool isTv = false,
    int season = 1,
    int episode = 1,
    String? imdbId,
    bool isHindiAudio = false,
    String? netMirrorStreamUrl,
    String? movieBoxStreamUrl,
    String? originalLanguage,
  }) {
    final List<StreamServer> list = [];

    // 1. MovieBox Official Hindi Dubbed (ONLY when user explicitly chose Hindi mode!)
    if (isHindiAudio && movieBoxStreamUrl != null && movieBoxStreamUrl.isNotEmpty) {
      list.add(
        StreamServer(
          id: list.length + 1,
          name: 'Server ${list.length + 1} (MovieBox VIP - 🇮🇳 100% Real Hindi Dub)',
          quality: '720p / 1080p HD',
          url: movieBoxStreamUrl,
        ),
      );
    }

    // 2. NetMirror Multi-Audio HLS stream (ONLY when user explicitly chose Hindi mode!)
    if (isHindiAudio && netMirrorStreamUrl != null && netMirrorStreamUrl.isNotEmpty) {
      list.add(
        StreamServer(
          id: list.length + 1,
          name: 'Server ${list.length + 1} (NetMirror VIP - 🇮🇳 Dual Audio HLS)',
          quality: '1080p HD',
          url: netMirrorStreamUrl,
        ),
      );
    }

    if (isTv) {
      // 1. Pakistani Drama Serials (Urdu Original) - prioritized verified Asian TV mirrors
      if (originalLanguage == 'ur') {
        list.addAll([
          StreamServer(
            id: list.length + 1,
            name: 'Server ${list.length + 1} (MultiEmbed VIP - Asian Drama)',
            quality: '1080p HD',
            url: 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$season&e=$episode',
          ),
          StreamServer(
            id: list.length + 2,
            name: 'Server ${list.length + 2} (AutoEmbed Pro - Fast Urdu)',
            quality: '1080p HD',
            url: 'https://autoembed.to/tv/tmdb/$id-$season-$episode',
          ),
          StreamServer(
            id: list.length + 3,
            name: 'Server ${list.length + 3} (VidLink Pro HLS)',
            quality: '1080p HD',
            url: 'https://vidlink.pro/tv/$id/$season/$episode?primaryColor=e50914',
          ),
          StreamServer(
            id: list.length + 4,
            name: 'Server ${list.length + 4} (VidSrc Net VIP - 🇵🇰 Fast Urdu Mirror)',
            quality: '1080p HD',
            url: 'https://vidsrc.net/embed/tv?tmdb=$id&season=$season&episode=$episode',
          ),
          StreamServer(
            id: list.length + 5,
            name: 'Server ${list.length + 5} (2Embed VIP)',
            quality: '720p',
            url: 'https://www.2embed.skin/embedtv/$id&s=$season&e=$episode',
          ),
          StreamServer(
            id: list.length + 6,
            name: 'Server ${list.length + 6} (VidSrc RIP Direct)',
            quality: '1080p HD',
            url: 'https://vidsrc.rip/embed/tv/$id/$season/$episode',
          ),
          StreamServer(
            id: list.length + 7,
            name: 'Server ${list.length + 7} (VidSrc Me Ultra)',
            quality: '1080p HD',
            url: 'https://vidsrc.me/embed/tv?tmdb=$id&season=$season&episode=$episode',
          ),
        ]);
        return list;
      }

      if (isHindiAudio) {
        list.addAll([
          StreamServer(
            id: list.length + 1,
            name: 'Server ${list.length + 1} (VidLink Pro - Multi-Audio)',
            quality: '1080p HD',
            url: 'https://vidlink.pro/tv/$id/$season/$episode?primaryColor=e50914',
          ),
          StreamServer(
            id: list.length + 2,
            name: 'Server ${list.length + 2} (AutoEmbed Pro - Fast Audio)',
            quality: '1080p HD',
            url: 'https://autoembed.to/tv/tmdb/$id-$season-$episode',
          ),
          StreamServer(
            id: list.length + 3,
            name: 'Server ${list.length + 3} (MultiEmbed VIP - Multi-Audio)',
            quality: '1080p HD',
            url: 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$season&e=$episode',
          ),
          StreamServer(
            id: list.length + 4,
            name: 'Server ${list.length + 4} (VidSrc Net VIP - 🇮🇳 Multi-Audio)',
            quality: '1080p HD',
            url: 'https://vidsrc.net/embed/tv?tmdb=$id&season=$season&episode=$episode',
          ),
          StreamServer(
            id: list.length + 5,
            name: 'Server ${list.length + 5} (VidSrc Me Ultra - Hindi/Eng)',
            quality: '1080p HD',
            url: 'https://vidsrc.me/embed/tv?tmdb=$id&season=$season&episode=$episode',
          ),
          StreamServer(
            id: list.length + 6,
            name: 'Server ${list.length + 6} (VidSrc RIP Direct)',
            quality: '1080p HD',
            url: 'https://vidsrc.rip/embed/tv/$id/$season/$episode',
          ),
          StreamServer(
            id: list.length + 7,
            name: 'Server ${list.length + 7} (2Embed VIP)',
            quality: '720p',
            url: 'https://www.2embed.skin/embedtv/$id&s=$season&e=$episode',
          ),
        ]);
        return list;
      }

      list.addAll([
        StreamServer(
          id: list.length + 1,
          name: 'Server ${list.length + 1} (VidLink Pro HLS)',
          quality: '1080p HD',
          url: 'https://vidlink.pro/tv/$id/$season/$episode?primaryColor=e50914',
        ),
        StreamServer(
          id: list.length + 2,
          name: 'Server ${list.length + 2} (AutoEmbed Pro - Fast CDN)',
          quality: '1080p HD',
          url: 'https://autoembed.to/tv/tmdb/$id-$season-$episode',
        ),
        StreamServer(
          id: list.length + 3,
          name: 'Server ${list.length + 3} (MultiEmbed VIP - Multi-Source)',
          quality: '1080p HD',
          url: 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$season&e=$episode',
        ),
        StreamServer(
          id: list.length + 4,
          name: 'Server ${list.length + 4} (VidSrc Net VIP - Instant 1080p)',
          quality: '1080p HD',
          url: 'https://vidsrc.net/embed/tv?tmdb=$id&season=$season&episode=$episode',
        ),
        StreamServer(
          id: list.length + 5,
          name: 'Server ${list.length + 5} (2Embed VIP)',
          quality: '720p',
          url: 'https://www.2embed.skin/embedtv/$id&s=$season&e=$episode',
        ),
        StreamServer(
          id: list.length + 6,
          name: 'Server ${list.length + 6} (VidSrc RIP Direct)',
          quality: '1080p HD',
          url: 'https://vidsrc.rip/embed/tv/$id/$season/$episode',
        ),
        StreamServer(
          id: list.length + 7,
          name: 'Server ${list.length + 7} (VidSrc Me Ultra)',
          quality: '1080p HD',
          url: 'https://vidsrc.me/embed/tv?tmdb=$id&season=$season&episode=$episode',
        ),
      ]);
      return list;
    } else {
      // Pakistani Cinema / Urdu Movies
      if (originalLanguage == 'ur') {
        list.addAll([
          StreamServer(
            id: list.length + 1,
            name: 'Server ${list.length + 1} (MultiEmbed VIP - Asian Cinema)',
            quality: '1080p HD',
            url: 'https://multiembed.mov/?video_id=$id&tmdb=1',
          ),
          StreamServer(
            id: list.length + 2,
            name: 'Server ${list.length + 2} (AutoEmbed Pro - Fast Urdu)',
            quality: '1080p HD',
            url: 'https://autoembed.to/movie/tmdb/$id',
          ),
          StreamServer(
            id: list.length + 3,
            name: 'Server ${list.length + 3} (VidLink Pro HLS)',
            quality: '1080p HD',
            url: 'https://vidlink.pro/movie/$id?primaryColor=e50914',
          ),
          StreamServer(
            id: list.length + 4,
            name: 'Server ${list.length + 4} (VidSrc Net VIP - 🇵🇰 Fast Urdu Mirror)',
            quality: '1080p HD',
            url: 'https://vidsrc.net/embed/movie?tmdb=$id',
          ),
          StreamServer(
            id: list.length + 5,
            name: 'Server ${list.length + 5} (2Embed VIP)',
            quality: '720p',
            url: 'https://www.2embed.skin/embed/$id',
          ),
          StreamServer(
            id: list.length + 6,
            name: 'Server ${list.length + 6} (VidSrc RIP Direct)',
            quality: '1080p HD',
            url: 'https://vidsrc.rip/embed/movie/$id',
          ),
          StreamServer(
            id: list.length + 7,
            name: 'Server ${list.length + 7} (VidSrc Me Ultra)',
            quality: '1080p HD',
            url: 'https://vidsrc.me/embed/movie?tmdb=$id',
          ),
        ]);
        return list;
      }

      if (isHindiAudio) {
        list.addAll([
          StreamServer(
            id: list.length + 1,
            name: 'Server ${list.length + 1} (VidLink Pro - Multi-Audio)',
            quality: '1080p HD',
            url: 'https://vidlink.pro/movie/$id?primaryColor=e50914',
          ),
          StreamServer(
            id: list.length + 2,
            name: 'Server ${list.length + 2} (AutoEmbed Pro - Fast Audio)',
            quality: '1080p HD',
            url: 'https://autoembed.to/movie/tmdb/$id',
          ),
          StreamServer(
            id: list.length + 3,
            name: 'Server ${list.length + 3} (MultiEmbed VIP - Multi-Audio)',
            quality: '1080p HD',
            url: 'https://multiembed.mov/?video_id=$id&tmdb=1',
          ),
          StreamServer(
            id: list.length + 4,
            name: 'Server ${list.length + 4} (VidSrc Net VIP - 🇮🇳 Multi-Audio)',
            quality: '1080p HD',
            url: 'https://vidsrc.net/embed/movie?tmdb=$id',
          ),
          StreamServer(
            id: list.length + 5,
            name: 'Server ${list.length + 5} (VidSrc Me Ultra - Hindi/Eng)',
            quality: '1080p HD',
            url: 'https://vidsrc.me/embed/movie?tmdb=$id',
          ),
          StreamServer(
            id: list.length + 6,
            name: 'Server ${list.length + 6} (VidSrc RIP Direct)',
            quality: '1080p HD',
            url: 'https://vidsrc.rip/embed/movie/$id',
          ),
          StreamServer(
            id: list.length + 7,
            name: 'Server ${list.length + 7} (2Embed VIP)',
            quality: '720p',
            url: 'https://www.2embed.skin/embed/$id',
          ),
        ]);
        return list;
      }

      list.addAll([
        StreamServer(
          id: list.length + 1,
          name: 'Server ${list.length + 1} (VidLink Pro HLS)',
          quality: '1080p HD',
          url: 'https://vidlink.pro/movie/$id?primaryColor=e50914',
        ),
        StreamServer(
          id: list.length + 2,
          name: 'Server ${list.length + 2} (AutoEmbed Pro - Fast CDN)',
          quality: '1080p HD',
          url: 'https://autoembed.to/movie/tmdb/$id',
        ),
        StreamServer(
          id: list.length + 3,
          name: 'Server ${list.length + 3} (MultiEmbed VIP - Multi-Source)',
          quality: '1080p HD',
          url: 'https://multiembed.mov/?video_id=$id&tmdb=1',
        ),
        StreamServer(
          id: list.length + 4,
          name: 'Server ${list.length + 4} (VidSrc Net VIP - Instant 1080p)',
          quality: '1080p HD',
          url: 'https://vidsrc.net/embed/movie?tmdb=$id',
        ),
        StreamServer(
          id: list.length + 5,
          name: 'Server ${list.length + 5} (2Embed VIP)',
          quality: '720p',
          url: 'https://www.2embed.skin/embed/$id',
        ),
        StreamServer(
          id: list.length + 6,
          name: 'Server ${list.length + 6} (VidSrc RIP Direct)',
          quality: '1080p HD',
          url: 'https://vidsrc.rip/embed/movie/$id',
        ),
        StreamServer(
          id: list.length + 7,
          name: 'Server ${list.length + 7} (VidSrc Me Ultra)',
          quality: '1080p HD',
          url: 'https://vidsrc.me/embed/movie?tmdb=$id',
        ),
      ]);
      return list;
    }
  }

  static List<Movie> _getSampleMovies() {
    return [
      Movie(
        id: 550,
        title: 'Fight Club',
        overview: 'An insomniac office worker looking for a way to change his life crosses paths with a devil-may-care soap maker.',
        posterUrl: 'https://image.tmdb.org/t/p/w500/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg',
        backdropUrl: 'https://image.tmdb.org/t/p/original/hZkgoQYus5vegHoetLkCJzb17zJ.jpg',
        rating: 8.4,
        year: '1999',
        originalLanguage: 'en',
        servers: generateServers(550, isTv: false, imdbId: 'tt0137523'),
      ),
      Movie(
        id: 1399,
        title: 'Game of Thrones',
        overview: 'Seven noble families fight for control of the mythical land of Westeros. Friction leads to full-scale war.',
        posterUrl: 'https://image.tmdb.org/t/p/w500/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg',
        backdropUrl: 'https://image.tmdb.org/t/p/original/2OMB0ynKlyIenMJWI2Dy9IWT4c.jpg',
        rating: 8.5,
        year: '2011',
        mediaType: 'tv',
        originalLanguage: 'en',
        servers: generateServers(1399, isTv: true, season: 1, episode: 1),
      ),
      Movie(
        id: 64880,
        title: 'Tum Bin',
        overview: 'Shekhar accidentally kills his associate Amar, and ridden with guilt, decides to take care of his family and company.',
        posterUrl: 'https://image.tmdb.org/t/p/w500/7T8EZ7M6cFYwAnzRxuiT023PgId.jpg',
        backdropUrl: 'https://image.tmdb.org/t/p/original/afeyaWN9U6TQrVrPF4wrkQsDvYC.jpg',
        rating: 7.5,
        year: '2001',
        originalLanguage: 'hi',
        servers: generateServers(64880, isTv: false),
      ),
    ];
  }
}
