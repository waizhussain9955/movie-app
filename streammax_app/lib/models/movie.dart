class Movie {
  final int id;
  final String title;
  final String? overview;
  final String? posterUrl;
  final String? backdropUrl;
  final double rating;
  final String year;
  final String mediaType; // 'movie' or 'tv'
  final List<String> genres;
  final int? runtime;
  final List<StreamServer> servers;
  final String? releaseDate;
  final String originalLanguage;
  // True when this title comes from the "Hindi Dubbed" row: the movie itself
  // is usually English-original (originalLanguage == 'en') but is meant to be
  // played with the Hindi dubbed audio track. Do NOT confuse with isHindi,
  // which only means Hindi-original (Bollywood).
  final bool isHindiDubbed;

  Movie({
    required this.id,
    required this.title,
    this.overview,
    this.posterUrl,
    this.backdropUrl,
    required this.rating,
    required this.year,
    this.mediaType = 'movie',
    this.genres = const [],
    this.runtime,
    this.servers = const [],
    this.releaseDate,
    this.originalLanguage = 'en',
    this.isHindiDubbed = false,
  });

  Movie copyWith({
    int? id,
    String? title,
    String? overview,
    String? posterUrl,
    String? backdropUrl,
    double? rating,
    String? year,
    String? mediaType,
    List<String>? genres,
    int? runtime,
    List<StreamServer>? servers,
    String? releaseDate,
    String? originalLanguage,
    bool? isHindiDubbed,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      overview: overview ?? this.overview,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      rating: rating ?? this.rating,
      year: year ?? this.year,
      mediaType: mediaType ?? this.mediaType,
      genres: genres ?? this.genres,
      runtime: runtime ?? this.runtime,
      servers: servers ?? this.servers,
      releaseDate: releaseDate ?? this.releaseDate,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      isHindiDubbed: isHindiDubbed ?? this.isHindiDubbed,
    );
  }

  bool get isHindi => originalLanguage == 'hi';

  bool get isUpcoming {
    if (releaseDate != null && releaseDate!.isNotEmpty) {
      try {
        final date = DateTime.parse(releaseDate!);
        return date.isAfter(DateTime.now());
      } catch (_) {}
    }
    // Fallback: check numerical release year
    final yr = int.tryParse(year);
    if (yr != null && yr > DateTime.now().year) {
      return true;
    }
    return false;
  }

  factory Movie.fromJson(Map<String, dynamic> json) {
    var rawServers = json['servers'] as List? ?? [];
    List<StreamServer> parsedServers = rawServers
        .map((s) => StreamServer.fromJson(s as Map<String, dynamic>))
        .toList();

    String parsedYear = json['year']?.toString() ?? '';
    if (parsedYear.isEmpty) {
      final dateStr = (json['release_date'] ?? json['first_air_date'] ?? '').toString();
      if (dateStr.isNotEmpty) {
        parsedYear = dateStr.split('-').first;
      } else {
        parsedYear = '2024';
      }
    }

    return Movie(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['name'] ?? 'Untitled',
      overview: json['overview'] ?? '',
      posterUrl: json['posterUrl'] ??
          (json['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${json['poster_path']}' : null),
      backdropUrl: json['backdropUrl'] ??
          (json['backdrop_path'] != null ? 'https://image.tmdb.org/t/p/original${json['backdrop_path']}' : null),
      rating: (json['rating'] != null)
          ? (json['rating'] as num).toDouble()
          : (json['vote_average'] != null ? (json['vote_average'] as num).toDouble() : 0.0),
      year: parsedYear,
      mediaType: json['mediaType'] ?? json['media_type'] ?? 'movie',
      genres: (json['genres'] as List?)?.map((g) => g is Map ? g['name'].toString() : g.toString()).toList() ?? [],
      runtime: json['runtime'],
      servers: parsedServers,
      releaseDate: json['release_date'] ?? json['first_air_date'],
      originalLanguage: json['original_language']?.toString() ?? 'en',
      isHindiDubbed: json['isHindiDubbed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'overview': overview,
    'posterUrl': posterUrl,
    'backdropUrl': backdropUrl,
    'rating': rating,
    'year': year,
    'mediaType': mediaType,
    'genres': genres,
    'runtime': runtime,
    'releaseDate': releaseDate,
    'originalLanguage': originalLanguage,
    'isHindiDubbed': isHindiDubbed,
    'servers': servers.map((s) => s.toJson()).toList(),
  };
}

class StreamServer {
  final int id;
  final String name;
  final String quality;
  final String url;
  final String? backupUrl;
  final String status;

  StreamServer({
    required this.id,
    required this.name,
    required this.quality,
    required this.url,
    this.backupUrl,
    this.status = 'active',
  });

  factory StreamServer.fromJson(Map<String, dynamic> json) {
    return StreamServer(
      id: json['id'] ?? 1,
      name: json['name'] ?? 'Server',
      quality: json['quality'] ?? '1080p',
      url: json['url'] ?? '',
      backupUrl: json['backupUrl'],
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quality': quality,
    'url': url,
    'backupUrl': backupUrl,
    'status': status,
  };
}

class Season {
  final int id;
  final String name;
  final int seasonNumber;
  final int episodeCount;

  Season({
    required this.id,
    required this.name,
    required this.seasonNumber,
    required this.episodeCount,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Season ${json['season_number']}',
      seasonNumber: json['season_number'] ?? 1,
      episodeCount: json['episode_count'] ?? 0,
    );
  }
}

class Episode {
  final int id;
  final String name;
  final String overview;
  final String? stillUrl;
  final int episodeNumber;
  final int seasonNumber;
  final double rating;

  Episode({
    required this.id,
    required this.name,
    required this.overview,
    this.stillUrl,
    required this.episodeNumber,
    required this.seasonNumber,
    this.rating = 0.0,
  });

  factory Episode.fromJson(Map<String, dynamic> json, int seasonNum) {
    return Episode(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Episode ${json['episode_number']}',
      overview: json['overview'] ?? '',
      stillUrl: json['still_path'] != null ? 'https://image.tmdb.org/t/p/w500${json['still_path']}' : null,
      episodeNumber: json['episode_number'] ?? 1,
      seasonNumber: seasonNum,
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
