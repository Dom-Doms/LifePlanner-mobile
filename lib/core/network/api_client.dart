import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.fieldErrors = const {},
  });

  final int statusCode;
  final String message;
  final Map<String, String> fieldErrors;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required String baseUrl}) : _baseUri = Uri.parse(baseUrl) {
    _httpClient.userAgent = 'LifePlanner Flutter';
  }

  final Uri _baseUri;
  final HttpClient _httpClient = HttpClient();
  String? _token;
  Future<bool> Function()? onRefreshToken;
  Future<void> Function()? onUnauthorized;
  Future<bool>? _refreshInFlight;

  void setToken(String? token) {
    _token = token;
  }

  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, String?> query = const {},
    bool auth = true,
  }) async {
    final decoded = await _request('GET', path, query: query, auth: auth);
    if (decoded is Map<String, dynamic>) return decoded;
    throw ApiException(statusCode: 500, message: 'Risposta API non valida');
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String?> query = const {},
    bool auth = true,
  }) async {
    final decoded = await _request('GET', path, query: query, auth: auth);
    if (decoded is List<dynamic>) return decoded;
    throw ApiException(statusCode: 500, message: 'Risposta API non valida');
  }

  Future<Map<String, dynamic>> postMap(
    String path, {
    Object? body,
    Map<String, String?> query = const {},
    bool auth = true,
  }) async {
    final decoded = await _request(
      'POST',
      path,
      body: body,
      query: query,
      auth: auth,
    );
    if (decoded is Map<String, dynamic>) return decoded;
    throw ApiException(statusCode: 500, message: 'Risposta API non valida');
  }

  Future<Map<String, dynamic>> putMap(
    String path, {
    Object? body,
    Map<String, String?> query = const {},
    bool auth = true,
  }) async {
    final decoded = await _request(
      'PUT',
      path,
      body: body,
      query: query,
      auth: auth,
    );
    if (decoded is Map<String, dynamic>) return decoded;
    throw ApiException(statusCode: 500, message: 'Risposta API non valida');
  }

  Future<void> delete(
    String path, {
    Object? body,
    Map<String, String?> query = const {},
    bool auth = true,
  }) async {
    await _request('DELETE', path, body: body, query: query, auth: auth);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String?> query = const {},
    bool auth = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    final uri = _buildUri(path, query);
    debugPrint('[api] $method ${uri.path} start');
    try {
      final decoded =
          await _sendRequest(
            method,
            uri,
            body: body,
            auth: auth,
            allowRefresh: true,
          ).timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw ApiException(
                statusCode: 408,
                message: 'Timeout API: $method ${uri.path}',
              );
            },
          );
      debugPrint(
        '[api] $method ${uri.path} success ${stopwatch.elapsedMilliseconds}ms',
      );
      return decoded;
    } on ApiException catch (error) {
      debugPrint(
        '[api] $method ${uri.path} error ${error.statusCode} ${error.message}',
      );
      rethrow;
    } catch (error) {
      debugPrint('[api] $method ${uri.path} error $error');
      throw ApiException(
        statusCode: 500,
        message: 'Errore rete: $method ${uri.path}',
      );
    }
  }

  Future<dynamic> _sendRequest(
    String method,
    Uri uri, {
    Object? body,
    bool auth = true,
    required bool allowRefresh,
  }) async {
    final request = await _httpClient.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    if (auth && _token != null && _token!.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    }
    if (body != null) {
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    final decoded = text.isEmpty ? null : jsonDecode(text);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (response.statusCode == 401 && auth && allowRefresh) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        return _sendRequest(
          method,
          uri,
          body: body,
          auth: auth,
          allowRefresh: false,
        );
      }
      await onUnauthorized?.call();
    }

    throw _exceptionFromResponse(response.statusCode, decoded);
  }

  Future<bool> _refreshAccessToken() async {
    final handler = onRefreshToken;
    if (handler == null) {
      return false;
    }
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final refresh = handler();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    }
  }

  Uri _buildUri(String path, Map<String, String?> query) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path
        : '${_baseUri.path}/';
    final mergedQuery = Map<String, String>.from(_baseUri.queryParameters);
    query.forEach((key, value) {
      if (value != null && value.isNotEmpty) mergedQuery[key] = value;
    });
    return _baseUri.replace(
      path: '$basePath$cleanPath',
      queryParameters: mergedQuery.isEmpty ? null : mergedQuery,
    );
  }

  ApiException _exceptionFromResponse(int statusCode, dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final errors = <String, String>{};
      final rawErrors = decoded['fieldErrors'];
      if (rawErrors is Map<String, dynamic>) {
        rawErrors.forEach((key, value) => errors[key] = value.toString());
      }
      final message = decoded['message']?.toString();
      return ApiException(
        statusCode: statusCode,
        message: message == null || message.isEmpty
            ? 'Errore API $statusCode'
            : message,
        fieldErrors: errors,
      );
    }
    return ApiException(
      statusCode: statusCode,
      message: 'Errore API $statusCode',
    );
  }
}
