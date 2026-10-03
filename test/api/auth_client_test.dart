import 'package:ehbot_mobile/api/api_exception.dart';
import 'package:ehbot_mobile/api/auth_client.dart';
import 'package:ehbot_mobile/api/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final Uri base = Uri.parse('https://ehbot.example.com');

  test('请求带上 Bearer access token', () async {
    late http.Request captured;
    final MockClient client = MockClient((http.Request request) async {
      captured = request;
      return http.Response('{"ok":true}', 200);
    });
    final AuthClient auth = AuthClient(
      inner: client,
      baseUri: base,
      session: AuthSession.password(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      ),
      onSessionExpired: () {},
    );

    await auth.get('/api/v1/summary');

    expect(captured.headers['Authorization'], 'Bearer access-1');
    expect(captured.url.path, '/api/v1/summary');
  });

  test('401 → 刷新一次 → 用新 access 重放', () async {
    int protectedCalls = 0;
    final MockClient client = MockClient((http.Request request) async {
      protectedCalls += 1;
      final String? auth = request.headers['Authorization'];
      if (auth == 'Bearer access-2') {
        return http.Response('{"ok":true}', 200);
      }
      return http.Response('{"error":{"code":"NOT_AUTHENTICATED"}}', 401);
    });
    final AuthSession session = AuthSession.password(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    bool expired = false;
    int refreshes = 0;
    final AuthClient client2 =
        AuthClient(
            inner: client,
            baseUri: base,
            session: session,
            onSessionExpired: () => expired = true,
          )
          ..refreshHook = (AuthSession s) async {
            refreshes += 1;
            s.updateTokens(access: 'access-2', refresh: 'refresh-2');
          };

    final http.Response response = await client2.get('/api/v1/summary');

    expect(response.statusCode, 200);
    expect(protectedCalls, 2);
    expect(refreshes, 1);
    expect(expired, isFalse);
    expect(session.accessToken, 'access-2');
  });

  test('刷新失败 → 回调 onSessionExpired 并返回原 401', () async {
    int protectedCalls = 0;
    final MockClient client = MockClient((http.Request request) async {
      protectedCalls += 1;
      return http.Response('{"error":{"code":"NOT_AUTHENTICATED"}}', 401);
    });
    bool expired = false;
    final AuthClient auth =
        AuthClient(
            inner: client,
            baseUri: base,
            session: AuthSession.password(
              accessToken: 'access-1',
              refreshToken: 'refresh-1',
            ),
            onSessionExpired: () => expired = true,
          )
          ..refreshHook = (AuthSession s) async {
            throw const ApiException(
              code: 'AUTH_TOKEN_REVOKED',
              message: 'rejected',
            );
          };

    final http.Response response = await auth.get('/api/v1/summary');

    expect(response.statusCode, 401);
    expect(protectedCalls, 1);
    expect(expired, isTrue);
  });

  test('重放后仍 401 → 回调 onSessionExpired', () async {
    final MockClient client = MockClient(
      (http.Request request) async =>
          http.Response('{"error":{"code":"NOT_AUTHENTICATED"}}', 401),
    );
    bool expired = false;
    final AuthClient auth =
        AuthClient(
            inner: client,
            baseUri: base,
            session: AuthSession.password(
              accessToken: 'access-1',
              refreshToken: 'refresh-1',
            ),
            onSessionExpired: () => expired = true,
          )
          ..refreshHook = (AuthSession s) async {
            s.updateTokens(access: 'access-2', refresh: 'refresh-2');
          };

    await auth.get('/api/v1/summary');

    expect(expired, isTrue);
  });

  test('API Key 收到 401：不刷新、不回调，交给界面提示', () async {
    int calls = 0;
    final MockClient client = MockClient((http.Request request) async {
      calls += 1;
      return http.Response('{"error":{"code":"NOT_AUTHENTICATED"}}', 401);
    });
    bool expired = false;
    bool refreshed = false;
    final AuthClient auth = AuthClient(
      inner: client,
      baseUri: base,
      session: AuthSession.apiKey('ehk_abc'),
      onSessionExpired: () => expired = true,
    )..refreshHook = (AuthSession s) async => refreshed = true;

    final http.Response response = await auth.get('/api/v1/summary');

    expect(response.statusCode, 401);
    expect(calls, 1);
    expect(refreshed, isFalse);
    expect(expired, isFalse);
  });

  test('传输层异常归一成 NETWORK_FAILURE', () async {
    final MockClient client = MockClient(
      (http.Request request) async => throw http.ClientException('boom'),
    );
    final AuthClient auth = AuthClient(
      inner: client,
      baseUri: base,
      session: AuthSession.apiKey('ehk_abc'),
      onSessionExpired: () {},
    );

    await expectLater(
      auth.get('/api/v1/summary'),
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
