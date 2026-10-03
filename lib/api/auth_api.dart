import 'dart:convert';

import 'package:http/http.dart' as http;

import 'json_io.dart';
import 'models.dart';
import 'transport_guard.dart';
import 'uri_utils.dart';

/// `/api/v1/auth/*` 四个端点的薄封装（不持有会话状态，便于单测）。
class AuthApi {
  AuthApi({
    required this.client,
    required this.baseUri,
    this.timeout = const Duration(seconds: 15),
  });

  final http.Client client;
  final Uri baseUri;
  final Duration timeout;

  Future<TokenPair> loginWithPassword({
    required String password,
    String? label,
  }) async {
    final http.Response response = await _post(
      '/api/v1/auth/login',
      body: <String, Object?>{
        'password': password,
        if (label != null && label.isNotEmpty) 'label': label,
      },
    );
    return TokenPair.fromJson(decodeJsonObject(ensureSuccess(response)));
  }

  Future<TokenPair> refresh(String refreshToken) async {
    final http.Response response = await _post(
      '/api/v1/auth/refresh',
      body: <String, Object?>{'refresh_token': refreshToken},
    );
    return TokenPair.fromJson(decodeJsonObject(ensureSuccess(response)));
  }

  Future<WhoAmI> whoAmI(String bearer) async {
    final http.Response response = await _get(
      '/api/v1/auth/whoami',
      bearer: bearer,
    );
    return WhoAmI.fromJson(decodeJsonObject(ensureSuccess(response)));
  }

  Future<void> logout(String bearer) async {
    final http.Response response = await _post(
      '/api/v1/auth/logout',
      bearer: bearer,
    );
    ensureSuccess(response);
  }

  Map<String, String> _headers(String? bearer) => <String, String>{
    if (bearer != null) 'Authorization': 'Bearer $bearer',
  };

  Future<http.Response> _get(String path, {String? bearer}) => guardTransport(
    () => client.get(resolveUri(baseUri, path), headers: _headers(bearer)),
    timeout: timeout,
  );

  Future<http.Response> _post(String path, {Object? body, String? bearer}) =>
      guardTransport(
        () => client.post(
          resolveUri(baseUri, path),
          headers: <String, String>{
            if (body != null) 'Content-Type': 'application/json',
            ..._headers(bearer),
          },
          body: body == null ? null : jsonEncode(body),
        ),
        timeout: timeout,
      );
}
