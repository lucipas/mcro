import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/micro_app.dart';

/// Stores micro-apps as one JSON file per app in the app documents
/// directory (`micro_apps/<id>.json`).
class StorageService {
  Future<Directory> _appsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}micro_apps');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Loads every saved micro-app, most recently updated first.
  /// Corrupt files are skipped instead of failing the whole load.
  Future<List<MicroApp>> loadAll() async {
    final dir = await _appsDir();
    final apps = <MicroApp>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) {
        continue;
      }
      try {
        final content = await entity.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          apps.add(MicroApp.fromJson(decoded));
        }
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    apps.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return apps;
  }

  /// Saves [app], creating or overwriting its file.
  Future<void> save(MicroApp app) async {
    app.updatedAt = DateTime.now();
    final dir = await _appsDir();
    final file = File('${dir.path}${Platform.pathSeparator}${app.id}.json');
    await file.writeAsString(jsonEncode(app.toJson()), flush: true);
  }

  /// Deletes the micro-app with [id], if it exists.
  Future<void> delete(String id) async {
    final dir = await _appsDir();
    final file = File('${dir.path}${Platform.pathSeparator}$id.json');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
