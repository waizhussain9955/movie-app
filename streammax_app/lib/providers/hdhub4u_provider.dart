import 'package:http/http.dart' as http;

import 'provider.dart';

/// HDHub4u (hdhubinfo.com) — WordPress download index ("HDHub4u Official"
/// 2026 catalog) with a rich Hindi dual-audio catalogue (Hindi Dubbed
/// Movies, South Hindi Dubbed, Dual Audio Packs categories).
///
/// v2 SEARCH (sitemap): hdhubinfo.com/?s=<query> IGNORES the query and
/// always returns the same Latest Releases list (~10 items), so the v1
/// provider could never find old titles (Game of Thrones returned []).
/// The site DOES publish a sitemap index (verified 2026-11-14 via curl):
///   https://hdhubinfo.com/sitemap.xml
///     -> sitemap-posts-1.xml (5,002 URLs) + sitemap-posts-2.xml (5,000)
///        + sitemap-posts-3.xml (4,396) = ~14,400 post URLs, ~2.3MB.
/// [search] now matches the query against those post-URL slugs
/// (client-side) and builds listings from the slugs. The sitemap list is
/// cached in memory for 60 minutes and one in-flight fetch is shared by
/// concurrent searches, so the ~2.3MB is never downloaded twice at once.
/// If the sitemap fetch fails, search falls back to the old ?s= + JSON-LD
/// Latest list path.
///
/// Post page DOWNLOAD LINKS (verified 2026-11-14 via curl):
///   <a ... href="https://hubcdn.club/file/...">480p⚡[730MB]</a>
///   <a ... href="https://hblinks.lol/archives/122613">720p x264 [1.8GB]</a>
///   <a ... href="https://hubdrive.blog/file/2050972273">1080p MULTi WEB-DL [9GB]</a>
///   <a ... href="https://4khdhub.one/avengers-endgame-encore-movie-8563/">4K | SDR | HDR | DV | REMUX</a>
///   <a ... href="https://playdrive.vip/e/AQA_ZawAAqKnhg"><span>WATCH Online</span></a>
///   <a ... href="https://hdstream4u.com/file/0yrm059janih"><span>PLAYER-2</span></a>
///
/// No direct .m3u8 / .mp4 is exposed anywhere; no public API.
class HdHub4uProvider implements ContentProvider {
  @override
  String get id => 'hdhub4u';

  @override
  String get name => 'HDHub4u';

  static const _base = 'https://hdhubinfo.com';

  static const _headers = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  static const _downloadHosts = <String>[
    'hubcdn.club',
    'hubdrive.blog',
    'hblinks.lol',
    '4khdhub.one',
  ];

  static const _watchHosts = <String>[
    'playdrive.vip',
    'hdstream4u.com',
  ];

  /// Sitemap index (verified 2026-11-14): lists sitemap-posts-1/2/3.xml
  /// (~14,400 post URLs) + sitemap-categories.xml.
  static const _sitemapIndex = 'https://hdhubinfo.com/sitemap.xml';

  /// In-memory cache of all post URLs from the sitemaps, 60-minute TTL.
  /// One in-flight fetch is shared by concurrent searches.
  static List<String>? _cachedPostUrls;
  static DateTime? _cacheFetchedAt;
  static Future<List<String>>? _inFlightFetch;
  static const _cacheTtl = Duration(minutes: 60);

  /// Warms the sitemap cache in the background (fire-and-forget). Call it
  /// when the provider screen opens so the first search usually hits a
  /// warm cache instead of downloading ~2.3MB of sitemaps on demand.
  static void warmUp() {
    _getPostUrls().catchError((_) => <String>[]);
  }

  static Future<List<String>> _getPostUrls() async {
    final now = DateTime.now();
    if (_cachedPostUrls != null &&
        _cacheFetchedAt != null &&
        now.difference(_cacheFetchedAt!) < _cacheTtl) {
      return _cachedPostUrls!;
    }
    _inFlightFetch ??= _fetchPostUrls();
    try {
      final urls = await _inFlightFetch!;
      _cachedPostUrls = urls;
      _cacheFetchedAt = DateTime.now();
      return urls;
    } finally {
      _inFlightFetch = null;
    }
  }

  /// Reads the sitemap list from the index (do NOT hardcode 1/2/3),
  /// downloads every post sitemap in parallel and returns all <loc> URLs.
  static Future<List<String>> _fetchPostUrls() async {
    final indexRes = await http
        .get(Uri.parse(_sitemapIndex), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (indexRes.statusCode != 200) return <String>[];
    final sitemapUrls = RegExp(
      r'<loc>(https://hdhubinfo\.com/sitemap-posts[^<]*\.xml)</loc>',
    ).allMatches(indexRes.body).map((m) => m.group(1)!).toList();
    if (sitemapUrls.isEmpty) return <String>[];
    final bodies = await Future.wait(
      sitemapUrls.map((u) => http
          .get(Uri.parse(u), headers: _headers)
          .timeout(const Duration(seconds: 20))
          .then((r) => r.statusCode == 200 ? r.body : '')
          .catchError((_) => '')),
    );
    final urls = <String>{};
    final locRe = RegExp(r'<loc>(https://hdhubinfo\.com/[^<]+)</loc>');
    for (final body in bodies) {
      for (final m in locRe.allMatches(body)) {
        urls.add(m.group(1)!);
      }
    }
    return urls.toList();
  }

  @override
  Future<List<ProviderListing>> search(String query) async {
    final words = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return [];
    // Primary path: match the query against every post-URL slug in the
    // sitemap. This finds old titles (e.g. Game of Thrones) that the
    // Latest Releases list never shows.
    try {
      final urls = await _getPostUrls().timeout(const Duration(seconds: 45));
      if (urls.isNotEmpty) {
        final results = _searchSlugs(urls, words);
        if (results.isNotEmpty) return results;
        // No sitemap hit — fall through to the legacy Latest list, which
        // can still catch a brand-new post the sitemap does not list yet.
      }
    } catch (_) {}
    return _searchLegacy(query);
  }

  /// Matches ALL query words against each post slug (hyphens = spaces)
  /// and builds a listing from the slug. Caps at 30 results.
  List<ProviderListing> _searchSlugs(List<String> urls, List<String> words) {
    final results = <ProviderListing>[];
    for (final url in urls) {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.pathSegments.isEmpty) continue;
      final slug = uri.pathSegments.last;
      final hay = slug.toLowerCase().replaceAll('-', ' ');
      if (!words.every((w) => hay.contains(w))) continue;
      results.add(ProviderListing.fromSlug(
        slug: slug,
        postUrl: url,
        providerId: id,
        providerName: name,
      ));
      if (results.length >= 30) break;
    }
    return results;
  }

