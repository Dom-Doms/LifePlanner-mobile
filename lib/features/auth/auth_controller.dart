import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/session_storage.dart';
import '../../data/models/auth_models.dart';
import '../../data/models/json_helpers.dart';
import '../../data/services/auth_api.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthApi authApi,
    required ApiClient apiClient,
    required SessionStorage storage,
  }) : _authApi = authApi,
       _apiClient = apiClient,
       _storage = storage {
    _apiClient.onUnauthorized = logout;
  }

  final AuthApi _authApi;
  final ApiClient _apiClient;
  final SessionStorage _storage;

  bool _restoring = true;
  bool _busy = false;
  String? _token;
  UserResponse? _user;

  bool get restoring => _restoring;
  bool get busy => _busy;
  bool get isAuthenticated => _token != null && _user != null;
  String? get token => _token;
  UserResponse? get user => _user;

  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (!_restoring) return;
    final completer = Completer<void>();
    void listener() {
      if (!_restoring && !completer.isCompleted) {
        completer.complete();
      }
    }

    addListener(listener);
    try {
      listener();
      await completer.future.timeout(timeout);
    } finally {
      removeListener(listener);
    }
  }

  Future<void> restore() async {
    _restoring = true;
    notifyListeners();
    try {
      final raw = await _storage.readSession();
      if (raw != null && raw.isNotEmpty) {
        final json = asMap(jsonDecode(raw));
        final token = readNullableString(json, 'token');
        final userJson = asMap(json['user']);
        if (token != null && userJson.isNotEmpty) {
          _applySession(token, UserResponse.fromJson(userJson));
          await refreshProfile();
        }
      }
    } catch (_) {
      await logout();
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    await _runBusy(() async {
      final auth = await _authApi.login(email: email, password: password);
      await _persistSession(auth.token, auth.user);
    });
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    await _runBusy(() async {
      await _authApi.register(
        username: username,
        email: email,
        password: password,
      );
      final auth = await _authApi.login(email: email, password: password);
      await _persistSession(auth.token, auth.user);
    });
  }

  Future<void> refreshProfile() async {
    if (_token == null) return;
    final user = await _authApi.me();
    _user = user;
    await _storage.writeSession(
      jsonEncode({'token': _token, 'user': user.toJson()}),
    );
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _apiClient.setToken(null);
    await _storage.clearSession();
    notifyListeners();
  }

  Future<void> _persistSession(String token, UserResponse user) async {
    _applySession(token, user);
    await _storage.writeSession(
      jsonEncode({'token': token, 'user': user.toJson()}),
    );
  }

  void _applySession(String token, UserResponse user) {
    _token = token;
    _user = user;
    _apiClient.setToken(token);
    notifyListeners();
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
