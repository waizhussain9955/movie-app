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
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        elevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: false,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search (e.g. Money Heist in Hindi)...',
            hintStyle: const TextStyle(color: Colors.grey),
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, color: Color(0xFFE50914)),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
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
      body: Column(
        children: [
          // Filter Chips Row (All, In Hindi / Dubbed, Movies, TV Series)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', Icons.apps),
                  const SizedBox(width: 8),
                  _buildFilterChip('In Hindi', Icons.translate, isHindiTag: true),
                  const SizedBox(width: 8),
                  _buildFilterChip('Movies', Icons.movie_outlined),
                  const SizedBox(width: 8),
                  _buildFilterChip('TV Series', Icons.tv),
                ],
              ),
            ),
          ),

          // Quick Search Suggestions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickSearches.map((term) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ActionChip(
                      label: Text(
                        term,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      backgroundColor: const Color(0xFF1A1A1A),
                      side: const BorderSide(color: Colors.white12),
                      onPressed: () => _triggerQuickSearch(term),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Search Results Grid
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
                : displayResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.movie_creation_outlined, size: 64, color: Colors.grey[700]),
                            const SizedBox(height: 12),
                            Text(
                              _controller.text.isEmpty
                                  ? 'Type to search over 50,000+ movies & TV shows'
                                  : 'No results found for "${_controller.text}"',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2 / 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: displayResults.length,
                        itemBuilder: (context, idx) {
                          final movie = displayResults[idx];
                          final isTv = movie.mediaType == 'tv';
                          final showHindiTag = _isHindiFilter || movie.isHindi;

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MovieDetailScreen(
                                    movie: movie,
                                    initialHindiAudio: _isHindiFilter || movie.isHindi,
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
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
                                        child: Center(
                                          child: Text(
                                            movie.title,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 10, color: Colors.white70),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      color: const Color(0xFF1E1E1E),
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
                                    top: 4,
                                    left: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isTv ? Colors.purple.withValues(alpha: 0.85) : Colors.red.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(3),
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
                                  // Hindi badge
                                  if (showHindiTag)
                                    Positioned(
                                      top: 20,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE50914),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: const Text(
                                          '🇮🇳 HINDI',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 7,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Rating badge
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        '★ ${movie.rating.toStringAsFixed(1)}',
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Bottom Title Gradient
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
                                        ),
                                      ),
                                      child: Text(
                                        movie.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
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
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected
            ? Colors.white
            : (isHindiTag ? const Color(0xFFE50914) : Colors.grey),
      ),
      label: Text(
        isHindiTag ? '🇮🇳 In Hindi / Dubbed' : label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[300],
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFE50914),
      backgroundColor: const Color(0xFF1E1E1E),
      side: BorderSide(
        color: isSelected
            ? const Color(0xFFE50914)
            : (isHindiTag ? const Color(0xFFE50914).withValues(alpha: 0.4) : Colors.white12),
      ),
      onSelected: (_) => _selectCategory(label),
    );
  }
}
