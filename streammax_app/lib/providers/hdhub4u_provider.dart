import 'package:http/http.dart' as http;

import 'provider.dart';

/// HDHub4u (hdhubinfo.com) — WordPress download index ("HDHub4u Official"
/// 2026 catalog) with a rich Hindi dual-audio catalogue (Hindi Dubbed
/// Movies, South Hindi Dubbed, Dual Audio Packs categories).
///
/// Search page format (verified 2026-11-14 via curl):
///   https://hdhubinfo.com/?s=avengers  -> HTTP 200, ~89KB
///   BUT the site IGNORES the ?s= query and always returns the same
///   Latest Releases list as the homepage. So [search] fetches that list
///   and filters it CLIENT-SIDE (see below).
///
/// The list is available twice in the HTML:
///   1. JSON-LD ItemList: {"@type":"ListItem","position":3,
///      "url":"https://hdhubinfo.com/avengers-endgame-encore-2026-imax-webrip-hindi-full-movie/",
///      "name":"Avengers Endgame: Encore (2026) iMAX WEB-DL [Hindi (DD5.1)
///      & English] 4K 1080p 720p & 480p Dual Audio [x264/10Bit-HEVC] |
///      Full Movie"}  (10 items — primary parse target)
///   2. Listing anchors: <a href="/avengers-endgame-encore-2026-imax-webrip-hindi-full-movie/"
///      aria-label="Avengers Endgame: Encore (2026) iMAX WEB-DL ..."> (fallback)
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

  @override
  Future<List<ProviderListing>> search(String query) async {
    try {
      final url =
          Uri.parse('$_base/?s=${Uri.encodeQueryComponent(query.trim())}');
      final res = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final all = _parseSearchPage(res.body);
      // The site ignores ?s=, so filter the Latest Releases list here:
      // keep only titles containing ALL query words (case-insensitive).
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
