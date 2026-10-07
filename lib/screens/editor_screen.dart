import 'package:flutter/material.dart';

import '../models/micro_app.dart';
import '../services/storage_service.dart';
import 'preview_screen.dart';

/// The editor: one tab per language (HTML / CSS / JS) with live
/// save and a Run action that opens the WebView preview.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.app, required this.storage});

  final MicroApp app;
  final StorageService storage;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _html;
  late final TextEditingController _css;
  late final TextEditingController _js;
  late final TextEditingController _renameController;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _html = TextEditingController(text: widget.app.html);
    _css = TextEditingController(text: widget.app.css);
    _js = TextEditingController(text: widget.app.js);
    _renameController = TextEditingController();
    _html.addListener(_onChanged);
    _css.addListener(_onChanged);
    _js.addListener(_onChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _html.dispose();
    _css.dispose();
    _js.dispose();
    _renameController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!_dirty) {
      setState(() {
        _dirty = true;
      });
    }
  }

  void _syncFromControllers() {
    widget.app.html = _html.text;
    widget.app.css = _css.text;
    widget.app.js = _js.text;
  }

  Future<void> _save({bool showSnackBar = false}) async {
    _syncFromControllers();
    await widget.storage.save(widget.app);
    if (!mounted) {
      return;
    }
    setState(() {
      _dirty = false;
    });
    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
    }
  }

  Future<void> _run() async {
    _syncFromControllers();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PreviewScreen(app: widget.app),
      ),
    );
  }

  Future<void> _rename() async {
    _renameController.text = widget.app.name;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename micro-app'),
        content: TextField(
          controller: _renameController,
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
            onPressed: () => Navigator.of(ctx).pop(_renameController.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) {
      return;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    setState(() {
      widget.app.name = trimmed;
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _save();
        if (!context.mounted) {
          return;
        }
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: InkWell(
            onTap: _rename,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.app.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit_outlined, size: 16),
              ],
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'HTML'),
              Tab(text: 'CSS'),
              Tab(text: 'JS'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Save',
              onPressed:
                  _dirty ? () => _save(showSnackBar: true) : null,
              icon: const Icon(Icons.save_outlined),
            ),
            IconButton(
              tooltip: 'Run',
              onPressed: _run,
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _codeArea(_html, 'HTML markup'),
            _codeArea(_css, 'CSS rules'),
            _codeArea(_js, 'JavaScript code'),
          ],
        ),
      ),
    );
  }

  Widget _codeArea(TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: TextField(
        controller: controller,
        expands: true,
        minLines: null,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontFamily: 'monospace'),
          filled: true,
          fillColor: const Color(0xFF16161C),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
