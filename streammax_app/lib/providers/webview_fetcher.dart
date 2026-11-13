import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Fetches a page's HTML through a hidden WebView (real browser engine).
///
/// Plain HTTP clients get blocked by Cloudflare's managed challenge on
/// some provider sites (MLSBD returns HTTP 403 "Just a moment..."),
/// while a real browser passes it. This helper drives a
/// [WebViewController] owned by the UI: the UI mounts [widget] (a 1x1
/// WebView that is never shown) and passes [fetchHtml] to the providers
/// that need it (see [ContentProvider.webViewFetch]).
///
/// Only ONE fetch runs at a time; concurrent callers wait their turn.
/// Never throws — returns null on any failure or timeout.
///
/// NOTE: [loadRequest] needs the widget to be mounted first. The UI
/// mounts the widget when the provider screen opens, so the very first
/// fetch (within ~1s of opening the screen) can return null if the
/// platform view is not attached yet — retrying the search works.
class WebViewFetcher {
  WebViewFetcher() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            final c = _pageFinished;
            if (c != null && !c.isCompleted) c.complete();
          },
        ),
      );
  }

  late final WebViewController _controller;
  Completer<void>? _pageFinished;
  bool _busy = false;

  /// The (hidden) widget the UI must mount for the controller to work.
  /// Mount it as a 1x1 box; the page itself is never shown.
  Widget get widget => WebViewWidget(controller: _controller);

  /// Loads [url] in the hidden WebView and returns the rendered page HTML
  /// (document.documentElement.outerHTML), or null on failure/timeout.
  /// [siteMarker] is a lower-case string that must appear in the page
  /// (e.g. 'mlsbd') — used to tell the real page apart from a challenge
  /// or error page. [timeout] caps the whole fetch (default 15s: the
  /// Cloudflare challenge itself can take a few seconds).
  Future<String?> fetchHtml(
    String url, {
    String siteMarker = '',
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    // Serialize: only one fetch at a time.
    while (_busy) {
      if (DateTime.now().isAfter(deadline)) return null;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    _busy = true;
    try {
      // Give the mounted widget a moment to attach the platform view.
      await Future.delayed(const Duration(milliseconds: 500));
      _pageFinished = Completer<void>();
      await _controller.loadRequest(Uri.parse(url));
      try {
        await _pageFinished!.future.timeout(const Duration(seconds: 10));
      } catch (_) {
        // Page never signalled finished — keep polling the DOM anyway.
      }
      final marker = siteMarker.toLowerCase();
      while (DateTime.now().isBefore(deadline)) {
        String? html;
        try {
          final result = await _controller.runJavaScriptReturningResult(
            'document.documentElement.outerHTML',
          );
          if (result is String) html = result;
        } catch (_) {}
        if (html != null && html.length > 500) {
          final lower = html.toLowerCase();
          final challenged = lower.contains('just a moment') ||
              lower.contains('cf-challenge') ||
              lower.contains('attention required') ||
              lower.contains('checking your browser');
          if (!challenged &&
              (marker.isEmpty || lower.contains(marker))) {
            return html;
          }
        }
        await Future.delayed(const Duration(seconds: 1));
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      _busy = false;
    }
  }
}
