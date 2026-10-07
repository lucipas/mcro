import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcro/services/platform_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.mcro.mcro/platform');
  final calls = <MethodCall>[];

  void mockPlatform(Future<Object?>? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    calls.clear();
  });

  test('requestPermissions forwards the permission list', () async {
    mockPlatform((call) async {
      calls.add(call);
      return true;
    });

    final granted = await PlatformServices().requestPermissions(
      <String>['android.permission.SEND_SMS'],
    );

    expect(granted, isTrue);
    expect(calls.single.method, 'permissions.request');
    final args = calls.single.arguments as Map;
    expect(args['permissions'], <String>['android.permission.SEND_SMS']);
  });

  test('requestPermissions returns false when the platform says no', () async {
    mockPlatform((call) async => false);

    expect(await PlatformServices().requestPermissions(<String>['a.b.c']),
        isFalse);
  });

  test('requestPermissions is trivially true for an empty list', () async {
    expect(await PlatformServices().requestPermissions(<String>[]), isTrue);
  });

  test('getCurrentLocation returns the platform map', () async {
    mockPlatform((call) async {
      calls.add(call);
      return <String, dynamic>{
        'latitude': 1.0,
        'longitude': 2.0,
        'timestamp': 123,
      };
    });

    final location = await PlatformServices().getCurrentLocation(
      timeout: const Duration(seconds: 7),
    );

    expect(location['latitude'], 1.0);
    expect(location['longitude'], 2.0);
    expect(calls.single.method, 'location.getCurrent');
    final args = calls.single.arguments as Map;
    expect(args['timeoutMs'], 7000);
  });

  test('getCurrentLocation rethrows platform errors', () async {
    mockPlatform(
      (call) async => throw PlatformException(
        code: 'TIMEOUT',
        message: 'No fix',
      ),
    );

    await expectLater(
      PlatformServices().getCurrentLocation(),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'TIMEOUT'),
      ),
    );
  });

  test('getCurrentLocation surfaces a null result as an error', () async {
    mockPlatform((call) async => null);

    await expectLater(
      PlatformServices().getCurrentLocation(),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'POSITION_UNAVAILABLE',
        ),
      ),
    );
  });

  test('sendSms passes the recipient and message', () async {
    mockPlatform((call) async {
      calls.add(call);
      return null;
    });

    await PlatformServices().sendSms(to: '+15550001111', message: 'hi');

    expect(calls.single.method, 'sms.send');
    final args = calls.single.arguments as Map;
    expect(args['to'], '+15550001111');
    expect(args['message'], 'hi');
  });
}