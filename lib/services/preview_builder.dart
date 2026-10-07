import '../models/micro_app.dart';
import 'bridge_js.dart';

/// Assembles a micro-app's HTML, CSS, and JS into one runnable document
/// that can be loaded into a WebView.
///
/// Every document also gets the micro-app bridge (`bridge_js.dart`)
/// injected into `<head>` so the page can call geolocation/SMS APIs.
String buildDocument({
  required String html,
  required String css,
  required String js,
}) {
  final styleTag = '<style>\n$css\n</style>';
  final scriptTag = '<script>\n$js\n</script>';
  final bridgeTag = '<script>\n$bridgeJs\n</script>';
  final lower = html.toLowerCase();

  // Plain fragment: wrap it in a full document.
  if (!lower.contains('<html')) {
    return '<!DOCTYPE html>\n'
        '<html lang="en">\n'
        '<head>\n'
        '<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1.0">\n'
        '$styleTag\n'
        '$bridgeTag\n'
        '</head>\n'
        '<body>\n'
        '$html\n'
        '$scriptTag\n'
        '</body>\n'
        '</html>';
  }

  // Full document: inject the style, bridge, and user script tags.
  var doc = html;
  doc = _insertBeforeClosingTag(doc, 'head', styleTag) ??
      _insertAfterOpeningTag(doc, 'head', styleTag) ??
      '$styleTag\n$doc';
  doc = _insertAfterOpeningTag(doc, 'head', bridgeTag) ??
      _insertBeforeClosingTag(doc, 'head', bridgeTag) ??
      _insertAfterOpeningTag(doc, 'html', bridgeTag) ??
      '$bridgeTag\n$doc';
  doc = _insertBeforeClosingTag(doc, 'body', scriptTag) ??
      _insertBeforeClosingTag(doc, 'html', scriptTag) ??
      '$doc\n$scriptTag';
  return doc;
}

/// Convenience wrapper for a [MicroApp].
String buildDocumentFor(MicroApp app) =>
    buildDocument(html: app.html, css: app.css, js: app.js);

/// Inserts [snippet] just before the first `</tag>` (case-insensitive).
/// Returns null when the closing tag is missing.
String? _insertBeforeClosingTag(String doc, String tag, String snippet) {
  final idx = doc.toLowerCase().indexOf('</$tag>');
  if (idx == -1) {
    return null;
  }
  return doc.substring(0, idx) + snippet + doc.substring(idx);
}

/// Inserts [snippet] just after the first `<tag ...>` opening tag
/// (case-insensitive, the tag name must end at a boundary so `<header>`
/// does not match `<head`). Returns null when the opening tag is missing.
String? _insertAfterOpeningTag(String doc, String tag, String snippet) {
  final lower = doc.toLowerCase();
  var searchFrom = 0;
  while (true) {
    final open = lower.indexOf('<$tag', searchFrom);
    if (open == -1) {
      return null;
    }
    final afterTag = open + tag.length + 1;
    if (afterTag < lower.length && _isTagBoundary(lower[afterTag])) {
      final close = lower.indexOf('>', open);
      if (close == -1) {
        return null;
      }
      return doc.substring(0, close + 1) + snippet + doc.substring(close + 1);
    }
    searchFrom = open + 1;
  }
}

bool _isTagBoundary(String char) => char == '>' || char == ' ' || char == '\t' || char == '\n' || char == '\r' || char == '/';
