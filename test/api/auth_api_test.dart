import 'dart:convert';

import 'package:ehbot_mobile/api/api_exception.dart';
import 'package:ehbot_mobile/api/auth_api.dart';
import 'package:ehbot_mobile/api/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/http_stubs.dart';

void main() {
  final Uri base = Uri.parse('https://ehbot.example.com');
  final Uri prefixed = Uri.parse('https://ehbot.example.com/ehbot');

  AuthApi apiWith(http.Client client, {Uri? baseUri}) =>
      AuthApi(client: client, baseUri: baseUri ?? base);

  test('密码登录：POST /api/v1/auth/login，带 password 与 label', () async {
    late http.Request captured;
    final MockClient client = MockClient((http.Request request) async {
      captured = request;
      return jsonResponse(tokenJson());
    });

    final TokenPair pair = await apiWith(client)
        .loginWithPassword(password: 'hunter2', label: 'Pixel 9');

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/auth/login');
    expect(captured.headers['Content-Type'], contains('application/json'));
    expect(jsonDecode(captured.body), <String, Object?>{
      'password': 'hunter2',
      'label': 'Pixel 9',
    });
    expect(pair.accessToken, 'access-1');
    expect(pair.refreshToken, 'refresh-1');
    expect(pair.expiresIn, 43200);
  });

  test('未改初始密码：403 PASSWORD_CHANGE_REQUIRED 透传为 ApiException', () async {
    final MockClient client = MockClient(
      (http.Request request) async =>
          errorResponse('PASSWORD_CHANGE_REQUIRED', status: 403),
    );

    await expectLater(
      apiWith(client).loginWithPassword(password: 'x'),
      throwsA(
        isA<ApiException>()
            .having(
              (ApiException e) => e.code,
              'code',
              'PASSWORD_CHANGE_REQUIRED',
            )
            .having((ApiException e) => e.statusCode, 'statusCode', 403),
      ),
    );
  });

  test('刷新：POST /api/v1/auth/refresh，带 refresh_token', () async {
    late http.Request captured;
    final MockClient client = MockClient((http.Request request) async {
      captured = request;
      return jsonResponse(tokenJson(access: 'access-2', refresh: 'refresh-2'));
    });

    final TokenPair pair = await apiWith(client).refresh('refresh-1');

    expect(captured.url.path, '/api/v1/auth/refresh');
    expect(jsonDecode(captured.body), <String, Object?>{
      'refresh_token': 'refresh-1',
    });
    expect(pair.refreshToken, 'refresh-2');
  });

  test('whoami：带 Bearer，expires_at 为空表示不过期', () async {
    late http.Request captured;
    final MockClient client = MockClient((http.Request request) async {
      captured = request;
      return jsonResponse(whoAmIJson(kind: 'api_key'));
    });

    final WhoAmI who = await apiWith(client).whoAmI('ehk_abc');

    expect(captured.url.path, '/api/v1/auth/whoami');
    expect(captured.headers['Authorization'], 'Bearer ehk_abc');
    expect(who.username, 'admin');
    expect(who.kind, 'api_key');
    expect(who.expiresAt, isNull);
  });

  test('反代前缀（APP_ROOT_PATH）保留在路径里', () async {
    late http.Request captured;
    final MockClient client = MockClient((http.Request request) async {
      captured = request;
      return jsonResponse(tokenJson());
    });

    await apiWith(client, baseUri: prefixed).loginWithPassword(password: 'x');

    expect(captured.url.path, '/ehbot/api/v1/auth/login');
  });

  test('logout：POST /api/v1/auth/logout，带 Bearer', () async {
    late http.Request captured;
    final MockClient client = MockClient((http.Request request) async {
      captured = request;
      return http.Response('', 204);
    });

    await apiWith(client).logout('access-1');

    expect(captured.url.path, '/api/v1/auth/logout');
    expect(captured.headers['Authorization'], 'Bearer access-1');
  });

  test('传输层异常归一成 NETWORK_FAILURE', () async {
    final MockClient client = MockClient(
      (http.Request request) async =>
          throw http.ClientException('connection refused'),
    );

    await expectLater(
      apiWith(client).loginWithPassword(password: 'x'),
      throwsA(
        isA<ApiException>().having(
          (ApiException e) => e.code,
          'code',
          ApiException.networkFailure,
        ),
      ),
    );
  });
}
