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
  bool _isOverviewExpanded = false;

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
    final isTvCandidate = _currentMovie.mediaType == 'tv';

    if (isTvCandidate) {
      final tvData = await ApiService.getTVDetails(widget.movie.id);
      if (mounted) {
        final seasons = tvData['seasons'] as List<Season>? ?? [];
        setState(() {
          _currentMovie = (tvData['movie'] as Movie).copyWith(mediaType: 'tv');
          if (_currentMovie.isHindi || widget.initialHindiAudio || widget.movie.isHindiDubbed) {
            _isHindiAudio = true;
          }
          _seasons = seasons;
          if (_seasons.isNotEmpty) {
            _selectedSeasonNumber = _seasons.first.seasonNumber;
          }
        });
        if (_seasons.isNotEmpty) {
          _loadEpisodes(_selectedSeasonNumber);
        }
        return;
      }
    }

    final full = await ApiService.getMovieDetails(widget.movie.id);
    if (full != null && mounted) {
      setState(() {
        _currentMovie = full;
        if (full.isHindi || widget.initialHindiAudio || widget.movie.isHindiDubbed) {
          _isHindiAudio = true;
        }
      });
    } else {
      // Fallback: If movie returned 404 (e.g. Game of Thrones opened from search as movie), try TV details!
      final tvData = await ApiService.getTVDetails(widget.movie.id);
      final fallbackSeasons = tvData['seasons'] as List<Season>? ?? [];
      if (fallbackSeasons.isNotEmpty && mounted) {
        setState(() {
          _currentMovie = (tvData['movie'] as Movie).copyWith(mediaType: 'tv');
          if (_currentMovie.isHindi || widget.initialHindiAudio || widget.movie.isHindiDubbed) {
            _isHindiAudio = true;
          }
          _seasons = fallbackSeasons;
          if (_seasons.isNotEmpty) {
            _selectedSeasonNumber = _seasons.first.seasonNumber;
          }
        });
        _loadEpisodes(_selectedSeasonNumber);
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
            allEpisodes: isTv ? _episodes : null,
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
        backgroundColor: const Color(0xFF0A0C10),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // 1. Sliver App Bar with Backdrop Image & Back Button
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: const Color(0xFF0A0C10),
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_currentMovie.backdropUrl != null || _currentMovie.posterUrl != null)
                      CachedNetworkImage(
                        imageUrl: _currentMovie.backdropUrl ?? _currentMovie.posterUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: const Color(0xFF131720)),
                        errorWidget: (_, _, _) => Container(color: const Color(0xFF131720)),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.45, 0.8, 1.0],
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                            const Color(0xFF0A0C10),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Movie Information & Clean Action Buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Meta Info Row (Rating, Year, HD Badge, Media Type)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB800),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.black, size: 13),
                              const SizedBox(width: 2),
                              Text(
                                _currentMovie.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _currentMovie.year.isNotEmpty ? _currentMovie.year : '2024',
                          style: const TextStyle(color: Color(0xFF9EA3AE), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131720),
                            border: Border.all(color: const Color(0xFF202634)),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            isTv ? 'TV SERIES' : '1080p FULL HD',
                            style: const TextStyle(color: Color(0xFF9EA3AE), fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_currentMovie.isUpcoming)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              border: Border.all(color: Colors.orange, width: 0.8),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'In Theaters',
                              style: TextStyle(color: Colors.orange, fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C853).withValues(alpha: 0.18),
                              border: Border.all(color: const Color(0xFF00C853), width: 0.8),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'Stream Ready',
                              style: TextStyle(color: Color(0xFF00E676), fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Audio Track / Language Selector
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131720),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF202634)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.multitrack_audio_rounded, color: Color(0xFFE50914), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Audio Track Preference:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _isHindiAudio = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: !_isHindiAudio ? const Color(0xFFE50914) : const Color(0xFF1B202B),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: !_isHindiAudio ? const Color(0xFFE50914) : const Color(0xFF2B3244),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '🇬🇧 English Audio',
                                        style: TextStyle(
                                          color: !_isHindiAudio ? Colors.white : const Color(0xFF9EA3AE),
                                          fontSize: 12,
                                          fontWeight: !_isHindiAudio ? FontWeight.bold : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _isHindiAudio = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: _isHindiAudio ? const Color(0xFFE50914) : const Color(0xFF1B202B),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _isHindiAudio ? const Color(0xFFE50914) : const Color(0xFF2B3244),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _currentMovie.isHindi ? '🇮🇳 Hindi Original' : '🇮🇳 Hindi Dubbed',
                                        style: TextStyle(
                                          color: _isHindiAudio ? Colors.white : const Color(0xFF9EA3AE),
                                          fontSize: 12,
                                          fontWeight: _isHindiAudio ? FontWeight.bold : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Primary CTA Buttons: [WATCH NOW] & [DOWNLOAD]
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                            label: Text(
                              isTv ? 'WATCH S1 E1' : 'WATCH NOW',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE50914),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
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
                                  isDownloaded ? Icons.check_circle_rounded : Icons.file_download_outlined,
                                  color: isDownloaded ? const Color(0xFF00E676) : Colors.white,
                                  size: 20,
                                ),
                                label: Text(
                                  isDownloaded ? 'Saved' : 'Download',
                                  style: TextStyle(
                                    color: isDownloaded ? const Color(0xFF00E676) : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isDownloaded ? const Color(0xFF00C853) : const Color(0xFF2B3244),
                                    width: 1.2,
                                  ),
                                  backgroundColor: const Color(0xFF131720),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  if (isDownloaded) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Saved offline in "My Downloads" tab.'),
                                        backgroundColor: Color(0xFF131720),
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
                    const SizedBox(height: 22),

                    // Overview Synopsis with Read More / Read Less
                    const Text(
                      'STORYLINE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentMovie.overview ?? 'No synopsis available for this title.',
                      style: const TextStyle(
                        color: Color(0xFFC5CAD4),
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                      maxLines: _isOverviewExpanded ? 20 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((_currentMovie.overview ?? '').length > 140)
                      GestureDetector(
                        onTap: () => setState(() => _isOverviewExpanded = !_isOverviewExpanded),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _isOverviewExpanded ? 'Show Less' : 'Read More',
                            style: const TextStyle(
                              color: Color(0xFFE50914),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // 3. TV SERIES SEASONS SECTION
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
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _seasons.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, idx) {
                              final s = _seasons[idx];
                              final isSelected = s.seasonNumber == _selectedSeasonNumber;
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedSeasonNumber = s.seasonNumber);
                                  _loadEpisodes(s.seasonNumber);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFE50914) : const Color(0xFF131720),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFFE50914) : const Color(0xFF202634),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Season ${s.seasonNumber}',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : const Color(0xFF9EA3AE),
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),

            // 4. Native Butter-Smooth Episodes SliverList
            if (isTv) ...[
              if (_isLoadingEpisodes)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(28.0),
                      child: CircularProgressIndicator(color: Color(0xFFE50914), strokeWidth: 3),
                    ),
                  ),
                )
              else if (_episodes.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'Episodes will be loaded shortly...',
                        style: TextStyle(color: Color(0xFF7E8695)),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  sliver: SliverList.separated(
                    itemCount: _episodes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final ep = _episodes[idx];
                      return InkWell(
                        onTap: () => _playEpisode(ep),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131720),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF202634)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Episode Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 104,
                                      height: 64,
                                      child: ep.stillUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: ep.stillUrl!,
                                              fit: BoxFit.cover,
                                              placeholder: (_, _) => Container(color: const Color(0xFF1B202B)),
                                              errorWidget: (_, _, _) => Container(
                                                color: const Color(0xFF1B202B),
                                                child: const Icon(Icons.movie_rounded, color: Colors.white24),
                                              ),
                                            )
                                          : Container(
                                              color: const Color(0xFF1B202B),
                                              child: const Icon(Icons.movie_rounded, color: Colors.white24),
                                            ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white24, width: 0.8),
                                      ),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
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
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      ep.overview.isNotEmpty ? ep.overview : 'No description available.',
                                      style: const TextStyle(
                                        color: Color(0xFF9EA3AE),
                                        fontSize: 11,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.play_circle_fill, color: Color(0xFFE50914), size: 30),
                                onPressed: () => _playEpisode(ep),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
            if (!isTv)
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
