import 'dart:convert';

import 'package:ehbot_mobile/api/api_exception.dart';
import 'package:ehbot_mobile/api/auth_session.dart';
import 'package:ehbot_mobile/state/app_state.dart';
import 'package:ehbot_mobile/state/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/http_stubs.dart';
import '../support/in_memory_thumbnail_cache.dart';
import '../support/in_memory_token_store.dart';

const AppSettings kSettings = AppSettings(
  baseUrl: 'https://ehbot.example.com/ehbot',
);

void primeSettings() {
  SharedPreferences.setMockInitialValues(<String, Object>{
    SettingsStore.storageKey: jsonEncode(kSettings.toJson()),
  });
}

AppState makeState(http.Client client, InMemoryTokenStore tokens) => AppState(
  settingsStore: SettingsStore(),
  tokenStore: tokens,
  thumbnailCache: InMemoryThumbnailCache(),
  clientFactory: (AppSettings _) => client,
);

MockClient happyClient({void Function()? onLogout}) => MockClient((
  http.Request request,
) async {
  switch (request.url.path) {
    case '/ehbot/api/v1/auth/login':
      return jsonResponse(tokenJson());
    case '/ehbot/api/v1/auth/whoami':
      return jsonResponse(whoAmIJson());
    case '/ehbot/api/v1/auth/refresh':
      return jsonResponse(tokenJson(access: 'access-2', refresh: 'refresh-2'));
    case '/ehbot/api/v1/auth/logout':
      onLogout?.call();
      return http.Response('', 204);
  }
  return http.Response('{"detail":"Not Found"}', 404);
});

