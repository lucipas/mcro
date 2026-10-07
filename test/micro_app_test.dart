import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcro/models/micro_app.dart';

void main() {
  group('MicroApp', () {
    test('json round-trip preserves all fields', () {
      final app = MicroApp.withStarterTemplate(name: 'My app');
      final restored = MicroApp.fromJson(
        jsonDecode(jsonEncode(app.toJson())) as Map<String, dynamic>,
      );

      expect(restored.id, app.id);
      expect(restored.name, 'My app');
      expect(restored.html, app.html);
      expect(restored.css, app.css);
      expect(restored.js, app.js);
      expect(restored.createdAt, app.createdAt);
      expect(restored.updatedAt, app.updatedAt);
    });

    test('create produces unique ids', () {
      final a = MicroApp.create(name: 'a');
      final b = MicroApp.create(name: 'b');
      expect(a.id, isNot(b.id));
      expect(a.id, isNotEmpty);
    });

    test('duplicate gets a new id and a copy suffix', () {
      final app = MicroApp.create(name: 'Widget')
        ..html = '<p>hi</p>'
        ..css = 'p {}'
        ..js = 'go();';
      final copy = app.duplicate();

      expect(copy.id, isNot(app.id));
      expect(copy.name, 'Widget (copy)');
      expect(copy.html, '<p>hi</p>');
      expect(copy.css, 'p {}');
      expect(copy.js, 'go();');
    });

    test('fromJson tolerates missing optional fields', () {
      final app = MicroApp.fromJson(<String, dynamic>{
        'id': 'x',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      expect(app.name, 'Untitled');
      expect(app.html, '');
      expect(app.css, '');
      expect(app.js, '');
    });
  });
}
