import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../providers/provider.dart';
import 'player_screen.dart';

/// Stremio-style provider search: searches the MLSBD & HDHub4u download
/// indexes for dual-audio (Hindi dubbed) titles and opens the found links
/// in the existing WebView [PlayerScreen].
///
/// Entry points (wired, additive only):
///   * Home screen — "Dual Audio Downloads" card.
///   * Movie detail screen — "Providers" button (pre-fills the movie title).
///
/// NOTE: provider links are plain web pages / file-host links, NOT direct
/// .m3u8 streams. They open in PlayerScreen's WebView, which handles the
/// host's own watch / download flow. See README for the PlayerScreen
/// navigation-whitelist step that is required before these links will load.
class ProviderSearchScreen extends StatefulWidget {
  final String? initialQuery;
  final Movie? movie;

  const ProviderSearchScreen({super.key, this.initialQuery, this.movie});

  @override
  State<ProviderSearchScreen> createState() => _ProviderSearchScreenState();
}

class _ProviderSearchScreenState extends State<ProviderSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<ProviderListing> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _selectedProvider = 'all'; // 'all' | 'mlsbd' | 'hdhub4u'

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null &&
        widget.initialQuery!.trim().isNotEmpty) {
      _controller.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _executeSearch(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _executeSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _hasSearched = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });
    try {
      List<ProviderListing> res;
      if (_selectedProvider == 'all') {
        res = await ProviderRegistry.searchAll(q);
      } else {
        final provider = ProviderRegistry.byId(_selectedProvider);
        res = provider == null
            ? <ProviderListing>[]
            : await provider.search(q).timeout(
                  const Duration(seconds: 12),
                  onTimeout: () => <ProviderListing>[],
                );
      }
      if (!mounted) return;
      setState(() {
        _results = res;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Provider search failed. Check your connection and try again.',
          ),
          backgroundColor: Color(0xFFE50914),
        ),
      );
    }
  }

  void _selectProvider(String id) {
    if (_selectedProvider == id) return;
    setState(() => _selectedProvider = id);
    if (_controller.text.trim().isNotEmpty) {
      _executeSearch(_controller.text);
    }
  }

  Future<void> _openListing(ProviderListing listing) async {
    final provider = ProviderRegistry.byId(listing.providerId);
    if (provider == null) return;
    // Track the dialog: the user can still dismiss it with the system back
    // button while the fetch runs, and a second pop would close this screen.
    var dialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFE50914)),
      ),
    ).then((_) => dialogOpen = false);
    List<ProviderLink> links;
    try {
      links = await provider.fetchLinks(listing).timeout(
            const Duration(seconds: 15),
            onTimeout: () => <ProviderLink>[
              ProviderLink(
                label: 'Open post page',
                url: listing.postUrl,
                kind: 'download',
              ),
            ],
          );
    } catch (_) {
      links = <ProviderLink>[
        ProviderLink(
          label: 'Open post page',
          url: listing.postUrl,
          kind: 'download',
        ),
      ];
    }
    if (!mounted) return;
    if (dialogOpen) Navigator.pop(context); // close loading dialog
    _showLinksSheet(listing, links);
  }

  void _showLinksSheet(ProviderListing listing, List<ProviderLink> links) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131720),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B3244),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  listing.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${listing.providerName}  •  ${listing.audioLabel.isNotEmpty ? listing.audioLabel : 'Dual Audio'}',
                  style: const TextStyle(color: Color(0xFF9EA3AE), fontSize: 12),
                ),
                const Divider(color: Color(0xFF202634), height: 20),
                ...links.map((link) => _buildLinkTile(link, listing)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinkTile(ProviderLink link, ProviderListing listing) {
    final isWatch = link.kind == 'watch';
    final host = Uri.tryParse(link.url)?.host ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF202634)),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          isWatch
              ? Icons.play_circle_fill
              : Icons.file_download_outlined,
          color:
              isWatch ? const Color(0xFFE50914) : const Color(0xFF00E676),
          size: 24,
        ),
        title: Text(
          link.label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          host,
          style: const TextStyle(color: Color(0xFF9EA3AE), fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (isWatch ? const Color(0xFFE50914) : const Color(0xFF00C853))
                .withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isWatch ? 'WATCH' : 'DOWNLOAD',
            style: TextStyle(
              color: isWatch ? Colors.white : const Color(0xFF00E676),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _openLinkInPlayer(link, listing),
      ),
    );
  }

  /// Opens a provider link in the existing WebView player. The provider
  /// link goes first; the movie's existing embed servers (VidLink, Videasy,
  /// …) follow as fallbacks when a [Movie] was passed in. With no [Movie],
  /// the provider link opens on its own.
  void _openLinkInPlayer(ProviderLink link, ProviderListing listing) {
    Navigator.pop(context); // close the bottom sheet
    final providerServer = StreamServer(
      id: 9001,
      name:
          '${listing.providerName} ${link.kind == 'watch' ? 'Watch' : 'Download'}',
      quality: 'Provider',
      url: link.url,
    );
    final movie = widget.movie ?? _fallbackMovie(listing);
    final servers = <StreamServer>[
      providerServer,
      ...?widget.movie?.servers,
    ];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          movie: movie,
          servers: servers,
          initialHindiAudio: true,
        ),
      ),
    );
  }

  /// PlayerScreen requires a Movie. When the search screen was opened
  /// without one (home-screen entry point), build a minimal Movie from the
  /// listing itself.
  Movie _fallbackMovie(ProviderListing listing) {
    return Movie(
      id: 0,
      title: listing.title,
      rating: 0.0,
      year: listing.year,
      mediaType: listing.mediaKind == 'tv' ? 'tv' : 'movie',
      isHindiDubbed: listing.isDualAudio,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0C10),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 14,
        title: const Text(
          'Dual Audio Providers',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search row: TextField + Search button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF131720),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFF202634),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: const InputDecoration(
                        hintText:
                            'Search dual-audio titles (e.g. Avengers)...',
                        hintStyle: TextStyle(
                          color: Color(0xFF7E8695),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Color(0xFFE50914),
                          size: 20,
                        ),
                      ),
                      onSubmitted: _executeSearch,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _executeSearch(_controller.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50914),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text(
                    'Search',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Provider filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildProviderChip('all', 'All', Icons.apps_rounded),
                  const SizedBox(width: 8),
                  _buildProviderChip(
                    'mlsbd',
                    'MLSBD',
                    Icons.movie_filter_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildProviderChip(
                    'hdhub4u',
                    'HDHub4u',
                    Icons.video_library_rounded,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Results
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE50914),
                      strokeWidth: 3,
                    ),
                  )
                : _results.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                        itemCount: _results.length,
                        itemBuilder: (context, idx) =>
                            _buildResultCard(_results[idx]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderChip(String id, String label, IconData icon) {
    final isSelected = _selectedProvider == id;
    return GestureDetector(
      onTap: () => _selectProvider(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE50914) : const Color(0xFF131720),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE50914)
                : const Color(0xFF202634),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : const Color(0xFF9EA3AE),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF9EA3AE),
                fontSize: 11.5,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF131720),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storage_rounded,
              size: 48,
              color: Color(0xFF7E8695),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _hasSearched
                ? 'No results found for "${_controller.text}"'
                : 'Search MLSBD & HDHub4u for dual-audio titles',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9EA3AE),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_hasSearched) ...[
            const SizedBox(height: 6),
            const Text(
              'Try another spelling, or pick one provider above.',
              style: TextStyle(color: Color(0xFF7E8695), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(ProviderListing listing) {
    final meta = <String>[];
    if (listing.year.isNotEmpty) meta.add(listing.year);
    meta.add(listing.mediaKind == 'tv' ? 'TV Series' : 'Movie');
    if (listing.qualities.isNotEmpty) {
      meta.add(listing.qualities.join(' • '));
    }
    final metaText = meta.join('  •  ') +
        (listing.sizes.isNotEmpty ? '\n${listing.sizes.join('  •  ')}' : '');
    return GestureDetector(
      onTap: () => _openListing(listing),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF131720),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF202634), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              listing.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _badge(listing.providerName, const Color(0xFFE50914)),
                if (listing.isDualAudio)
                  _badge(
                    'Dual Audio 🇮🇳',
                    const Color(0xFF00C853),
                    textColor: const Color(0xFF00E676),
                  )
                else if (listing.audioLabel.isNotEmpty)
                  _badge(
                    listing.audioLabel,
                    const Color(0xFF00C853),
                    textColor: const Color(0xFF00E676),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              metaText,
              style: const TextStyle(
                color: Color(0xFF9EA3AE),
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color, {Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
