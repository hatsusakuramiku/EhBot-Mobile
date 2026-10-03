import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_session.dart';
import 'transport_guard.dart';
import 'uri_utils.dart';

/// 数据端点的带鉴权客户端：自动加 `Authorization`，401 时按凭据族分流
/// （`CONTRACT.md` §4）：密码族用 refresh 换一次并重放；API Key 族不刷新。
class AuthClient {
  AuthClient({
    required this.inner,
    required this.baseUri,
    required this.session,
    required this.onSessionExpired,
    this.timeout = const Duration(seconds: 15),
  });

  final http.Client inner;
  final Uri baseUri;
  final AuthSession session;
  final Duration timeout;

  /// refresh 失败、或重放后仍 401 时回调（界面据此回登录页）。
  final void Function() onSessionExpired;

  /// 用 refresh token 换新 access；由 `AppState` 注入，避免 api 层反向依赖端点细节。
  Future<void> Function(AuthSession session)? refreshHook;

  Future<http.Response> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) => _run(
    (auth) => inner.get(
      resolveUri(baseUri, path, query),
      headers: <String, String>{...?headers, ...auth},
    ),
  );

  Future<http.Response> postJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => _run(
    (auth) => inner.post(
      resolveUri(baseUri, path),
      headers: <String, String>{
        'Content-Type': 'application/json',
        ...?headers,
        ...auth,
      },
      body: body == null ? null : jsonEncode(body),
    ),
  );

  /// 取流（SSE 等长连接）。超时只作用于「拿到响应头」，不影响后续流。
  Future<http.StreamedResponse> stream(
    String path, {
    Map<String, String>? headers,
  }) async {
    Future<http.StreamedResponse> attempt() => inner.send(
      http.Request('GET', resolveUri(baseUri, path))
        ..headers.addAll(<String, String>{...?headers, ..._authHeaders()}),
    );

    http.StreamedResponse response = await guardTransport(
      attempt,
      timeout: timeout,
    );
    if (response.statusCode != 401) {
      return response;
    }
    if (session.kind == CredentialKind.apiKey) {
      return response;
    }
    final Future<void> Function(AuthSession)? refresh = refreshHook;
    if (refresh == null || session.refreshToken == null) {
      onSessionExpired();
      return response;
    }
    try {
      await refresh(session);
    } on Object {
      onSessionExpired();
      return response;
    }
    response = await guardTransport(attempt, timeout: timeout);
    if (response.statusCode == 401) {
      onSessionExpired();
    }
    return response;
  }

  Future<http.Response> patchJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => _run(
    (auth) => inner.patch(
      resolveUri(baseUri, path),
      headers: <String, String>{
        'Content-Type': 'application/json',
        ...?headers,
        ...auth,
      },
      body: body == null ? null : jsonEncode(body),
    ),
  );

  Future<http.Response> _run(
    Future<http.Response> Function(Map<String, String> authHeaders) attempt,
  ) async {
    http.Response response = await guardTransport(
      () => attempt(_authHeaders()),
      timeout: timeout,
    );
    if (response.statusCode != 401) {
      return response;
    }
    if (session.kind == CredentialKind.apiKey) {
      return response;
    }
    final Future<void> Function(AuthSession)? refresh = refreshHook;
    if (refresh == null || session.refreshToken == null) {
      onSessionExpired();
      return response;
    }
    try {
      await refresh(session);
    } on Object {
      onSessionExpired();
      return response;
    }
    response = await guardTransport(
      () => attempt(_authHeaders()),
      timeout: timeout,
    );
    if (response.statusCode == 401) {
      onSessionExpired();
    }
    return response;
  }

  Map<String, String> _authHeaders() {
    final String? bearer = session.bearer;
    return <String, String>{
      if (bearer != null) 'Authorization': 'Bearer $bearer',
    };
  }
}
