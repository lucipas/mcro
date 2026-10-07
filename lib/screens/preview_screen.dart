import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/micro_app.dart';
import '../services/micro_app_bridge.dart';
import '../services/preview_builder.dart';

/// Full-screen "run" view: the micro-app rendered in a WebView with
/// floating close/reload controls and the geolocation/SMS bridge.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.app});

  final MicroApp app;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final WebViewController _controller;
  late final MicroAppBridge _bridge;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF121212));
    _bridge = MicroAppBridge(
      runJavaScript: (javascript) async {
        try {
          await _controller.runJavaScript(javascript);
        } catch (_) {
          // The page may already be gone; there is nothing to complete.
        }
      },
    );
    _bridge.attachTo(_controller);
    _controller.loadHtmlString(buildDocumentFor(widget.app));
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          Positioned.fill(
            child: WebViewWidget(controller: _controller),
          ),
          Positioned(
            top: topPad + 8,
            left: 12,
            child: _roundButton(
              tooltip: 'Close',
              icon: Icons.close,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            top: topPad + 8,
            right: 12,
            child: _roundButton(
              tooltip: 'Reload',
              icon: Icons.refresh,
              onTap: () => _controller.reload(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0x8C000000),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        color: Colors.white,
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
  }
}
