import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/notifications/mobile_push_service.dart';
import '../../core/storage/session_storage.dart';
import '../../data/models/auth_models.dart';
import '../../data/services/auth_api.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthApi authApi,
    required ApiClient apiClient,
    required SessionStorage storage,
    MobilePushRegistration? mobilePush,
  }) : _authApi = authApi,
       _apiClient = apiClient,
       _storage = storage,
       _mobilePush = mobilePush {
    _apiClient.onRefreshToken = _refreshAccessToken;
    _apiClient.onUnauthorized = logout;
  }

  final AuthApi _authApi;
  final ApiClient _apiClient;
  final SessionStorage _storage;
  final MobilePushRegistration? _mobilePush;

  bool _restoring = true;
  bool _busy = false;
  String? _accessToken;
  String? _refreshToken;
  UserResponse? _user;

  bool get restoring => _restoring;
  bool get busy => _busy;
  bool get isAuthenticated => _accessToken != null && _user != null;
  String? get token => _accessToken;
  String? get refreshToken => _refreshToken;
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
      final session = await _storage.readSession();
      if (session != null) {
        _applySession(
          session.accessToken,
          session.user,
          refreshToken: session.refreshToken,
        );
        try {
          await refreshProfile();
        } on ApiException catch (error) {
          if (error.statusCode == 401 || error.statusCode == 403) {
            final refreshed = await _refreshAccessToken();
            if (!refreshed) {
              await logout();
            }
          } else {
            debugPrint(
              '[auth] profile refresh failed during restore; keeping cached session: ${error.message}',
            );
          }
        }
        if (isAuthenticated) {
          await _mobilePush?.registerCurrentDevice();
        }
      }
    } catch (error) {
      debugPrint('[auth] session restore failed: $error');
      await logout();
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    await _runBusy(() async {
      final auth = await _authApi.login(email: email, password: password);
      await _persistSession(
        accessToken: auth.token,
        refreshToken: auth.refreshToken,
        user: auth.user,
      );
      await _mobilePush?.registerCurrentDevice();
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
      await _persistSession(
        accessToken: auth.token,
        refreshToken: auth.refreshToken,
        user: auth.user,
      );
      await _mobilePush?.registerCurrentDevice();
    });
  }

  Future<void> refreshProfile() async {
    if (_accessToken == null) return;
    final user = await _authApi.me();
    _user = user;
    await _storage.writeSession(
      StoredSession(
        accessToken: _accessToken!,
        refreshToken: _refreshToken,
        user: user,
      ),
    );
    notifyListeners();
  }

  Future<void> logout() async {
    final refreshToken = _refreshToken;
    await _mobilePush?.deleteCurrentTokenOnLogout();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _authApi.logout(refreshToken: refreshToken);
      } catch (error) {
        debugPrint('[auth] remote logout failed: $error');
      }
    }
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    _apiClient.setToken(null);
    await _storage.clearSession();
    notifyListeners();
  }

  Future<bool> _refreshAccessToken() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }
    try {
      final auth = await _authApi.refresh(refreshToken);
      await _persistSession(
        accessToken: auth.token,
        refreshToken: auth.refreshToken,
        user: auth.user,
      );
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return false;
      }
      debugPrint('[auth] access token refresh failed: ${error.message}');
      return false;
    } catch (error) {
      debugPrint('[auth] access token refresh failed: $error');
      return false;
    }
  }

  Future<void> _persistSession({
    required String accessToken,
    required String? refreshToken,
    required UserResponse user,
  }) async {
    _applySession(accessToken, user, refreshToken: refreshToken);
    await _storage.writeSession(
      StoredSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
      ),
    );
  }

  void _applySession(
    String accessToken,
    UserResponse user, {
    String? refreshToken,
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _user = user;
    _apiClient.setToken(accessToken);
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
