import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import 'database_service.dart';

/// Result of a single backend request.
///
/// A transport failure (no network, DNS, timeout) is represented as
/// [isNetworkError] with status code `0`, so callers can distinguish
/// "the server said no" from "we could not reach the server" and fall back to
/// local storage in the offline-first path.
class ApiResult {
  final bool success;
  final int statusCode;
  final String? code;
  final String? message;
  final dynamic data;

  /// The decoded JSON body, which may be a `Map`, a `List`, or `null`.
  final dynamic body;

  const ApiResult({
    required this.success,
    required this.statusCode,
    this.code,
    this.message,
    this.data,
    this.body,
  });

  factory ApiResult.network(String message) => ApiResult(
        success: false,
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: message,
      );

  bool get isNetworkError => statusCode == 0;

  @override
  String toString() => 'ApiResult($statusCode, success=$success, code=$code)';
}

/// Low-level HTTP client for the Node.js backend.
///
/// Holds the platform session tokens (persisted in the local SQLite settings
/// table so the app stays offline-first), injects the bearer token, and
/// refreshes it once on a `401` before giving up.
class BackendApiClient {
  static BackendApiClient? _instance;

  static const String _kAccessToken = 'auth_access_token';
  static const String _kRefreshToken = 'auth_refresh_token';
  static const Duration _timeout = Duration(seconds: 15);

  final String baseUrl;
  final http.Client _client;
  final DatabaseService _db;

  String? _accessToken;
  String? _refreshToken;
  bool _tokensLoaded = false;

  static bool? _remoteEnabledOverride;

  BackendApiClient({
    String? baseUrl,
    http.Client? client,
    DatabaseService? dbService,
  })  : baseUrl = baseUrl ?? AppConstants.apiBaseUrl,
        _client = client ?? http.Client(),
        _db = dbService ?? DatabaseService.instance;

  static BackendApiClient get instance => _instance ??= BackendApiClient();

  /// Whether real network calls are allowed.
  ///
  /// Disabled under `flutter test` so the existing offline unit/widget tests
  /// never open a socket; tests that exercise the client inject their own
  /// [http.Client] and set this explicitly.
  static bool get remoteEnabled {
    if (_remoteEnabledOverride != null) return _remoteEnabledOverride!;
    if (kIsWeb) return true;
    final flag = Platform.environment['FLUTTER_TEST'];
    return flag == null || flag == 'false';
  }

  @visibleForTesting
  static void setRemoteEnabledForTesting(bool? enabled) {
    _remoteEnabledOverride = enabled;
  }

  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  Future<void> loadTokens() async {
    if (_tokensLoaded) return;
    try {
      _accessToken = await _db.getSetting(_kAccessToken);
      _refreshToken = await _db.getSetting(_kRefreshToken);
    } catch (_) {
      _accessToken = null;
      _refreshToken = null;
    }
    _tokensLoaded = true;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _tokensLoaded = true;
    await _db.saveSetting(_kAccessToken, accessToken);
    await _db.saveSetting(_kRefreshToken, refreshToken);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _tokensLoaded = true;
    await _db.deleteSetting(_kAccessToken);
    await _db.deleteSetting(_kRefreshToken);
  }

  Future<ApiResult> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<ApiResult> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<ApiResult> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<ApiResult> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<ApiResult> delete(String path) => _send('DELETE', path);

  /// Rotates the session using the stored refresh token.
  Future<bool> refreshSession() async {
    await loadTokens();
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;

    final result = await _send(
      'POST',
      '/auth/refresh',
      body: {'refreshToken': _refreshToken},
      retryOnUnauthorized: false,
    );

    if (!result.success) return false;

    final data = result.data;
    if (data is! Map) return false;

    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    if (access == null || refresh == null) return false;

    await saveTokens(accessToken: access, refreshToken: refresh);
    return true;
  }

  Future<ApiResult> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool retryOnUnauthorized = true,
  }) async {
    await loadTokens();

    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(
        queryParameters: query.map((key, value) => MapEntry(key, '$value')),
      );
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (hasToken) 'Authorization': 'Bearer $_accessToken',
    };

    try {
      final encoded = body == null ? null : jsonEncode(body);
      late http.Response response;

      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(_timeout);
          break;
        case 'POST':
          response =
              await _client.post(uri, headers: headers, body: encoded).timeout(_timeout);
          break;
        case 'PATCH':
          response =
              await _client.patch(uri, headers: headers, body: encoded).timeout(_timeout);
          break;
        case 'PUT':
          response =
              await _client.put(uri, headers: headers, body: encoded).timeout(_timeout);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers).timeout(_timeout);
          break;
        default:
          return ApiResult.network('Unsupported method $method');
      }

      if (response.statusCode == 401 &&
          retryOnUnauthorized &&
          _refreshToken != null &&
          _refreshToken!.isNotEmpty &&
          path != '/auth/refresh') {
        final refreshed = await refreshSession();
        if (refreshed) {
          return await _send(
            method,
            path,
            body: body,
            query: query,
            retryOnUnauthorized: false,
          );
        }
      }

      return _parse(response);
    } on SocketException catch (e) {
      return ApiResult.network(e.message);
    } on TimeoutException {
      return ApiResult.network('Request timed out');
    } on http.ClientException catch (e) {
      return ApiResult.network(e.message);
    } catch (e) {
      return ApiResult.network(e.toString());
    }
  }

  ApiResult _parse(http.Response response) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    final map = decoded is Map<String, dynamic> ? decoded : null;
    final successFlag = map?['success'];
    final success = response.statusCode >= 200 &&
        response.statusCode < 300 &&
        (successFlag == null || successFlag == true);

    return ApiResult(
      success: success,
      statusCode: response.statusCode,
      code: map?['code'] as String?,
      message: (map?['message'] ?? map?['error']) as String?,
      data: map?['data'],
      body: decoded,
    );
  }
}
