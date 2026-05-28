import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/models/auth_models.dart';
import '../../data/models/json_helpers.dart';

abstract class SecureKeyValueStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

class StoredSession {
  const StoredSession({
    required this.accessToken,
    required this.user,
    this.refreshToken,
  });

  factory StoredSession.fromJson(Map<String, dynamic> json) => StoredSession(
    accessToken: readString(json, 'accessToken', readString(json, 'token')),
    refreshToken: readNullableString(json, 'refreshToken'),
    user: UserResponse.fromJson(asMap(json['user'])),
  );

  final String accessToken;
  final String? refreshToken;
  final UserResponse user;

  Map<String, dynamic> toJson() => withoutNulls({
    'accessToken': accessToken,
    'token': accessToken,
    'refreshToken': refreshToken,
    'user': user.toJson(),
  });
}

class SessionStorage {
  SessionStorage({MethodChannel? channel, SecureKeyValueStore? secureStore})
    : _legacyChannel =
          channel ?? const MethodChannel('lifeplanner_mobile/session_storage'),
      _secureStore = secureStore ?? FlutterSecureKeyValueStore();

  static const _accessTokenKey = 'lifeplanner.accessToken';
  static const _refreshTokenKey = 'lifeplanner.refreshToken';
  static const _userKey = 'lifeplanner.user';

  final MethodChannel _legacyChannel;
  final SecureKeyValueStore _secureStore;
  String? _legacyMemorySession;

  Future<StoredSession?> readSession() async {
    final secureSession = await _readSecureSession();
    if (secureSession != null) {
      return secureSession;
    }

    final legacyRaw = await _readLegacySession();
    if (legacyRaw == null || legacyRaw.isEmpty) {
      return null;
    }
    final legacySession = StoredSession.fromJson(asMap(jsonDecode(legacyRaw)));
    await writeSession(legacySession);
    await _clearLegacySession();
    return legacySession;
  }

  Future<void> writeSession(StoredSession session) async {
    await _secureStore.write(key: _accessTokenKey, value: session.accessToken);
    if (session.refreshToken == null || session.refreshToken!.isEmpty) {
      await _secureStore.delete(key: _refreshTokenKey);
    } else {
      await _secureStore.write(
        key: _refreshTokenKey,
        value: session.refreshToken!,
      );
    }
    await _secureStore.write(key: _userKey, value: jsonEncode(session.user));
    await _clearLegacySession();
  }

  Future<void> clearSession() async {
    await _secureStore.delete(key: _accessTokenKey);
    await _secureStore.delete(key: _refreshTokenKey);
    await _secureStore.delete(key: _userKey);
    await _clearLegacySession();
  }

  Future<StoredSession?> _readSecureSession() async {
    final accessToken = await _secureStore.read(key: _accessTokenKey);
    final userRaw = await _secureStore.read(key: _userKey);
    if (accessToken == null ||
        accessToken.isEmpty ||
        userRaw == null ||
        userRaw.isEmpty) {
      return null;
    }
    return StoredSession(
      accessToken: accessToken,
      refreshToken: await _secureStore.read(key: _refreshTokenKey),
      user: UserResponse.fromJson(asMap(jsonDecode(userRaw))),
    );
  }

  Future<String?> _readLegacySession() async {
    try {
      return await _legacyChannel.invokeMethod<String>('read');
    } on MissingPluginException {
      return _legacyMemorySession;
    }
  }

  Future<void> _clearLegacySession() async {
    _legacyMemorySession = null;
    try {
      await _legacyChannel.invokeMethod<void>('clear');
    } on MissingPluginException {
      return;
    }
  }
}
