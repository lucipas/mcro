import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcro/main.dart';
import 'package:mcro/models/micro_app.dart';
import 'package:mcro/screens/gallery_screen.dart';
import 'package:mcro/services/storage_service.dart';

/// In-memory storage so widget tests never touch the filesystem.
class _FakeStorage extends StorageService {
  final List<MicroApp> apps = [];

  @override
  Future<List<MicroApp>> loadAll() async => List<MicroApp>.of(apps);

  @override
  Future<void> save(MicroApp app) async {
    apps.removeWhere((element) => element.id == app.id);
    apps.add(app);
  }

  @override
  Future<void> delete(String id) async {
    apps.removeWhere((element) => element.id == id);
  }
}

void main() {
  testWidgets('McroApp shows the gallery empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GalleryScreen(storage: _FakeStorage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My micro-apps'), findsOneWidget);
    expect(find.text('No micro-apps yet'), findsOneWidget);
  });

  testWidgets('gallery lists saved micro-apps', (tester) async {
    final storage = _FakeStorage()
      ..apps.add(MicroApp.create(name: 'Counter'))
      ..apps.add(MicroApp.create(name: 'Clock'));

    await tester.pumpWidget(
      MaterialApp(
        home: GalleryScreen(storage: storage),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Counter'), findsOneWidget);
    expect(find.text('Clock'), findsOneWidget);
    expect(find.text('No micro-apps yet'), findsNothing);
  });

  testWidgets('create dialog builds a starter micro-app and opens the editor',
      (tester) async {
    final storage = _FakeStorage();

    await tester.pumpWidget(
      MaterialApp(
        home: GalleryScreen(storage: storage),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Counter');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // The editor is open...
    expect(find.text('Counter'), findsWidgets);
    expect(find.text('HTML'), findsOneWidget);
    // ...and the app was persisted with starter content.
    expect(storage.apps, hasLength(1));
    expect(storage.apps.first.js, contains('addEventListener'));
  });

  testWidgets('app widget builds without errors', (tester) async {
    // Injectable storage so the root widget never touches path_provider,
    // which does not resolve inside a widget test.
    await tester.pumpWidget(McroApp(storage: _FakeStorage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
