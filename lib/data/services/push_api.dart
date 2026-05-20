import '../../core/network/api_client.dart';

class PushApi {
  PushApi(this._client);

  final ApiClient _client;

  Future<String?> getVapidPublicKey() async {
    final data = await _client.getMap('/push/vapid-public-key');
    return data['publicKey']?.toString();
  }

  Future<Map<String, dynamic>> sendTestNotification({String? title}) {
    return _client.postMap(
      '/push/test',
      body: title == null || title.isEmpty ? null : {'title': title},
    );
  }
}
