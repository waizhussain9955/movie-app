import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import 'movie_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  List<Movie> _heroMovies = [];
  List<Movie> _latestMovies = [];
  List<Movie> _trendingMovies = [];
  List<Movie> _series = [];
  List<Movie> _bollywood = [];
  List<Movie> _topRated = [];
  List<Movie> _action = [];
  List<Movie> _hollywood = [];
  List<Movie> _hindiDubbed = [];
  List<Movie> _anime = [];
  String _selectedCategory = 'All';

  final List<Map<String, String>> _categories = [
    {'label': 'All', 'icon': '🏠'},
    {'label': 'Latest', 'icon': '🆕'},
    {'label': 'Trending', 'icon': '🔥'},
    {'label': 'TV Series', 'icon': '📺'},
    {'label': 'Bollywood', 'icon': '🇮🇳'},
    {'label': 'Hollywood', 'icon': '🎬'},
    {'label': 'Hindi Dubbed', 'icon': '🎧'},
    {'label': 'Action', 'icon': '💥'},
    {'label': 'Anime', 'icon': '⛩️'},
    {'label': 'Top Rated', 'icon': '⭐'},
  ];

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    if (mounted) setState(() => _isLoading = true);
    final feed = await ApiService.getHomeFeed();
    if (mounted) {
      setState(() {
        _heroMovies    = feed['hero'] ?? [];
        _latestMovies  = feed['latest'] ?? [];
        _trendingMovies = feed['trending'] ?? [];
        _series        = feed['series'] ?? [];
        _bollywood     = feed['bollywood'] ?? [];
        _topRated      = feed['topRated'] ?? [];
        _action        = feed['action'] ?? [];
        _hollywood     = feed['hollywood'] ?? [];
        _hindiDubbed   = feed['hindiDubbed'] ?? [];
        _anime         = feed['anime'] ?? [];
        _isLoading     = false;
      });
    }
  }

  List<Movie> get _currentList {
    switch (_selectedCategory) {
      case 'Latest':       return _latestMovies;
      case 'Trending':     return _trendingMovies;
      case 'TV Series':    return _series;
      case 'Bollywood':    return _bollywood;
      case 'Hollywood':    return _hollywood;
      case 'Hindi Dubbed': return _hindiDubbed;
      case 'Action':       return _action;
      case 'Anime':        return _anime;
      case 'Top Rated':    return _topRated;
      default:             return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0C10),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFE50914), strokeWidth: 3),
              SizedBox(height: 16),
              Text(
                'Loading cinema experience...',
                style: TextStyle(color: Color(0xFF9EA3AE), fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    final featured = _heroMovies.isNotEmpty ? _heroMovies.first : null;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = screenHeight.clamp(330.0, 430.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C10),
      body: RefreshIndicator(
        color: const Color(0xFFE50914),
        backgroundColor: const Color(0xFF131720),
        onRefresh: _loadFeed,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // ── 1. App Bar with Brand Logo & Category Tabs ──────────
            SliverAppBar(
              pinned: true,
              floating: false,
              backgroundColor: const Color(0xFF0A0C10),
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_circle_fill, color: Color(0xFFE50914), size: 26),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'STREAMMAX',
                    style: TextStyle(
                      color: Color(0xFFE50914),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: Container(
                  color: const Color(0xFF0A0C10),
                  height: 50,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final cat = _categories[idx];
                      final label = cat['label']!;
                      final icon = cat['icon']!;
                      final isSelected = label == _selectedCategory;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = label),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE50914) : const Color(0xFF131720),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFE50914) : const Color(0xFF202634),
                              width: 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFE50914).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            '$icon $label',
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF9EA3AE),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // ── 2. Hero Featured Banner (All tab only) ─────────────
            if (featured != null && _selectedCategory == 'All')
              SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: featured))),
                  child: Container(
                    height: heroHeight,
                    margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (featured.posterUrl != null || featured.backdropUrl != null)
                          CachedNetworkImage(
                            imageUrl: featured.backdropUrl ?? featured.posterUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(color: const Color(0xFF131720)),
                            errorWidget: (_, _, _) => Container(color: const Color(0xFF131720)),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.45, 0.78, 1.0],
                              colors: [
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.75),
                                const Color(0xFF0A0C10),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16, left: 16, right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE50914),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'NOW PLAYING IN CINEMAS',
                                  style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                featured.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFB800),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, color: Colors.black, size: 12),
                                        const SizedBox(width: 2),
                                        Text(
                                          featured.rating.toStringAsFixed(1),
                                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    featured.year.isNotEmpty ? featured.year : '2024',
                                    style: const TextStyle(color: Color(0xFF9EA3AE), fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00C853).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF00C853), width: 0.6),
                                    ),
                                    child: const Text(
                                      '🎧 Multi-Audio',
                                      style: TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                                    label: const Text('Play Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE50914),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                      elevation: 4,
                                    ),
                                    onPressed: () => Navigator.push(context,
                                        MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: featured))),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                                    label: const Text('Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF2B3244), width: 1.2),
                                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                    ),
                                    onPressed: () => Navigator.push(context,
                                        MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: featured))),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── 3. Filtered Category Grid (when non-All category is picked) ────────
            if (_selectedCategory != 'All')
              ..._buildGridSlivers(
                title: '${_categories.firstWhere((c) => c['label'] == _selectedCategory)['icon']!} $_selectedCategory',
                movies: _currentList,
              ),

            // ── 4. All Tab — 30 Latest Movies Virtualized Grid ───────
            if (_selectedCategory == 'All')
              ..._buildGridSlivers(
                title: '🆕 30 Latest Movies',
                movies: _latestMovies.take(30).toList(),
              ),

            // ── 5. All Tab — Horizontal Movie Sections ──────────────
            if (_selectedCategory == 'All') ...[
              _buildSection(title: '🔥 Trending Worldwide',           movies: _trendingMovies),
              _buildSection(title: '📺 Top TV Series & Shows',        movies: _series),
              _buildSection(title: '🇮🇳 Bollywood & Hindi Cinema',    movies: _bollywood),
              _buildSection(title: '🎬 Hollywood Blockbusters',       movies: _hollywood),
              _buildSection(title: '🎧 Hindi Dubbed Hollywood',       movies: _hindiDubbed),
              _buildSection(title: '💥 Action & Thrillers',           movies: _action),
              _buildSection(title: '⛩️ Popular Anime',               movies: _anime),
              _buildSection(title: '⭐ Critically Acclaimed',         movies: _topRated),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],
        ),
      ),
    );
  }

  // ── Native Sliver Grid (Zero ShrinkWrap, 60fps Lazy Virtualization) ──
  List<Widget> _buildGridSlivers({required String title, required List<Movie> movies}) {
    if (movies.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.movie_filter_rounded, color: Colors.white24, size: 48),
                  SizedBox(height: 12),
                  Text('No content found in this category', style: TextStyle(color: Color(0xFF7E8695), fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF131720),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF202634)),
                ),
                child: Text(
                  '${movies.length} titles',
                  style: const TextStyle(color: Color(0xFF9EA3AE), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.58,
            crossAxisSpacing: 8,
            mainAxisSpacing: 10,
          ),
          itemCount: movies.length,
          itemBuilder: (context, idx) => _buildGridCard(movies[idx]),
        ),
      ),
    ];
  }

  Widget _buildGridCard(Movie movie) {
    final hasHindi = movie.isHindi || movie.isHindiDubbed;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie))),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF131720),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF202634), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster
            movie.posterUrl != null
                ? CachedNetworkImage(
                    imageUrl: movie.posterUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: const Color(0xFF131720)),
                    errorWidget: (_, _, _) => _placeholderCard(movie.title),
                  )
                : _placeholderCard(movie.title),

            // Top Badges
            Positioned(
              top: 5, left: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  movie.mediaType == 'tv' ? 'TV' : 'HD',
                  style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Positioned(
              top: 5, right: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white12, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 10),
                    const SizedBox(width: 2),
                    Text(
                      movie.rating.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom gradient + title
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.98),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasHindi) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF00C853), width: 0.5),
                        ),
                        child: const Text(
                          '🎧 HINDI',
                          style: TextStyle(color: Color(0xFF00E676), fontSize: 7.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                    Text(
                      movie.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      movie.year.isNotEmpty ? movie.year : '2024',
                      style: const TextStyle(color: Color(0xFF9EA3AE), fontSize: 9.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderCard(String title) {
    return Container(
      color: const Color(0xFF131720),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Color(0xFF9EA3AE)),
          ),
        ),
      ),
    );
  }

  // ── Horizontal scrollable row section ──────────────────────────
  Widget _buildSection({required String title, required List<Movie> movies}) {
    if (movies.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    final catMap = {
                      'Trending': 'Trending', 'TV Series': 'TV Series',
                      'Bollywood': 'Bollywood', 'Hollywood': 'Hollywood',
                      'Hindi Dubbed': 'Hindi Dubbed', 'Action': 'Action',
                      'Anime': 'Anime', 'Critically': 'Top Rated',
                    };
                    final matchKey = catMap.keys.firstWhere(
                        (k) => title.contains(k), orElse: () => '');
                    if (matchKey.isNotEmpty) {
                      setState(() => _selectedCategory = catMap[matchKey]!);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131720),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF202634)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See All',
                          style: TextStyle(color: Color(0xFFE50914), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 3),
                        Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFE50914), size: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 195,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: movies.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                final movie = movies[idx];
                final hasHindi = movie.isHindi || movie.isHindiDubbed;
                return GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie))),
                  child: Container(
                    width: 122,
                    decoration: BoxDecoration(
                      color: const Color(0xFF131720),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF202634), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (movie.posterUrl != null)
                          CachedNetworkImage(
                            imageUrl: movie.posterUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(color: const Color(0xFF131720)),
                            errorWidget: (_, _, _) => Container(
                              color: const Color(0xFF131720),
                              child: Center(
                                child: Text(movie.title, textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10, color: Colors.white70)),
                              ),
                            ),
                          )
                        else
                          Container(
                            color: const Color(0xFF131720),
                            child: Center(
                              child: Text(movie.title, textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, color: Colors.white)),
                            ),
                          ),
                        Positioned(
                          top: 5, right: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white12, width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 10),
                                const SizedBox(width: 2),
                                Text(
                                  movie.rating.toStringAsFixed(1),
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.75),
                                  Colors.black.withValues(alpha: 0.98),
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasHindi) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    margin: const EdgeInsets.only(bottom: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00C853).withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: const Color(0xFF00C853), width: 0.5),
                                    ),
                                    child: const Text(
                                      '🎧 HINDI',
                                      style: TextStyle(color: Color(0xFF00E676), fontSize: 7.5, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                                Text(
                                  movie.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  movie.year.isNotEmpty ? movie.year : '2024',
                                  style: const TextStyle(color: Color(0xFF9EA3AE), fontSize: 9.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
