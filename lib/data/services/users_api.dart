import '../../core/network/api_client.dart';
import '../models/auth_models.dart';
import '../models/json_helpers.dart';

class UsersApi {
  UsersApi(this._client);

  final ApiClient _client;

  Future<List<UserResponse>> searchUsers(String query) async {
    if (query.trim().length < 2) return [];
    final data = await _client.getList(
      '/users/search',
      query: {'q': query.trim()},
    );
    return data.map((item) => UserResponse.fromJson(asMap(item))).toList();
  }
}
