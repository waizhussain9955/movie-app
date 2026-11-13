import 'dart:async';

import 'hdhub4u_provider.dart';
import 'mlsbd_provider.dart';

/// One title found on a provider site (MLSBD / HDHub4u).
///
/// All fields are derived from the listing title text — neither site exposes
/// a structured API, so the providers scrape raw HTML and parse the title.
class ProviderListing {
  final String title;
  final String postUrl;
  final String providerId;
  final String providerName;
  final String audioLabel; // e.g. 'Dual Audio [Hindi-English]'
  final List<String> qualities; // e.g. ['480p', '720p', '1080p']
  final List<String> sizes; // e.g. ['1.4GB', '3GB', '7.4GB']
  final String year;
  final bool isDualAudio;
  final String mediaKind; // 'movie' | 'tv' | 'unknown'

  const ProviderListing({
    required this.title,
    required this.postUrl,
    required this.providerId,
    required this.providerName,
    this.audioLabel = '',
    this.qualities = const [],
    this.sizes = const [],
    this.year = '',
    this.isDualAudio = false,
    this.mediaKind = 'unknown',
  });

  /// Builds a listing by parsing a raw post title such as:
  /// "Game of Thrones (2019) S08 Dual Audio [Hindi-English] Blu-Ray –
  ///  480P | 720P | 1080P – x264 – 1.4GB | 3GB | 7.4GB ESub".
  factory ProviderListing.fromTitle({
    required String title,
    required String postUrl,
    required String providerId,
    required String providerName,
  }) {
    final clean = decodeHtmlEntities(title).trim();

    final yearMatch = RegExp(r'\((\d{4})').firstMatch(clean);
    final year = yearMatch?.group(1) ?? '';

    final qualities = <String>[];
    for (final m in RegExp(r'\b(480p|720p|1080p|2160p|4K)\b', caseSensitive: false)
        .allMatches(clean)) {
      final raw = m.group(1)!.toLowerCase();
      final norm = (raw == '2160p' || raw == '4k') ? '4K' : raw;
      if (!qualities.contains(norm)) qualities.add(norm);
    }

    final sizes = <String>[];
    for (final m in RegExp(r'(\d+(?:\.\d+)?)\s?(GB|MB)', caseSensitive: false)
        .allMatches(clean)) {
      final size = '${m.group(1)}${m.group(2)!.toUpperCase()}';
      if (!sizes.contains(size)) sizes.add(size);
    }

    String audioLabel = '';
    bool isDualAudio = false;
    final dualMatch = RegExp(r'Dual Audio\s*\[[^\]]+\]', caseSensitive: false)
        .firstMatch(clean);
    if (dualMatch != null) {
      audioLabel = dualMatch.group(0)!;
      isDualAudio = true;
    } else if (clean.toLowerCase().contains('dual audio')) {
      audioLabel = 'Dual Audio';
      isDualAudio = true;
    } else if (clean.toLowerCase().contains('hindi dubbed')) {
      audioLabel = 'Hindi Dubbed';
    } else if (clean.toLowerCase().contains('hindi')) {
      audioLabel = 'Hindi';
    }

    String mediaKind = 'movie';
    if (RegExp(r'\bS\d{1,2}\b', caseSensitive: false).hasMatch(clean) ||
        clean.toLowerCase().contains('season') ||
        clean.toLowerCase().contains('episode')) {
      mediaKind = 'tv';
    }

    return ProviderListing(
      title: clean,
      postUrl: postUrl,
      providerId: providerId,
      providerName: providerName,
      audioLabel: audioLabel,
      qualities: qualities,
      sizes: sizes,
      year: year,
      isDualAudio: isDualAudio,
      mediaKind: mediaKind,
    );
  }
}

/// A watch / download link extracted from a provider post page.
class ProviderLink {
  final String label;
  final String url;
  final String kind; // 'watch' | 'download'

  const ProviderLink({
    required this.label,
    required this.url,
    required this.kind,
  });
}

/// Contract every content provider must implement.
///
/// Implementations must never throw: return [] (search) or a fallback link
/// (fetchLinks) on any network / parse failure.
abstract class ContentProvider {
  String get id;
  String get name;

  Future<List<ProviderListing>> search(String query);
  Future<List<ProviderLink>> fetchLinks(ProviderListing listing);
}

/// Registry of all providers. To add a new provider:
///   1. Create a class implementing [ContentProvider].
///   2. Add one instance to [all] below. Nothing else changes.
class ProviderRegistry {
  static final List<ContentProvider> all = [
    MlsbdProvider(),
    HdHub4uProvider(),
  ];

  static ContentProvider? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Searches every provider in parallel. Each provider gets a 10s timeout
  /// and any per-provider error degrades to an empty list, so one dead
  /// provider never breaks the whole search. Results are merged and
  /// deduped by post URL.
  static Future<List<ProviderListing>> searchAll(String query) async {
    final results = await Future.wait(
      all.map((p) => p
          .search(query)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => <ProviderListing>[],
          )
          .catchError((_) => <ProviderListing>[])),
    );
    final merged = <ProviderListing>[];
    final seen = <String>{};
    for (final list in results) {
      for (final item in list) {
        if (seen.add(item.postUrl)) merged.add(item);
      }
    }
    return merged;
  }
}

/// Decodes the HTML entities that appear in scraped titles
/// (&amp; &#038; &quot; &#8211; …). Numeric entities are decoded first so
/// that a literal "&amp;" in the source does not double-decode.
String decodeHtmlEntities(String input) {
  var s = input;
  s = s.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (m) => String.fromCharCode(int.tryParse(m.group(1)!) ?? 0),
  );
  const named = <String, String>{
    '&amp;': '&',
    '&quot;': '"',
    '&apos;': "'",
    '&lt;': '<',
    '&gt;': '>',
    '&nbsp;': ' ',
  };
  named.forEach((k, v) => s = s.replaceAll(k, v));
  return s;
}

/// Strips HTML tags from scraped anchor text and collapses whitespace.
String stripHtmlTags(String input) {
  final noTags = input.replaceAll(RegExp(r'<[^>]*>'), ' ');
  return decodeHtmlEntities(noTags).replaceAll(RegExp(r'\s+'), ' ').trim();
}
