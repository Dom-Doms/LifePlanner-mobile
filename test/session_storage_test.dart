import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeplanner_mobile/core/storage/session_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('lifeplanner_mobile/session_storage_test');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('session storage writes and restores persisted session value', () async {
    String? persisted;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'read':
              return persisted;
            case 'write':
              persisted = (call.arguments as Map)['value'] as String?;
              return null;
            case 'clear':
              persisted = null;
              return null;
          }
          return null;
        });

    final storage = SessionStorage(channel: channel);
    await storage.writeSession('{"token":"abc"}');

    expect(await storage.readSession(), '{"token":"abc"}');

    await storage.clearSession();
    expect(await storage.readSession(), isNull);
  });
}
