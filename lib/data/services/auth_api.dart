import '../../core/network/api_client.dart';
import '../models/auth_models.dart';

class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.postMap(
      '/auth/login',
      auth: false,
      body: {'email': email, 'password': password},
    );
    return AuthResponse.fromJson(data);
  }

  Future<UserResponse> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final data = await _client.postMap(
      '/auth/register',
      auth: false,
      body: {'username': username, 'email': email, 'password': password},
    );
    return UserResponse.fromJson(data);
  }

  Future<MessageResponse> forgotPassword(String email) async {
    final data = await _client.postMap(
      '/auth/forgot-password',
      auth: false,
      body: {'email': email},
    );
    return MessageResponse.fromJson(data);
  }

  Future<MessageResponse> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final data = await _client.postMap(
      '/auth/reset-password',
      auth: false,
      body: {'token': token, 'newPassword': newPassword},
    );
    return MessageResponse.fromJson(data);
  }

  Future<UserResponse> me() async {
    final data = await _client.getMap('/auth/me');
    return UserResponse.fromJson(data);
  }

  Future<AuthResponse> refresh(String refreshToken) async {
    final data = await _client.postMap(
      '/auth/refresh',
      auth: false,
      body: {'refreshToken': refreshToken},
    );
    return AuthResponse.fromJson(data);
  }

  Future<void> logout({String? refreshToken}) async {
    await _client.postMap(
      '/auth/logout',
      auth: false,
      body: refreshToken == null || refreshToken.isEmpty
          ? null
          : {'refreshToken': refreshToken},
    );
  }
}
