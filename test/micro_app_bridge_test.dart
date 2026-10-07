import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcro/services/micro_app_bridge.dart';
import 'package:mcro/services/platform_services.dart';

class _FakePlatform extends PlatformServices {
  bool locationGranted = true;
  bool smsGranted = true;
  bool locationThrows = false;
  List<String>? lastPermissions;
  String? lastSmsTo;
  String? lastSmsBody;
  Duration? lastTimeout;
  Map<String, dynamic> location = <String, dynamic>{
    'latitude': 52.5,
    'longitude': 13.4,
    'accuracy': 5.0,
    'altitude': null,
    'speed': null,
    'timestamp': 1728000000000,
  };

  @override
  Future<bool> requestPermissions(List<String> permissions) async {
    lastPermissions = permissions;
    if (permissions.contains('android.permission.SEND_SMS')) {
      return smsGranted;
    }
    return locationGranted;
  }

  @override
  Future<Map<String, dynamic>> getCurrentLocation({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    lastTimeout = timeout;
    if (!locationGranted) {
      throw PlatformException(
        code: 'PERMISSION_DENIED',
        message: 'Location permission not granted.',
      );
    }
    if (locationThrows) {
      throw PlatformException(code: 'TIMEOUT', message: 'No fix within timeout.');
    }
    return location;
  }

  @override
  Future<void> sendSms({required String to, required String message}) async {
    lastSmsTo = to;
    lastSmsBody = message;
  }
}

void main() {
  late _FakePlatform platform;
  late List<String> javascript;
  late MicroAppBridge bridge;

  setUp(() {
    platform = _FakePlatform();
    javascript = <String>[];
    bridge = MicroAppBridge(
      runJavaScript: javascript.add,
      platform: platform,
    );
  });

  Future<void> send(String json) => bridge.handleMessage(json);

  group('geolocation.getCurrentPosition', () {
    test('resolves with position data', () async {
      await send(
        '{"id":"t1","method":"geolocation.getCurrentPosition","params":{}}',
      );

      expect(
        platform.lastPermissions,
        contains('android.permission.ACCESS_FINE_LOCATION'),
      );
      expect(platform.lastTimeout, const Duration(seconds: 15));
      expect(javascript, hasLength(1));
      expect(javascript.single, startsWith('__mcroComplete("t1", true'));
      expect(javascript.single, contains('latitude'));
      expect(javascript.single, contains('52.5'));
    });

    test('forwards and clamps the timeout option', () async {
      await send(
        '{"id":"t2","method":"geolocation.getCurrentPosition",'
        '"params":{"timeout":999999}}',
      );

      expect(platform.lastTimeout, const Duration(seconds: 60));
    });

    test('rejects with PERMISSION_DENIED when permission is missing', () async {
      platform.locationGranted = false;
      await send(
        '{"id":"t3","method":"geolocation.getCurrentPosition","params":{}}',
      );

      expect(javascript.single, startsWith('__mcroComplete("t3", false'));
      expect(javascript.single, contains('PERMISSION_DENIED'));
    });

    test('maps platform errors into the rejection payload', () async {
      platform.locationThrows = true;
      await send(
        '{"id":"t4","method":"geolocation.getCurrentPosition","params":{}}',
      );

      expect(javascript.single, startsWith('__mcroComplete("t4", false'));
      expect(javascript.single, contains('TIMEOUT'));
    });
  });

  group('sms.send', () {
    test('trims the recipient and delivers the message', () async {
      await send(
        '{"id":"s1","method":"sms.send",'
        '"params":{"to":" +15550001111 ","body":"hi"}}',
      );

      expect(platform.lastSmsTo, '+15550001111');
      expect(platform.lastSmsBody, 'hi');
      expect(javascript.single, startsWith('__mcroComplete("s1", true'));
      expect(javascript.single, contains('sent'));
    });

    test('rejects with INVALID_ARGUMENT when recipient is missing', () async {
      await send('{"id":"s2","method":"sms.send","params":{"body":"hi"}}');

      expect(platform.lastSmsTo, isNull);
      expect(javascript.single, startsWith('__mcroComplete("s2", false'));
      expect(javascript.single, contains('INVALID_ARGUMENT'));
    });

    test('rejects with PERMISSION_DENIED when SMS permission is missing',
        () async {
      platform.smsGranted = false;
      await send(
        '{"id":"s3","method":"sms.send","params":{"to":"+1","body":"hi"}}',
      );

      expect(platform.lastSmsTo, isNull);
      expect(javascript.single, startsWith('__mcroComplete("s3", false'));
      expect(javascript.single, contains('PERMISSION_DENIED'));
    });
  });

  group('message handling', () {
    test('rejects unknown methods', () async {
      await send('{"id":"u1","method":"bogus.call","params":{}}');

      expect(javascript.single, startsWith('__mcroComplete("u1", false'));
      expect(javascript.single, contains('UNKNOWN_METHOD'));
    });

    test('ignores malformed messages', () async {
      await send('not json');
      await send('[1, 2, 3]');
      await send('{"id":5}');
      await send('{"id":"x","method":42}');

      expect(javascript, isEmpty);
    });
  });
}