import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'platform_services.dart';

/// Error raised by bridge handlers. [code] is forwarded to JavaScript so
/// micro-apps can branch on it (e.g. `PERMISSION_DENIED`).
class BridgeException implements Exception {
  const BridgeException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

/// Connects micro-app JavaScript to Flutter.
///
/// Page code calls `McroBridge.postMessage(json)` (see `bridge_js.dart`);
/// this class dispatches the request to [PlatformServices] and completes
/// the JavaScript promise by calling `__mcroComplete(id, ok, json)`.
class MicroAppBridge {
  MicroAppBridge({
    required void Function(String javascript) runJavaScript,
    PlatformServices? platform,
  })  : _runJavaScript = runJavaScript,
        _platform = platform ?? PlatformServices();

  final void Function(String javascript) _runJavaScript;
  final PlatformServices _platform;

  /// Registers the `McroBridge` JS channel on [controller].
  /// Must be called before the micro-app document is loaded.
  void attachTo(WebViewController controller) {
    controller.addJavaScriptChannel(
      'McroBridge',
      onMessageReceived: (message) {
        // Errors are reported back through the promise, never thrown here.
        handleMessage(message.message);
      },
    );
  }

  /// Handles one raw JSON message sent from the page.
  @visibleForTesting
  Future<void> handleMessage(String raw) async {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) {
      return;
    }
    final id = decoded['id'];
    final method = decoded['method'];
    if (id is! String || method is! String) {
      return;
    }
    final rawParams = decoded['params'];
    final params = rawParams is Map
        ? rawParams.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    try {
      final result = await _dispatch(method, params);
      _complete(id, true, jsonEncode(result));
    } on BridgeException catch (e) {
      _complete(id, false, jsonEncode({'code': e.code, 'message': e.message}));
    } on PlatformException catch (e) {
      _complete(
        id,
        false,
        jsonEncode({
          'code': e.code.isEmpty ? 'INTERNAL' : e.code,
          'message': e.message ?? 'Platform error.',
        }),
      );
    } catch (e) {
      _complete(id, false, jsonEncode({'code': 'INTERNAL', 'message': '$e'}));
    }
  }

  Future<Map<String, dynamic>> _dispatch(
    String method,
    Map<String, dynamic> params,
  ) {
    switch (method) {
      case 'geolocation.getCurrentPosition':
        return _getCurrentPosition(params);
      case 'sms.send':
        return _sendSms(params);
      default:
        throw BridgeException('UNKNOWN_METHOD', 'Unknown method: $method');
    }
  }

  Future<Map<String, dynamic>> _getCurrentPosition(
    Map<String, dynamic> params,
  ) async {
    // Ask for the strongest location permission. The result is NOT a hard
    // gate: the platform falls back to whatever the user granted (coarse
    // access alone is usable) and reports PERMISSION_DENIED when nothing
    // is available.
    await _platform.requestPermissions(const [
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_COARSE_LOCATION',
    ]);
    final rawTimeout = params['timeout'];
    final timeoutMs = rawTimeout is num
        ? rawTimeout.toInt().clamp(1000, 60000).toInt()
        : 15000;
    return _platform.getCurrentLocation(
      timeout: Duration(milliseconds: timeoutMs),
    );
  }

  Future<Map<String, dynamic>> _sendSms(Map<String, dynamic> params) async {
    final to = params['to'];
    final body = params['body'] ?? '';
    if (to is! String || to.trim().isEmpty) {
      throw const BridgeException(
        'INVALID_ARGUMENT',
        'The "to" field is required.',
      );
    }
    if (body is! String) {
      throw const BridgeException(
        'INVALID_ARGUMENT',
        'The "body" field must be a string.',
      );
    }
    final granted = await _platform
        .requestPermissions(const ['android.permission.SEND_SMS']);
    if (!granted) {
      throw const BridgeException(
        'PERMISSION_DENIED',
        'SMS permission was denied.',
      );
    }
    await _platform.sendSms(to: to.trim(), message: body);
    return <String, dynamic>{'sent': true};
  }

  void _complete(String id, bool ok, String json) {
    final status = ok ? 'true' : 'false';
    _runJavaScript(
      '__mcroComplete(${jsonEncode(id)}, $status, ${jsonEncode(json)})',
    );
  }
}
