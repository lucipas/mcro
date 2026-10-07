import 'package:flutter/material.dart';

import '../models/micro_app.dart';
import '../services/storage_service.dart';
import 'editor_screen.dart';
import 'preview_screen.dart';

/// The home screen: every saved micro-app, plus create/open/delete.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, this.storage});

  /// Injectable for tests; defaults to real on-disk storage.
  final StorageService? storage;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late final StorageService _storage;
  late Future<List<MicroApp>> _appsFuture;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? StorageService();
    _appsFuture = _storage.loadAll();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _appsFuture = _storage.loadAll();
    });
  }

  Future<void> _createApp() async {
    _nameController.clear();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New micro-app'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          maxLength: 40,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_nameController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) {
      return;
    }
    final trimmed = name.trim();
    final app = MicroApp.withStarterTemplate(
      name: trimmed.isEmpty ? 'Untitled' : trimmed,
    );
    await _storage.save(app);
    if (!mounted) {
      return;
    }
    await _openEditor(app);
  }

  Future<void> _openEditor(MicroApp app) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(app: app, storage: _storage),
      ),
    );
    if (!mounted) {
      return;
    }
    _reload();
  }

  Future<void> _run(MicroApp app) => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PreviewScreen(app: app),
        ),
      );

  Future<bool> _confirmDelete(MicroApp app) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${app.name}"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _onMenuSelected(String action, MicroApp app) async {
    if (action == 'run') {
      await _run(app);
    } else if (action == 'duplicate') {
      await _storage.save(app.duplicate());
      if (!mounted) {
        return;
      }
      _reload();
    } else if (action == 'delete') {
      final confirmed = await _confirmDelete(app);
      if (!confirmed) {
        return;
      }
      await _storage.delete(app.id);
      if (!mounted) {
        return;
      }
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My micro-apps'),
      ),
      body: FutureBuilder<List<MicroApp>>(
        future: _appsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load micro-apps:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final apps = snapshot.data ?? <MicroApp>[];
          if (apps.isEmpty) {
            return _buildEmptyState();
          }
          return _buildList(apps);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createApp,
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.widgets_outlined, size: 64),
          const SizedBox(height: 12),
          const Text(
            'No micro-apps yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('Build a tiny app with HTML, CSS, and JS.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _createApp,
            icon: const Icon(Icons.add),
            label: const Text('Create your first micro-app'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<MicroApp> apps) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: apps.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final app = apps[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            onTap: () => _openEditor(app),
            title: Text(app.name),
            subtitle: Text(_relativeTime(app.updatedAt)),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _onMenuSelected(value, app),
              itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'run',
                    child: ListTile(
                      leading: Icon(Icons.play_arrow_rounded),
                      title: Text('Run'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    child: ListTile(
                      leading: Icon(Icons.copy_outlined),
                      title: Text('Duplicate'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
            ),
          ),
        );
      },
    );
  }

  static String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) {
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[time.month - 1]} ${time.day}, ${time.year}';
  }
}
