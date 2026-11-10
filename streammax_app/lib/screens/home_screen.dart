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
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFE50914)),
              SizedBox(height: 16),
              Text(
                'Loading cinema experience...',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final featured = _heroMovies.isNotEmpty ? _heroMovies.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: RefreshIndicator(
        color: const Color(0xFFE50914),
        onRefresh: _loadFeed,
        child: CustomScrollView(
          slivers: [
            // ── 1. App Bar ──────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              floating: false,
              backgroundColor: const Color(0xFF0A0A0A),
              elevation: 0,
              title: const Row(
                children: [
                  Icon(Icons.play_circle_fill, color: Color(0xFFE50914), size: 28),
                  SizedBox(width: 8),
                  Text(
                    'STREAMMAX',
                    style: TextStyle(
                      color: Color(0xFFE50914),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Container(
                  color: const Color(0xFF0A0A0A),
                  height: 52,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    scrollDirection: Axis.horizontal,
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
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE50914) : const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected ? null : Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            '$icon $label',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[400],
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                    height: 400,
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (featured.posterUrl != null || featured.backdropUrl != null)
                            CachedNetworkImage(
                              imageUrl: featured.backdropUrl ?? featured.posterUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(color: const Color(0xFF1F1F1F)),
                              errorWidget: (_, _, _) => Container(color: const Color(0xFF1F1F1F)),
                            ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.5),
                                  Colors.black.withValues(alpha: 0.95),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16, left: 16, right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // NEW badge + title
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE50914),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('🆕 NOW PLAYING', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  featured.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                                      child: Text('★ ${featured.rating.toStringAsFixed(1)}',
                                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(featured.year, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.greenAccent, width: 0.5)),
                                      child: const Text('🎧 Multi-Audio', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                                      label: const Text('Play Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFE50914),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => Navigator.push(context,
                                          MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: featured))),
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.info_outline, color: Colors.white),
                                      label: const Text('Details', style: TextStyle(color: Colors.white)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.white30),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              ),

            // ── 3. Filtered category grid (non-All tabs) ────────────
            if (_selectedCategory != 'All')
              _buildGridSection(
                title: '${_categories.firstWhere((c) => c['label'] == _selectedCategory)['icon']!} $_selectedCategory',
                movies: _currentList,
              ),

            // ── 4. All Tab — 30 Latest Movies GRID ─────────────────
            if (_selectedCategory == 'All')
              _buildGridSection(
                title: '🆕 30 Latest Movies',
                movies: _latestMovies.take(30).toList(),
              ),

            // ── 5. All Tab — Horizontal rows ───────────────────────
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

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ── Grid section (3-column) for category filter + latest 30 ──
  Widget _buildGridSection({required String title, required List<Movie> movies}) {
    if (movies.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.movie_filter, color: Colors.white24, size: 48),
                SizedBox(height: 12),
                Text('No content found', style: TextStyle(color: Colors.white38, fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.62,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: movies.length,
            itemBuilder: (context, idx) => _buildGridCard(movies[idx]),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(Movie movie) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster
            movie.posterUrl != null
                ? CachedNetworkImage(
                    imageUrl: movie.posterUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: const Color(0xFF1E1E1E)),
                    errorWidget: (_, _, _) => _placeholderCard(movie.title),
                  )
                : _placeholderCard(movie.title),
            // Top badges
            Positioned(
              top: 6, left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFE50914), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  movie.mediaType == 'tv' ? 'TV' : 'Movie',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Positioned(
              top: 6, right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(4)),
                child: Text('★ ${movie.rating.toStringAsFixed(1)}',
                    style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ),
            // Bottom gradient + title
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.95)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(movie.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(movie.year, style: const TextStyle(color: Colors.white54, fontSize: 10)),
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
      color: const Color(0xFF1E1E1E),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(title, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
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
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
                GestureDetector(
                  onTap: () {
                    // Extract category from title icon
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
                  child: const Text('See All →',
                      style: TextStyle(color: Color(0xFFE50914), fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                final movie = movies[idx];
                return GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 120,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (movie.posterUrl != null)
                            CachedNetworkImage(
                              imageUrl: movie.posterUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(color: const Color(0xFF1E1E1E)),
                              errorWidget: (_, _, _) => Container(
                                color: const Color(0xFF1E1E1E),
                                child: Center(child: Text(movie.title, textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10, color: Colors.white70))),
                              ),
                            )
                          else
                            Container(color: const Color(0xFF1E1E1E),
                                child: Center(child: Text(movie.title, textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11, color: Colors.white)))),
                          Positioned(
                            top: 6, right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(4)),
                              child: Text('★ ${movie.rating.toStringAsFixed(1)}',
                                  style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
                                ),
                              ),
                              child: Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
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
