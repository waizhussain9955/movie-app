import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../services/netmirror_service.dart';
import 'player_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final Movie movie;
  final bool initialHindiAudio;

  const MovieDetailScreen({
    super.key,
    required this.movie,
    this.initialHindiAudio = false,
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  late Movie _currentMovie;
  List<Season> _seasons = [];
  int _selectedSeasonNumber = 1;
  List<Episode> _episodes = [];
  bool _isLoadingEpisodes = false;
  late bool _isHindiAudio;

  @override
  void initState() {
    super.initState();
    _currentMovie = widget.movie;
    // Hindi Dubbed row titles are English-original, so isHindi alone is not
    // enough: a title tagged isHindiDubbed must also open in Hindi mode.
    _isHindiAudio = widget.initialHindiAudio ||
        widget.movie.isHindi ||
        widget.movie.isHindiDubbed;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    if (_currentMovie.mediaType == 'tv') {
      final tvData = await ApiService.getTVDetails(widget.movie.id);
      if (mounted) {
        setState(() {
          _currentMovie = tvData['movie'] as Movie;
          // NOTE: getTVDetails rebuilds the Movie, so the isHindiDubbed tag
          // from the home row is lost here — read it from widget.movie.
          if (_currentMovie.isHindi ||
              widget.initialHindiAudio ||
              widget.movie.isHindiDubbed) {
            _isHindiAudio = true;
          }
          _seasons = tvData['seasons'] as List<Season>;
          if (_seasons.isNotEmpty) {
            _selectedSeasonNumber = _seasons.first.seasonNumber;
          }
        });
        if (_seasons.isNotEmpty) {
          _loadEpisodes(_selectedSeasonNumber);
        }
      }
    } else {
      final full = await ApiService.getMovieDetails(widget.movie.id);
      if (full != null && mounted) {
        setState(() {
          _currentMovie = full;
          // NOTE: getMovieDetails rebuilds the Movie, so the isHindiDubbed
          // tag from the home row is lost here — read it from widget.movie.
          if (full.isHindi ||
              widget.initialHindiAudio ||
              widget.movie.isHindiDubbed) {
            _isHindiAudio = true;
          }
        });
      }
    }
  }

  Future<void> _loadEpisodes(int seasonNumber) async {
    setState(() => _isLoadingEpisodes = true);
    final eps = await ApiService.getSeasonEpisodes(_currentMovie.id, seasonNumber);
    if (mounted) {
      setState(() {
        _episodes = eps;
        _isLoadingEpisodes = false;
      });
    }
  }

  Future<void> _launchPlayer({int? season, int? episode, String? episodeTitle}) async {
    final isTv = _currentMovie.mediaType == 'tv';
    final sNum = season ?? 1;
    final epNum = episode ?? 1;

    // Show instant SnackBar while resolving Fast Streaming Mirrors
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚡ Connecting to Fast Streaming Mirrors...'),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF1E1E1E),
      ),
    );

    // Resolve NetMirror HLS Stream with timeout of 8 seconds
    String? netmirrorUrl;
    try {
      netmirrorUrl = await NetMirrorService.resolveStream(
        _currentMovie.title,
        isTv: isTv,
        season: sNum,
        episode: epNum,
      ).timeout(const Duration(seconds: 8), onTimeout: () => null);
    } catch (_) {}

    final servers = ApiService.generateServers(
      _currentMovie.id,
      isTv: isTv,
      season: sNum,
      episode: epNum,
      isHindiAudio: _isHindiAudio,
      netMirrorStreamUrl: netmirrorUrl,
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            movie: _currentMovie,
            servers: servers,
            episodeTitle: episodeTitle ?? (isTv ? 'Season $sNum Episode $epNum' : null),
            seasonNumber: isTv ? sNum : null,
            episodeNumber: isTv ? epNum : null,
            initialHindiAudio: _isHindiAudio,
          ),
        ),
      );
    }
  }

  void _playEpisode(Episode episode) {
    _launchPlayer(
      season: episode.seasonNumber,
      episode: episode.episodeNumber,
      episodeTitle: 'S${episode.seasonNumber} E${episode.episodeNumber}: ${episode.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTv = _currentMovie.mediaType == 'tv';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: CustomScrollView(
          slivers: [
            // 1. Sliver App Bar with Backdrop Image & Back Button
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: const Color(0xFF0F0F0F),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_currentMovie.backdropUrl != null || _currentMovie.posterUrl != null)
                      CachedNetworkImage(
                        imageUrl: _currentMovie.backdropUrl ?? _currentMovie.posterUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: const Color(0xFF1A1A1A)),
                        errorWidget: (_, _, _) => Container(color: const Color(0xFF1A1A1A)),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                            const Color(0xFF0F0F0F),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Movie Information & Clean Action Buttons (NO CLUTTERED SERVERS)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      _currentMovie.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Meta Info Row (Rating, Year, HD Badge, Media Type)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '★ ${_currentMovie.rating.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          _currentMovie.year,
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isTv ? 'TV SERIES' : '1080p HD',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                        if (_currentMovie.isUpcoming)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              border: Border.all(color: Colors.orange),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Upcoming / In Theaters',
                              style: TextStyle(color: Colors.orange, fontSize: 11),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              border: Border.all(color: Colors.green),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Stream Ready',
                              style: TextStyle(color: Colors.green, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Audio Track / Language Selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181818),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.volume_up, color: Colors.amber, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Select Audio Track:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text('🇬🇧 English', style: TextStyle(fontSize: 12)),
                                selected: !_isHindiAudio,
                                selectedColor: const Color(0xFFE50914),
                                backgroundColor: const Color(0xFF262626),
                                labelStyle: TextStyle(
                                  color: !_isHindiAudio ? Colors.white : Colors.grey[400],
                                  fontWeight: !_isHindiAudio ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (val) {
                                  if (val) setState(() => _isHindiAudio = false);
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Text(
                                  _currentMovie.isHindi ? '🇮🇳 Hindi (Original)' : '🇮🇳 Hindi Dubbed',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                selected: _isHindiAudio,
                                selectedColor: const Color(0xFFE50914),
                                backgroundColor: const Color(0xFF262626),
                                labelStyle: TextStyle(
                                  color: _isHindiAudio ? Colors.white : Colors.grey[400],
                                  fontWeight: _isHindiAudio ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (val) {
                                  if (val) setState(() => _isHindiAudio = true);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Primary CTA Buttons: [WATCH NOW] & [DOWNLOAD]
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                            label: Text(
                              isTv ? 'WATCH S1 E1' : 'WATCH NOW',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE50914),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _launchPlayer(season: 1, episode: 1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ValueListenableBuilder<List<DownloadItem>>(
                            valueListenable: DownloadService().downloadsNotifier,
                            builder: (context, downloads, _) {
                              final isDownloaded = downloads.any((d) => d.movie.id == _currentMovie.id && d.isCompleted);
                              return OutlinedButton.icon(
                                icon: Icon(
                                  isDownloaded ? Icons.check_circle : Icons.download,
                                  color: isDownloaded ? Colors.greenAccent : Colors.white,
                                ),
                                label: Text(
                                  isDownloaded ? 'Downloaded' : 'Download',
                                  style: TextStyle(color: isDownloaded ? Colors.greenAccent : Colors.white),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: isDownloaded ? Colors.green : Colors.white30),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  if (isDownloaded) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Saved offline in "My Downloads" tab.'),
                                        backgroundColor: Color(0xFF222222),
                                      ),
                                    );
                                  } else {
                                    DownloadService().startDownload(_currentMovie);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('⬇️ Downloading "${_currentMovie.title}" for offline watching...'),
                                        backgroundColor: const Color(0xFFE50914),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Overview Synopsis
                    const Text(
                      'STORYLINE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentMovie.overview ?? 'No synopsis available for this title.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 3. TV SERIES SEASONS & EPISODES SECTION
                    if (isTv) ...[
                      const Text(
                        'SEASONS & EPISODES',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Horizontal Season Pills
                      if (_seasons.isNotEmpty)
                        SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _seasons.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, idx) {
                              final s = _seasons[idx];
                              final isSelected = s.seasonNumber == _selectedSeasonNumber;
                              return ChoiceChip(
                                label: Text(
                                  'Season ${s.seasonNumber}',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.grey[400],
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: const Color(0xFFE50914),
                                backgroundColor: const Color(0xFF1E1E1E),
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _selectedSeasonNumber = s.seasonNumber);
                                    _loadEpisodes(s.seasonNumber);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Episode List
                      if (_isLoadingEpisodes)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(color: Color(0xFFE50914)),
                          ),
                        )
                      else if (_episodes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Episodes will be loaded shortly...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _episodes.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, idx) {
                            final ep = _episodes[idx];
                            return InkWell(
                              onTap: () => _playEpisode(ep),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF181818),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Episode Thumbnail
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 100,
                                            height: 60,
                                            child: ep.stillUrl != null
                                                ? CachedNetworkImage(
                                                    imageUrl: ep.stillUrl!,
                                                    fit: BoxFit.cover,
                                                    placeholder: (_, _) => Container(color: Colors.black26),
                                                    errorWidget: (_, _, _) => Container(color: Colors.black26),
                                                  )
                                                : Container(
                                                    color: Colors.black38,
                                                    child: const Icon(Icons.movie, color: Colors.grey),
                                                  ),
                                          ),
                                          const CircleAvatar(
                                            radius: 14,
                                            backgroundColor: Colors.black54,
                                            child: Icon(Icons.play_arrow, color: Colors.white, size: 18),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Episode Meta
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${ep.episodeNumber}. ${ep.name}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            ep.overview.isNotEmpty ? ep.overview : 'No overview available.',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 11,
                                              height: 1.3,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
