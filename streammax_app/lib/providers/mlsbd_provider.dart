import 'package:http/http.dart' as http;

import 'provider.dart';

/// MLSBD (mlsbd.co) — WordPress download index with the best dual-audio
/// coverage found so far (Game of Thrones, Stranger Things, Avengers and
/// Money Heist all complete in Dual Audio [Hindi-English]).
///
/// Search page format (verified 2026-11-14 via text fetch):
///   https://mlsbd.co/?s=game+of+thrones
///   -> "You searched for game of thrones » MLSBD" with post headings like
///   "Game of Thrones (2019) S08 Dual Audio [Hindi-English] Blu-Ray –
///    480P | 720P | 1080P – x264 – 1.4GB | 3GB | 7.4GB ESub –
///    Download & Watch Online"
///
/// Post pages route ALL download links through savelinks.me.
///
/// KNOWN LIMIT (verified from this VM, 2026-11-14): mlsbd.co sits behind a
/// Cloudflare "Just a moment..." managed challenge. Plain HTTP clients
/// (curl, and therefore http.get from the app) get HTTP 403 with the
/// challenge page, while a real browser passes it. So [search] may return []
/// on networks where Cloudflare challenges the app's requests — the parser
/// below is written against the verified title format and standard
/// WordPress anchor markup, but it has NOT been run against live MLSBD HTML
/// from this VM. If MLSBD stays blocked, open the post URL in the WebView
/// player instead (it runs a real browser engine and can pass the check).
class MlsbdProvider implements ContentProvider {
  @override
  String get id => 'mlsbd';

  @override
  String get name => 'MLSBD';

  static const _base = 'https://mlsbd.co';

  static const _headers = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  @override
  Future<List<ProviderListing>> search(String query) async {
    try {
      final url =
          Uri.parse('$_base/?s=${Uri.encodeQueryComponent(query.trim())}');
      final res = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      return _parseSearchPage(res.body);
    } catch (_) {
      return [];
    }
  }

  /// Post titles sit in headings that link to the post page. Keep only
  /// anchors whose text carries a year in parens AND mentions Dual Audio
  /// or Hindi — that is exactly the dual-audio catalogue this feature is for.
  List<ProviderListing> _parseSearchPage(String html) {
    final results = <ProviderListing>[];
    final seen = <String>{};
    final anchorRe = RegExp(
      // Absolute (https://mlsbd.co/slug/) or root-relative (/slug/) post links.
      r'<a[^>]+href="((?:https://mlsbd\.co)?/[^"]+)"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    for (final m in anchorRe.allMatches(html)) {
      final rawHref = m.group(1)!;
      final href =
          rawHref.startsWith('http') ? rawHref : '$_base$rawHref';
      final text = stripHtmlTags(m.group(2)!);
      if (text.isEmpty) continue;
      if (!RegExp(r'\(\d{4}').hasMatch(text)) continue;
      final lower = text.toLowerCase();
      if (!lower.contains('dual audio') && !lower.contains('hindi')) {
        continue;
      }
      if (!seen.add(href)) continue;
      results.add(ProviderListing.fromTitle(
        title: text,
        postUrl: href,
        providerId: id,
        providerName: name,
      ));
      if (results.length >= 30) break;
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

  /// Download links go through savelinks.me; "Watch Online" buttons are
  /// kept as watch links. Everything else on the page is ignored.
  List<ProviderLink> _parsePostPage(String html) {
    final links = <ProviderLink>[];
    final seen = <String>{};
    final anchorRe = RegExp(
      r'<a[^>]+href="(https?://[^"]+)"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    for (final m in anchorRe.allMatches(html)) {
      final href = m.group(1)!;
      final text = stripHtmlTags(m.group(2)!);
      final lowerText = text.toLowerCase();
      if (href.contains('savelinks')) {
        if (seen.add(href)) {
          links.add(ProviderLink(
            label: text.isEmpty ? 'Download' : text,
            url: href,
            kind: 'download',
          ));
        }
      } else if (lowerText.contains('watch online') ||
          lowerText.contains('watch')) {
        if (seen.add(href)) {
          links.add(ProviderLink(
            label: text.isEmpty ? 'Watch Online' : text,
            url: href,
            kind: 'watch',
          ));
        }
      }
    }
    return links;
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
