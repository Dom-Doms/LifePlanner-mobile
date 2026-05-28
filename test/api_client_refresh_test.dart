import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeplanner_mobile/core/network/api_client.dart';

void main() {
  test('401 refreshes token and retries original request once', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final seenAuthorization = <String?>[];
    unawaited(
      server.forEach((request) async {
        seenAuthorization.add(
          request.headers.value(HttpHeaders.authorizationHeader),
        );
        if (request.headers.value(HttpHeaders.authorizationHeader) ==
            'Bearer fresh-token') {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'ok': true}));
        } else {
          request.response
            ..statusCode = 401
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'message': 'expired'}));
        }
        await request.response.close();
      }),
    );
    final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api');
    client.setToken('expired-token');
    var refreshCalls = 0;
    client.onRefreshToken = () async {
      refreshCalls += 1;
      client.setToken('fresh-token');
      return true;
    };

    final result = await client.getMap('/protected');

    expect(result['ok'], isTrue);
    expect(refreshCalls, 1);
    expect(seenAuthorization, ['Bearer expired-token', 'Bearer fresh-token']);
  });

  test(
    '401 refresh failure calls unauthorized handler and does not loop',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var requests = 0;
      unawaited(
        server.forEach((request) async {
          requests += 1;
          request.response
            ..statusCode = 401
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'message': 'expired'}));
          await request.response.close();
        }),
      );
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api');
      client.setToken('expired-token');
      var refreshCalls = 0;
      var unauthorizedCalls = 0;
      client.onRefreshToken = () async {
        refreshCalls += 1;
        return false;
      };
      client.onUnauthorized = () async {
        unauthorizedCalls += 1;
      };

      await expectLater(
        client.getMap('/protected'),
        throwsA(isA<ApiException>()),
      );

      expect(requests, 1);
      expect(refreshCalls, 1);
      expect(unauthorizedCalls, 1);
    },
  );

  test('auth false requests do not call refresh handler', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(
      server.forEach((request) async {
        request.response
          ..statusCode = 401
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'message': 'bad login'}));
        await request.response.close();
      }),
    );
    final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api');
    var refreshCalls = 0;
    client.onRefreshToken = () async {
      refreshCalls += 1;
      return true;
    };

    await expectLater(
      client.postMap('/auth/login', auth: false, body: {}),
      throwsA(isA<ApiException>()),
    );

    expect(refreshCalls, 0);
  });
}
