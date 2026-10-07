import 'dart:math';

/// A micro-app: a tiny program made of HTML, CSS, and JavaScript.
class MicroApp {
  MicroApp({
    required this.id,
    required this.name,
    required this.html,
    required this.css,
    required this.js,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  String name;
  String html;
  String css;
  String js;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Creates an empty micro-app with a fresh id.
  factory MicroApp.create({required String name}) {
    final now = DateTime.now();
    return MicroApp(
      id: _newId(now),
      name: name,
      html: '',
      css: '',
      js: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Creates a micro-app seeded with a small working example.
  factory MicroApp.withStarterTemplate({required String name}) {
    final app = MicroApp.create(name: name);
    app.html = '''
<div class="card">
  <h1>Hello 👋</h1>
  <p id="msg">Tap the button below.</p>
  <button id="btn">Tap me</button>
</div>
''';
    app.css = '''
* { box-sizing: border-box; }

body {
  margin: 0;
  min-height: 100vh;
  display: grid;
  place-items: center;
  font-family: system-ui, sans-serif;
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: #222;
}

.card {
  background: #fff;
  padding: 32px;
  border-radius: 16px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.25);
  text-align: center;
  width: min(80vw, 320px);
}

button {
  border: 0;
  border-radius: 999px;
  padding: 12px 24px;
  font-size: 16px;
  background: #222;
  color: #fff;
  cursor: pointer;
}
''';
    app.js = '''
let count = 0;
const msg = document.getElementById('msg');
document.getElementById('btn').addEventListener('click', function () {
  count += 1;
  msg.textContent = count === 1 ? 'Nice first tap!' : 'Tapped ' + count + ' times';
});
''';
    return app;
  }

  factory MicroApp.fromJson(Map<String, dynamic> json) => MicroApp(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Untitled',
        html: json['html'] as String? ?? '',
        css: json['css'] as String? ?? '',
        js: json['js'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'html': html,
        'css': css,
        'js': js,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Returns a copy with a new id and the "(copy)" suffix on the name.
  MicroApp duplicate() {
    final now = DateTime.now();
    return MicroApp(
      id: _newId(now),
      name: '$name (copy)',
      html: html,
      css: css,
      js: js,
      createdAt: now,
      updatedAt: now,
    );
  }

  static String _newId(DateTime time) =>
      '${time.microsecondsSinceEpoch.toRadixString(36)}'
      '-${Random.secure().nextInt(0x7fffffff).toRadixString(36)}';
}
