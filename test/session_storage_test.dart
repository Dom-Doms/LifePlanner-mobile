import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeplanner_mobile/core/storage/session_storage.dart';
import 'package:lifeplanner_mobile/data/models/auth_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('lifeplanner_mobile/session_storage_test');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('secure storage writes and restores token pair and user', () async {
    final secure = MemorySecureKeyValueStore();
    final storage = SessionStorage(channel: channel, secureStore: secure);
    final user = _user();

    await storage.writeSession(
      StoredSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        user: user,
      ),
    );

    final restored = await storage.readSession();
    expect(restored?.accessToken, 'access-token');
    expect(restored?.refreshToken, 'refresh-token');
    expect(restored?.user.email, user.email);
    expect(secure.values.containsValue('access-token'), isTrue);
    expect(secure.values.containsValue('refresh-token'), isTrue);
  });

  test('migrates legacy platform session and clears legacy storage', () async {
    final secure = MemorySecureKeyValueStore();
    var legacyCleared = false;
    final legacySession = jsonEncode({
      'token': 'legacy-access-token',
      'user': _user().toJson(),
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'read':
              return legacyCleared ? null : legacySession;
            case 'clear':
              legacyCleared = true;
              return null;
          }
          return null;
        });

    final storage = SessionStorage(channel: channel, secureStore: secure);
    final migrated = await storage.readSession();

    expect(migrated?.accessToken, 'legacy-access-token');
    expect(migrated?.refreshToken, isNull);
    expect(legacyCleared, isTrue);
    expect((await storage.readSession())?.accessToken, 'legacy-access-token');
  });

  test('clear removes secure and legacy session data', () async {
    final secure = MemorySecureKeyValueStore();
    var legacyCleared = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'clear') {
            legacyCleared = true;
          }
          return null;
        });
    final storage = SessionStorage(channel: channel, secureStore: secure);

    await storage.writeSession(
      StoredSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        user: _user(),
      ),
    );
    await storage.clearSession();

    expect(await storage.readSession(), isNull);
    expect(secure.values, isEmpty);
    expect(legacyCleared, isTrue);
  });
}

UserResponse _user() => const UserResponse(
  id: 1,
  username: 'mobile',
  email: 'mobile@example.com',
  role: 'USER',
);

class MemorySecureKeyValueStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
