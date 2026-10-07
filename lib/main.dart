import 'package:flutter/material.dart';

import 'screens/gallery_screen.dart';

void main() {
  runApp(const McroApp());
}

/// Root widget: a dark, code-editor-flavoured Material app.
class McroApp extends StatelessWidget {
  const McroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mcro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF82B1FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const GalleryScreen(),
    );
  }
}
