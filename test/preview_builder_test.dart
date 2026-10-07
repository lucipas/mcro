import 'package:flutter_test/flutter_test.dart';
import 'package:mcro/services/preview_builder.dart';

void main() {
  group('buildDocument', () {
    test('wraps a plain fragment in a full document', () {
      final doc = buildDocument(
        html: '<h1>Hi</h1>',
        css: 'h1 { color: red; }',
        js: 'console.log(1);',
      );

      expect(doc, contains('<!DOCTYPE html>'));
      expect(doc, contains('name="viewport"'));
      expect(doc, contains('<h1>Hi</h1>'));
      expect(doc, contains('McroBridge'));
      expect(doc.indexOf('McroBridge'), lessThan(doc.indexOf('</head>')));

      final styleAt = doc.indexOf('<style>');
      final headCloseAt = doc.indexOf('</head>');
      final scriptAt = doc.indexOf('<script>');
      final bodyCloseAt = doc.indexOf('</body>');
      expect(styleAt, inInclusiveRange(0, headCloseAt));
      expect(scriptAt, inInclusiveRange(0, bodyCloseAt));
      expect(doc.indexOf('h1 { color: red; }'), greaterThan(styleAt));
      expect(doc.indexOf('h1 { color: red; }'), lessThan(headCloseAt));
      expect(doc.indexOf('console.log(1);'), greaterThan(scriptAt));
      expect(doc.indexOf('console.log(1);'), lessThan(bodyCloseAt));
    });

    test('injects into an existing full document', () {
      final doc = buildDocument(
        html: '<html><head><title>t</title></head>'
            '<body><p>x</p></body></html>',
        css: 'p {}',
        js: 'run();',
      );

      expect(doc.indexOf('p {}'), lessThan(doc.indexOf('</head>')));
      expect(doc.indexOf('p {}'), greaterThan(doc.indexOf('<title>')));
      expect(doc.indexOf('run();'), lessThan(doc.indexOf('</body>')));
      expect(doc.indexOf('run();'), greaterThan(doc.indexOf('<p>')));
    });

    test('handles uppercase tags', () {
      final doc = buildDocument(
        html: '<HTML><HEAD><TITLE>t</TITLE></HEAD>'
            '<BODY><P>x</P></BODY></HTML>',
        css: 'P {}',
        js: 'go();',
      );

      final lower = doc.toLowerCase();
      expect(lower.indexOf('p {}'), lessThan(lower.indexOf('</head>')));
      expect(lower.indexOf('go();'), lessThan(lower.indexOf('</body>')));
    });

    test('does not match <header> when inserting into <head>', () {
      final doc = buildDocument(
        html: '<html><body><header>nav</header><p>x</p></body></html>',
        css: 'p {}',
        js: '',
      );

      // The style tag must still land inside a head context (prepended
      // before the document) rather than inside the <header> element.
      expect(doc.indexOf('<style>'), lessThan(doc.indexOf('<html>')));
      expect(doc.indexOf('<style>'), 0);
    });

    test('injects the micro-app bridge before user code', () {
      final fragment = buildDocument(html: '<p>hi</p>', css: '', js: 'start();');
      expect(fragment.indexOf('McroBridge'), lessThan(fragment.indexOf('start();')));
      expect(fragment.indexOf('McroBridge'), lessThan(fragment.indexOf('</head>')));

      final full = buildDocument(
        html: '<html><body><p>x</p></body></html>',
        css: '',
        js: 'go();',
      );
      // No <head> here; the bridge still lands between <html> and <body>.
      expect(full.indexOf('McroBridge'), greaterThan(full.indexOf('<html>')));
      expect(full.indexOf('McroBridge'), lessThan(full.indexOf('<body>')));
      expect(full.indexOf('McroBridge'), lessThan(full.indexOf('go();')));
    });

    test('keeps empty sections', () {
      final doc = buildDocument(html: '', css: '', js: '');
      expect(doc, contains('<style>'));
      expect(doc, contains('<script>'));
      expect(doc, contains('</html>'));
    });
  });
}