  /// Legacy path (v1): the ?s= page ignores the query and returns the
  /// Latest Releases list; parse it (JSON-LD ItemList, aria-label
  /// anchors as fallback) and filter client-side. Only used when the
  /// sitemap fetch fails or finds nothing.
  Future<List<ProviderListing>> _searchLegacy(String query) async {
    try {
      final url =
          Uri.parse('$_base/?s=${Uri.encodeQueryComponent(query.trim())}');
      final res = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final all = _parseSearchPage(res.body);
      final words = query
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (words.isEmpty) return all;
      return all.where((l) {
        final title = l.title.toLowerCase();
        return words.every((w) => title.contains(w));
      }).toList();
    } catch (_) {
      return [];
    }
  }

  List<ProviderListing> _parseSearchPage(String html) {
    final results = <ProviderListing>[];
    final seen = <String>{};

    // 1) JSON-LD ItemList — the most reliable source (url + name pairs).
    final ldRe =
        RegExp(r'"url":"(https://hdhubinfo\.com/[^"]+)","name":"([^"]+)"');
    for (final m in ldRe.allMatches(html)) {
      final href = m.group(1)!;
      final title = stripHtmlTags(m.group(2)!);
      if (title.isEmpty || !seen.add(href)) continue;
      results.add(ProviderListing.fromTitle(
        title: title,
        postUrl: href,
        providerId: id,
        providerName: name,
      ));
    }

    // 2) Fallback: listing anchors carrying the title in aria-label.
    if (results.isEmpty) {
      final anchorRe = RegExp(
        r'<a\s+href="(/[^"]+)"[^>]*aria-label="([^"]+)"',
        dotAll: true,
      );
      for (final m in anchorRe.allMatches(html)) {
        final href = '$_base${m.group(1)!}';
        final title = stripHtmlTags(m.group(2)!);
        if (title.isEmpty || !seen.add(href)) continue;
        results.add(ProviderListing.fromTitle(
          title: title,
          postUrl: href,
          providerId: id,
          providerName: name,
        ));
      }
    }
    return results;
  }

  @override
  Future<List<ProviderLink>> fetchLinks(ProviderListing listing) async {
    try {
      final res = await http
          .get(Uri.parse(listing.postUrl), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return _fallback(listing);
      final links = _parsePostPage(res.body);
      return links.isEmpty ? _fallback(listing) : links;
    } catch (_) {
      return _fallback(listing);
    }
  }

  /// Download anchors point at the four file hosts; WATCH Online / PLAYER-2
  /// anchors point at the two third-party players. Labels come from the
  /// anchor text ("480p⚡[730MB]", "720p x264 [1.8GB]", "WATCH Online", …).
  List<ProviderLink> _parsePostPage(String html) {
    final links = <ProviderLink>[];
    final seen = <String>{};
    final anchorRe = RegExp(
      r'<a[^>]+href="(https?://[^"]+)"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    for (final m in anchorRe.allMatches(html)) {
      final href = m.group(1)!;
      final label = stripHtmlTags(m.group(2)!);
      // Skip bare-homepage links (e.g. the "4K Movies" nav link to
      // https://4khdhub.one) — real file links always carry a path.
      final uri = Uri.tryParse(href);
      if (uri == null || uri.path.isEmpty || uri.path == '/') continue;
      final host = uri.host.toLowerCase();
      if (_isHost(host, _downloadHosts)) {
        if (seen.add(href)) {
          links.add(ProviderLink(
            label: label.isEmpty ? 'Download' : label,
            url: href,
            kind: 'download',
          ));
        }
      } else if (_isHost(host, _watchHosts)) {
        if (seen.add(href)) {
          links.add(ProviderLink(
            label: label.isEmpty ? 'Watch Online' : label,
            url: href,
            kind: 'watch',
          ));
        }
      }
    }
    return links;
  }

  bool _isHost(String host, List<String> allowed) {
    for (final h in allowed) {
      if (host == h || host.endsWith('.$h')) return true;
    }
    return false;
  }

  /// Last resort so the user can always open the post itself in the player.
  List<ProviderLink> _fallback(ProviderListing listing) {
    return [
      ProviderLink(
        label: 'Open post page',
        url: listing.postUrl,
        kind: 'download',
      ),
    ];
  }
}
