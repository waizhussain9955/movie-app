import 'package:flutter_test/flutter_test.dart';
import 'package:streammax_app/models/movie.dart';
import 'package:streammax_app/services/api_service.dart';
import 'package:streammax_app/services/download_service.dart';

void main() {
  test('Movie and 6 Servers JSON parsing test', () {
    final mockJson = {
      'id': 550,
      'title': 'Fight Club',
      'overview': 'An insomniac office worker...',
      'posterUrl': 'https://image.tmdb.org/t/p/w500/sample.jpg',
      'backdropUrl': 'https://image.tmdb.org/t/p/original/backdrop.jpg',
      'rating': 8.5,
      'year': '1999',
      'servers': [
        {'id': 1, 'name': 'Server 1 (VidSrc Pro)', 'quality': '1080p', 'url': 'https://vidsrc.to/embed/movie/550'},
        {'id': 2, 'name': 'Server 2 (VidLink Ultra)', 'quality': '1080p', 'url': 'https://vidlink.pro/movie/550'},
        {'id': 3, 'name': 'Server 3 (EmbedSu)', 'quality': '1080p', 'url': 'https://embed.su/embed/movie/550'},
        {'id': 4, 'name': 'Server 4 (2Embed)', 'quality': '720p', 'url': 'https://www.2embed.cc/embed/550'},
        {'id': 5, 'name': 'Server 5 (AutoEmbed)', 'quality': '1080p', 'url': 'https://player.autoembed.cc/embed/movie/550'},
        {'id': 6, 'name': 'Server 6 (SuperEmbed)', 'quality': '720p', 'url': 'https://multiembed.mov/directstream.php?video_id=550'},
      ]
    };

    final movie = Movie.fromJson(mockJson);

    expect(movie.id, 550);
    expect(movie.title, 'Fight Club');
    expect(movie.rating, 8.5);
    expect(movie.servers.length, 6);
    expect(movie.servers.first.name, 'Server 1 (VidSrc Pro)');
    expect(movie.servers.last.name, 'Server 6 (SuperEmbed)');
  });

  test('TV Show Season and Episode model parsing test', () {
    final seasonJson = {
      'id': 3624,
      'season_number': 1,
      'name': 'Season 1',
      'episode_count': 10,
    };
    final season = Season.fromJson(seasonJson);
    expect(season.seasonNumber, 1);
    expect(season.episodeCount, 10);

    final epJson = {
      'id': 63056,
      'episode_number': 1,
      'name': 'Winter Is Coming',
      'overview': 'Lord Stark is troubled by news from a deserter.',
      'still_path': '/o4IX9Mm0kpLITVANJMx7inyEUaY.jpg',
      'vote_average': 8.6,
    };
    final episode = Episode.fromJson(epJson, 1);
    expect(episode.episodeNumber, 1);
    expect(episode.name, 'Winter Is Coming');
    expect(episode.seasonNumber, 1);
    expect(episode.stillUrl, contains('o4IX9Mm0kpLITVANJMx7inyEUaY.jpg'));
  });

  test('Upcoming movie release date detection test', () {
    final futureDate = DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T').first;
    final upcomingMovie = Movie(
      id: 1610901,
      title: 'Upcoming Movie 2027',
      rating: 0.0,
      year: '2027',
      releaseDate: futureDate,
    );
    expect(upcomingMovie.isUpcoming, isTrue);

    final oldMovie = Movie(
      id: 64880,
      title: 'Tum Bin',
      rating: 7.5,
      year: '2001',
      releaseDate: '2001-06-25',
    );
    expect(oldMovie.isUpcoming, isFalse);
  });

  test('ApiService generateServers generates 6 distinct mirrors for Movie and TV', () {
    // Movie check
    final movieServers = ApiService.generateServers(550, isTv: false);
    expect(movieServers.length, 6);
    expect(movieServers.first.url, contains('vidlink.pro/movie/550'));
    expect(movieServers[1].url, contains('vidsrc.to/embed/movie/550'));

    // TV check (Game of Thrones S1 E1)
    final tvServers = ApiService.generateServers(1399, isTv: true, season: 1, episode: 1);
    expect(tvServers.length, 6);
    expect(tvServers.first.url, contains('vidlink.pro/tv/1399/1/1'));
    expect(tvServers[1].url, contains('vidsrc.to/embed/tv/1399/1/1'));
    expect(tvServers[2].url, contains('vidsrc.sh/embed/tv?tmdb=1399&season=1&episode=1'));
  });

  test('DownloadItem persistent JSON round-trip serialization test', () {
    final movie = Movie(
      id: 64880,
      title: 'Tum Bin',
      rating: 7.5,
      year: '2001',
      posterUrl: 'https://image.tmdb.org/t/p/w500/poster.jpg',
    );
    final item = DownloadItem(
      movie: movie,
      progress: 1.0,
      isCompleted: true,
      speed: 'Completed',
      size: '1.2 MB',
      localPath: '/data/user/0/com.example.streammax/files/movie_64880.mp4',
    );

    final jsonMap = item.toJson();
    final reconstructed = DownloadItem.fromJson(jsonMap);

    expect(reconstructed.movie.id, 64880);
    expect(reconstructed.movie.title, 'Tum Bin');
    expect(reconstructed.isCompleted, isTrue);
    expect(reconstructed.localPath, contains('movie_64880.mp4'));
  });

  test('Hindi Audio and Multi-Audio routing test', () {
    final hindiMovie = Movie(
      id: 64880,
      title: 'Tum Bin',
      rating: 7.5,
      year: '2001',
      originalLanguage: 'hi',
    );
    expect(hindiMovie.isHindi, isTrue);

    final englishMovie = Movie(
      id: 299534,
      title: 'Avengers: Endgame',
      rating: 8.3,
      year: '2019',
      originalLanguage: 'en',
    );
    expect(englishMovie.isHindi, isFalse);

    // Verify Hindi servers generation
    final hindiServers = ApiService.generateServers(299534, isTv: false, isHindiAudio: true);
    expect(hindiServers.length, 6);
    expect(hindiServers.first.name, contains('VidLink'));
    expect(hindiServers.first.url, contains('vidlink.pro/movie/299534'));
    expect(hindiServers[1].name, contains('VidSrc'));

    // Verify NetMirror VIP Server 1 injection
    const testM3u8 = 'https://tv.imgcdn.kim/newtv/hls/nf/80205342.m3u8';
    final netMirrorServers = ApiService.generateServers(
      71446,
      isTv: true,
      season: 1,
      episode: 1,
      isHindiAudio: true,
      netMirrorStreamUrl: testM3u8,
    );
    expect(netMirrorServers.first.name, contains('NetMirror VIP'));
    expect(netMirrorServers.first.url, testM3u8);
  });
}
