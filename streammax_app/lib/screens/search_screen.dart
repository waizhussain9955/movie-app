import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import 'movie_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Movie> _results = [];
  bool _isSearching = false;
  bool _isHindiFilter = false;
  String _selectedCategory = 'All'; // 'All', 'In Hindi', 'Movies', 'TV Series'
  Timer? _debounceTimer;

  final List<String> _quickSearches = [
    'Money Heist in Hindi',
    'Game of Thrones in Hindi',
    'Tum Bin',
    'Avengers in Hindi',
    'Breaking Bad in Hindi',
    'Squid Game in Hindi',
    'Fight Club',
    'The Dark Knight',
  ];

  void _onQueryChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _executeSearch(query);
    });
  }

  void _executeSearch(String query) async {
    final raw = query.trim();
    if (raw.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    // 1. SMART QUERY CLEANER FOR "IN HINDI" / "DUBBED"
    // Strips trailing 'in hindi', 'hindi dubbed', etc. so TMDB can find the actual title!
    bool queryTargetedHindi = _isHindiFilter || _selectedCategory == 'In Hindi';
    String cleanTitle = raw;
    final hindiPatterns = [
      RegExp(r'\bin hindi\b', caseSensitive: false),
      RegExp(r'\bhindi dubbed\b', caseSensitive: false),
      RegExp(r'\bhindi audio\b', caseSensitive: false),
      RegExp(r'\bhindi version\b', caseSensitive: false),
      RegExp(r'\bhindi\b', caseSensitive: false),
      RegExp(r'\bdubbed\b', caseSensitive: false),
      RegExp(r'\bin urdu\b', caseSensitive: false),
      RegExp(r'\burdu\b', caseSensitive: false),
    ];

    for (final pattern in hindiPatterns) {
      if (pattern.hasMatch(cleanTitle)) {
        queryTargetedHindi = true;
        cleanTitle = cleanTitle.replaceAll(pattern, '').trim();
      }
    }

    // Clean dangling prepositions (e.g. "Money Heist in" -> "Money Heist")
    cleanTitle = cleanTitle.replaceAll(RegExp(r'\s+(in|of|the)$', caseSensitive: false), '').trim();
    if (cleanTitle.isEmpty) cleanTitle = raw;

    setState(() {
      _isSearching = true;
      if (queryTargetedHindi) {
        _isHindiFilter = true;
      }
    });

    final res = await ApiService.search(cleanTitle);
    if (mounted) {
      setState(() {
        _results = res;
        _isSearching = false;
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  void _triggerQuickSearch(String term) {
    _controller.text = term;
    _executeSearch(term);
  }

  void _selectCategory(String cat) {
    setState(() {
      _selectedCategory = cat;
      _isHindiFilter = (cat == 'In Hindi');
    });
    if (_controller.text.isNotEmpty) {
      _executeSearch(_controller.text);
    }
  }

  List<Movie> _getFilteredResults() {
    if (_selectedCategory == 'Movies') {
      return _results.where((m) => m.mediaType == 'movie').toList();
    }
    if (_selectedCategory == 'TV Series') {
      return _results.where((m) => m.mediaType == 'tv').toList();
    }
    return _results;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayResults = _getFilteredResults();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0C10),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 14,
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF131720),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF202634), width: 1),
          ),
          child: TextField(
            controller: _controller,
            autofocus: false,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Search movies, series (e.g. Money Heist in Hindi)...',
              hintStyle: const TextStyle(color: Color(0xFF7E8695), fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFE50914), size: 20),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF9EA3AE), size: 18),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _results = []);
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              setState(() {});
              _onQueryChanged(val);
            },
            onSubmitted: _executeSearch,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Row (All, In Hindi / Dubbed, Movies, TV Series)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0C10),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterChip('All', Icons.apps_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip('In Hindi', Icons.translate_rounded, isHindiTag: true),
                  const SizedBox(width: 8),
                  _buildFilterChip('Movies', Icons.movie_outlined),
                  const SizedBox(width: 8),
                  _buildFilterChip('TV Series', Icons.tv_rounded),
                ],
              ),
            ),
          ),

          // Quick Search Suggestions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _quickSearches.map((term) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: GestureDetector(
                      onTap: () => _triggerQuickSearch(term),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131720),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF202634)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.trending_up_rounded, color: Color(0xFFE50914), size: 13),
                            const SizedBox(width: 4),
                            Text(
                              term,
                              style: const TextStyle(color: Color(0xFFC5CAD4), fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Search Results Grid
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914), strokeWidth: 3))
                : displayResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFF131720),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.search_rounded, size: 48, color: Color(0xFF7E8695)),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _controller.text.isEmpty
                                  ? 'Type to search over 50,000+ movies & TV shows'
                                  : 'No results found for "${_controller.text}"',
                              style: const TextStyle(color: Color(0xFF9EA3AE), fontSize: 13.5, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: displayResults.length,
                        itemBuilder: (context, idx) {
                          final movie = displayResults[idx];
                          final isTv = movie.mediaType == 'tv';
                          final showHindiTag = _isHindiFilter || movie.isHindi || movie.isHindiDubbed;

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MovieDetailScreen(
                                    movie: movie,
                                    initialHindiAudio: _isHindiFilter || movie.isHindi || movie.isHindiDubbed,
                                  ),
                                ),
                              );
                            },
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
                                  if (movie.posterUrl != null)
                                    CachedNetworkImage(
                                      imageUrl: movie.posterUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (_, _) => Container(color: const Color(0xFF131720)),
                                      errorWidget: (_, _, _) => Container(
                                        color: const Color(0xFF131720),
                                        child: Center(
                                          child: Text(
                                            movie.title,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 10, color: Color(0xFF9EA3AE)),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      color: const Color(0xFF131720),
                                      padding: const EdgeInsets.all(4),
                                      child: Center(
                                        child: Text(
                                          movie.title,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 11, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  // Type badge (TV vs Movie)
                                  Positioned(
                                    top: 5,
                                    left: 5,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE50914),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isTv ? 'SERIES' : 'MOVIE',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Rating badge
                                  Positioned(
                                    top: 5,
                                    right: 5,
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
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Bottom Title Gradient
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
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
                                          if (showHindiTag) ...[
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
                                                style: TextStyle(
                                                  color: Color(0xFF00E676),
                                                  fontSize: 7.5,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ],
                                          Text(
                                            movie.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            movie.year.isNotEmpty ? movie.year : '2024',
                                            style: const TextStyle(
                                              color: Color(0xFF9EA3AE),
                                              fontSize: 9,
                                            ),
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

  Widget _buildFilterChip(String label, IconData icon, {bool isHindiTag = false}) {
    final isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () => _selectCategory(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE50914) : const Color(0xFF131720),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE50914)
                : (isHindiTag ? const Color(0xFF00C853).withValues(alpha: 0.5) : const Color(0xFF202634)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? Colors.white
                  : (isHindiTag ? const Color(0xFF00E676) : const Color(0xFF9EA3AE)),
            ),
            const SizedBox(width: 5),
            Text(
              isHindiTag ? '🇮🇳 In Hindi' : label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF9EA3AE),
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
