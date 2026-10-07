import 'package:flutter/services.dart';

/// Thin wrapper over the `dev.mcro.mcro/platform` method channel,
/// implemented in `MainActivity.kt` (permissions, location, SMS).
class PlatformServices {
  static const MethodChannel _channel = MethodChannel('dev.mcro.mcro/platform');

  /// Requests [permissions]; returns true when all of them are granted.
  Future<bool> requestPermissions(List<String> permissions) async {
    if (permissions.isEmpty) {
      return true;
    }
    final granted = await _channel.invokeMethod<bool>(
      'permissions.request',
      <String, dynamic>{'permissions': permissions},
    );
    return granted ?? false;
  }

  /// Returns the current (or most recent) position from the platform.
  Future<Map<String, dynamic>> getCurrentLocation({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final location = await _channel.invokeMapMethod<String, dynamic>(
      'location.getCurrent',
      <String, dynamic>{'timeoutMs': timeout.inMilliseconds},
    );
    if (location == null) {
      throw PlatformException(
        code: 'POSITION_UNAVAILABLE',
        message: 'The platform returned no location.',
      );
    }
    return location;
  }

  /// Sends an SMS via the default SMS app subsystem (requires SEND_SMS).
  Future<void> sendSms({required String to, required String message}) async {
    await _channel.invokeMethod<void>(
      'sms.send',
      <String, dynamic>{'to': to, 'message': message},
    );
  }
}