void main() {
  test('没有配置服务器时进配置页', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppState state = makeState(happyClient(), InMemoryTokenStore());

    await state.bootstrap();

    expect(state.stage, AppStage.serverSetup);
    expect(state.isLoggedIn, isFalse);
  });

  test('保存设置后进登录页，并作废旧凭据', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final InMemoryTokenStore tokens = InMemoryTokenStore()..apiKey = 'ehk_old';
    final AppState state = makeState(happyClient(), tokens);
    await state.bootstrap();

    await state.saveSettings(kSettings);

    expect(state.stage, AppStage.login);
    expect(tokens.apiKey, isNull);
    expect((await SettingsStore().load()).baseUrl, kSettings.baseUrl);
  });

  test('密码登录成功：access 只在内存，refresh 落存储', () async {
    primeSettings();
    final InMemoryTokenStore tokens = InMemoryTokenStore();
    final AppState state = makeState(happyClient(), tokens);
    await state.bootstrap();

    await state.loginWithPassword('hunter2', label: 'Pixel 9');

    expect(state.stage, AppStage.ready);
    expect(state.identity?.username, 'admin');
    expect(state.session?.kind, CredentialKind.password);
    expect(state.session?.accessToken, 'access-1');
    expect(tokens.refreshToken, 'refresh-1');
    expect(tokens.apiKey, isNull);
    expect(state.client, isNotNull);
  });

  test('未改初始密码：403 抛出且不落任何凭据', () async {
    primeSettings();
    final InMemoryTokenStore tokens = InMemoryTokenStore();
    final AppState state = makeState(
      MockClient(
        (http.Request request) async =>
            errorResponse('PASSWORD_CHANGE_REQUIRED', status: 403),
      ),
      tokens,
    );
    await state.bootstrap();

    await expectLater(
      state.loginWithPassword('hunter2'),
      throwsA(
        isA<ApiException>().having(
          (ApiException e) => e.code,
          'code',
          'PASSWORD_CHANGE_REQUIRED',
        ),
      ),
    );
    expect(state.stage, AppStage.login);
    expect(tokens.refreshToken, isNull);
  });

  test('API Key 登录成功：只落 Key，不落 refresh', () async {
    primeSettings();
    final InMemoryTokenStore tokens = InMemoryTokenStore();
    final AppState state = makeState(
      MockClient(
        (http.Request request) async =>
            jsonResponse(whoAmIJson(kind: 'api_key')),
      ),
      tokens,
    );
    await state.bootstrap();

    await state.loginWithApiKey('ehk_abc');

    expect(state.stage, AppStage.ready);
    expect(state.session?.kind, CredentialKind.apiKey);
    expect(state.session?.bearer, 'ehk_abc');
    expect(tokens.apiKey, 'ehk_abc');
    expect(tokens.refreshToken, isNull);
  });

  test('API Key 无效：抛 401 且不落凭据', () async {
    primeSettings();
    final InMemoryTokenStore tokens = InMemoryTokenStore();
    final AppState state = makeState(
      MockClient(
        (http.Request request) async =>
            errorResponse('NOT_AUTHENTICATED', status: 401),
      ),
      tokens,
    );
    await state.bootstrap();

    await expectLater(
      state.loginWithApiKey('ehk_bad'),
      throwsA(
        isA<ApiException>().having(
          (ApiException e) => e.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(state.stage, AppStage.login);
    expect(tokens.apiKey, isNull);
  });

  test('启动时用 API Key 恢复会话', () async {
    primeSettings();
    final InMemoryTokenStore tokens = InMemoryTokenStore()
      ..apiKey = 'ehk_saved';
    final AppState state = makeState(
      MockClient((http.Request request) async {
        expect(request.headers['Authorization'], 'Bearer ehk_saved');
        return jsonResponse(whoAmIJson(kind: 'api_key'));
      }),
      tokens,
    );

    await state.bootstrap();

    expect(state.stage, AppStage.ready);
    expect(state.session?.kind, CredentialKind.apiKey);
  });

  test('启动时用 refresh token 换 access 并轮换 refresh', () async {
    primeSettings();
    final InMemoryTokenStore tokens = InMemoryTokenStore()
      ..refreshToken = 'refresh-1';
    bool refreshed = false;
    final AppState state = makeState(
      MockClient((http.Request request) async {
        switch (request.url.path) {
          case '/ehbot/api/v1/auth/refresh':
            refreshed = true;
            expect(jsonDecode(request.body)['refresh_token'], 'refresh-1');
            return jsonResponse(
              tokenJson(access: 'access-2', refresh: 'refresh-2'),
            );
          case '/ehbot/api/v1/auth/whoami':
            expect(request.headers['Authorization'], 'Bearer access-2');
            return jsonResponse(whoAmIJson());
        }
        return http.Response('{}', 404);
      }),
      tokens,
    );

    await state.bootstrap();

    expect(refreshed, isTrue);
    expect(state.stage, AppStage.ready);
    expect(state.session?.accessToken, 'access-2');
    expect(tokens.refreshToken, 'refresh-2');
  });

  test('refresh 被拒：清凭据、回登录页并给提示', () async {
    primeSettings();
    final InMemoryTokenStore tokens = InMemoryTokenStore()
      ..refreshToken = 'refresh-1';
    final AppState state = makeState(
      MockClient(
        (http.Request request) async =>
            errorResponse('AUTH_TOKEN_REVOKED', status: 401),
      ),
      tokens,
    );

    await state.bootstrap();

    expect(state.stage, AppStage.login);
    expect(tokens.refreshToken, isNull);
    expect(state.notice, isNotNull);
  });

  test('密码会话退出登录：通知后端吊销并清空本地', () async {
    primeSettings();
    final InMemoryTokenStore tokens = InMemoryTokenStore();
    bool logoutCalled = false;
    final AppState state = makeState(
      happyClient(onLogout: () => logoutCalled = true),
      tokens,
    );
    await state.bootstrap();
    await state.loginWithPassword('hunter2');

    await state.logout();

    expect(logoutCalled, isTrue);
    expect(tokens.refreshToken, isNull);
    expect(state.stage, AppStage.login);
    expect(state.session, isNull);
    expect(state.identity, isNull);
  });

  test('API Key 会话退出：不发 logout 请求（族隔离）', () async {
    primeSettings();
    final InMemoryTokenStore tokens = InMemoryTokenStore()..apiKey = 'ehk_abc';
    bool logoutCalled = false;
    final AppState state = makeState(
      MockClient((http.Request request) async {
        if (request.url.path.endsWith('/auth/logout')) {
          logoutCalled = true;
          return http.Response('', 204);
        }
        return jsonResponse(whoAmIJson(kind: 'api_key'));
      }),
      tokens,
    );
    await state.bootstrap();

    await state.logout();

    expect(logoutCalled, isFalse);
    expect(tokens.apiKey, isNull);
    expect(state.stage, AppStage.login);
  });
}
