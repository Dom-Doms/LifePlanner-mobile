import 'package:flutter_test/flutter_test.dart';
import 'package:lifeplanner_mobile/core/network/api_client.dart';
import 'package:lifeplanner_mobile/core/notifications/mobile_push_service.dart';
import 'package:lifeplanner_mobile/core/storage/session_storage.dart';
import 'package:lifeplanner_mobile/data/models/auth_models.dart';
import 'package:lifeplanner_mobile/data/services/auth_api.dart';
import 'package:lifeplanner_mobile/features/auth/auth_controller.dart';

import 'session_storage_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restore keeps session when access token is valid', () async {
    final storage = SessionStorage(secureStore: MemorySecureKeyValueStore());
    final authApi = FakeAuthApi(meResponse: _user());
    final controller = AuthController(
      authApi: authApi,
      apiClient: ApiClient(baseUrl: 'http://localhost/api'),
      storage: storage,
    );
    await storage.writeSession(
      StoredSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        user: _user(),
      ),
    );

    await controller.restore();

    expect(controller.isAuthenticated, isTrue);
    expect(controller.token, 'access');
    expect(controller.refreshToken, 'refresh');
    expect(authApi.refreshCalls, 0);
  });

  test('restore registers mobile push after valid session', () async {
    final storage = SessionStorage(secureStore: MemorySecureKeyValueStore());
    final mobilePush = FakeMobilePushRegistration();
    final controller = AuthController(
      authApi: FakeAuthApi(meResponse: _user()),
      apiClient: ApiClient(baseUrl: 'http://localhost/api'),
      storage: storage,
      mobilePush: mobilePush,
    );
    await storage.writeSession(
      StoredSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        user: _user(),
      ),
    );

    await controller.restore();

    expect(mobilePush.registerCalls, 1);
  });

  test('login registers mobile push after session is applied', () async {
    final storage = SessionStorage(secureStore: MemorySecureKeyValueStore());
    final mobilePush = FakeMobilePushRegistration();
    final controller = AuthController(
      authApi: FakeAuthApi(
        loginResponse: AuthResponse(
          token: 'access',
          refreshToken: 'refresh',
          user: _user(),
        ),
      ),
      apiClient: ApiClient(baseUrl: 'http://localhost/api'),
      storage: storage,
      mobilePush: mobilePush,
    );

    await controller.login(
      email: 'mobile@example.com',
      password: 'Password123!',
    );

    expect(controller.isAuthenticated, isTrue);
    expect(mobilePush.registerCalls, 1);
  });

  test(
    'restore refreshes expired access token when refresh token is valid',
    () async {
      final storage = SessionStorage(secureStore: MemorySecureKeyValueStore());
      final authApi = FakeAuthApi(
        meError: ApiException(statusCode: 401, message: 'expired'),
        refreshResponse: AuthResponse(
          token: 'new-access',
          refreshToken: 'new-refresh',
          user: _user(),
        ),
      );
      final controller = AuthController(
        authApi: authApi,
        apiClient: ApiClient(baseUrl: 'http://localhost/api'),
        storage: storage,
      );
      await storage.writeSession(
        StoredSession(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
          user: _user(),
        ),
      );

      await controller.restore();

      expect(controller.isAuthenticated, isTrue);
      expect(controller.token, 'new-access');
      expect(controller.refreshToken, 'new-refresh');
      expect(authApi.refreshCalls, 1);
    },
  );

  test('restore logs out when refresh token fails', () async {
    final storage = SessionStorage(secureStore: MemorySecureKeyValueStore());
    final authApi = FakeAuthApi(
      meError: ApiException(statusCode: 401, message: 'expired'),
      refreshError: ApiException(statusCode: 401, message: 'invalid refresh'),
    );
    final controller = AuthController(
      authApi: authApi,
      apiClient: ApiClient(baseUrl: 'http://localhost/api'),
      storage: storage,
    );
    await storage.writeSession(
      StoredSession(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        user: _user(),
      ),
    );

    await controller.restore();

    expect(controller.isAuthenticated, isFalse);
    expect(await storage.readSession(), isNull);
  });

  test('logout revokes refresh token and clears local session', () async {
    final storage = SessionStorage(secureStore: MemorySecureKeyValueStore());
    final authApi = FakeAuthApi(meResponse: _user());
    final controller = AuthController(
      authApi: authApi,
      apiClient: ApiClient(baseUrl: 'http://localhost/api'),
      storage: storage,
    );
    await storage.writeSession(
      StoredSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        user: _user(),
      ),
    );
    await controller.restore();

    await controller.logout();

    expect(authApi.logoutRefreshToken, 'refresh');
    expect(controller.isAuthenticated, isFalse);
    expect(await storage.readSession(), isNull);
  });

  test(
    'logout clears local session even when mobile push unregister fails',
    () async {
      final storage = SessionStorage(secureStore: MemorySecureKeyValueStore());
      final mobilePush = FakeMobilePushRegistration(deleteFails: true);
      final controller = AuthController(
        authApi: FakeAuthApi(meResponse: _user()),
        apiClient: ApiClient(baseUrl: 'http://localhost/api'),
        storage: storage,
        mobilePush: mobilePush,
      );
      await storage.writeSession(
        StoredSession(
          accessToken: 'access',
          refreshToken: 'refresh',
          user: _user(),
        ),
      );
      await controller.restore();

      await controller.logout();

      expect(mobilePush.deleteCalls, 1);
      expect(controller.isAuthenticated, isFalse);
      expect(await storage.readSession(), isNull);
    },
  );
}

UserResponse _user() => const UserResponse(
  id: 1,
  username: 'mobile',
  email: 'mobile@example.com',
  role: 'USER',
);

class FakeAuthApi implements AuthApi {
  FakeAuthApi({
    this.loginResponse,
    this.meResponse,
    this.meError,
    this.refreshResponse,
    this.refreshError,
  });

  final AuthResponse? loginResponse;
  final UserResponse? meResponse;
  final ApiException? meError;
  final AuthResponse? refreshResponse;
  final ApiException? refreshError;
  int refreshCalls = 0;
  int loginCalls = 0;
  String? logoutRefreshToken;

  @override
  Future<MessageResponse> forgotPassword(String email) =>
      throw UnimplementedError();

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    loginCalls += 1;
    return loginResponse ??
        AuthResponse(token: 'access', refreshToken: 'refresh', user: _user());
  }

  @override
  Future<void> logout({String? refreshToken}) async {
    logoutRefreshToken = refreshToken;
  }

  @override
  Future<UserResponse> me() async {
    final error = meError;
    if (error != null) throw error;
    return meResponse ?? _user();
  }

  @override
  Future<AuthResponse> refresh(String refreshToken) async {
    refreshCalls += 1;
    final error = refreshError;
    if (error != null) throw error;
    return refreshResponse ??
        AuthResponse(
          token: 'new-access',
          refreshToken: 'new-refresh',
          user: _user(),
        );
  }

  @override
  Future<UserResponse> register({
    required String username,
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<MessageResponse> resetPassword({
    required String token,
    required String newPassword,
  }) => throw UnimplementedError();
}

class FakeMobilePushRegistration implements MobilePushRegistration {
  FakeMobilePushRegistration({this.deleteFails = false});

  final bool deleteFails;
  int registerCalls = 0;
  int deleteCalls = 0;

  @override
  Future<void> registerCurrentDevice() async {
    registerCalls += 1;
  }

  @override
  Future<void> deleteCurrentTokenOnLogout() async {
    deleteCalls += 1;
    if (deleteFails) {
      throw Exception('network');
    }
  }
}
