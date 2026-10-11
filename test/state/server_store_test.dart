import 'dart:convert';

import 'package:ehbot_mobile/state/app_state.dart';
import 'package:ehbot_mobile/state/server_store.dart';
import 'package:ehbot_mobile/state/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_thumbnail_cache.dart';
import '../support/in_memory_token_store.dart';

MockClient notFoundClient() => MockClient(
  (http.Request request) async =>
      http.Response('{"error":{"code":"NOT_FOUND","message":"x"}}', 404),
);

AppState makeState({
  MockClient? client,
  InMemoryTokenStore? tokens,
}) => AppState(
  settingsStore: SettingsStore(),
  serverStore: ServerStore(),
  tokenStore: tokens ?? InMemoryTokenStore(),
  thumbnailCache: InMemoryThumbnailCache(),
  clientFactory: (AppSettings _) => client ?? notFoundClient(),
);

Map<String, Object?> profileJson(String id, String url, {String label = ''}) =>
    <String, Object?>{
      'id': id,
      'label': label,
      'settings': AppSettings(baseUrl: url).toJson(),
    };

void main() {
  test('旧版单服务器设置会迁移成一条档案（无感升级）', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SettingsStore.storageKey: jsonEncode(
        const AppSettings(baseUrl: 'https://old.example.com').toJson(),
      ),
    });
    final AppState state = makeState();

    await state.bootstrap();

    expect(state.servers, hasLength(1));
    expect(state.activeServerId, isNotNull);
    expect(state.settings.baseUrl, 'https://old.example.com');
    expect(state.activeServer?.effectiveLabel, 'old.example.com');
    // 已落盘：第二次读能拿到。
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ServerStore.storageKey), isNotNull);
    expect(prefs.getString(ServerStore.activeKey), state.activeServerId);
    expect(state.stage, AppStage.login);
  });

  test('多档案时按 active id 选中对应服务器', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ServerStore.storageKey: jsonEncode(<Map<String, Object?>>[
        profileJson('a', 'https://a.example.com'),
        profileJson('b', 'https://b.example.com'),
      ]),
      ServerStore.activeKey: 'b',
    });
    final AppState state = makeState();

    await state.bootstrap();

    expect(state.servers, hasLength(2));
    expect(state.activeServerId, 'b');
    expect(state.settings.baseUrl, 'https://b.example.com');
  });

  test('active id 失效时回落到第一条档案', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ServerStore.storageKey: jsonEncode(<Map<String, Object?>>[
        profileJson('a', 'https://a.example.com'),
        profileJson('b', 'https://b.example.com'),
      ]),
      ServerStore.activeKey: 'gone',
    });
    final AppState state = makeState();

    await state.bootstrap();

    expect(state.activeServerId, 'a');
    expect(state.settings.baseUrl, 'https://a.example.com');
  });

  test('切换服务器会登出并落到另一台的登录页', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ServerStore.storageKey: jsonEncode(<Map<String, Object?>>[
        profileJson('a', 'https://a.example.com'),
        profileJson('b', 'https://b.example.com'),
      ]),
      ServerStore.activeKey: 'a',
    });
    final InMemoryTokenStore tokens = InMemoryTokenStore()..apiKey = 'ehk_x';
    final AppState state = makeState(tokens: tokens);
    await state.bootstrap();
    expect(state.activeServerId, 'a');

    await state.switchServer('b');

    expect(state.activeServerId, 'b');
    expect(state.settings.baseUrl, 'https://b.example.com');
    expect(state.stage, AppStage.login);
    expect(tokens.clearCount, greaterThan(0));
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ServerStore.activeKey), 'b');
  });

  test('删除当前服务器后回落到剩下那条', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ServerStore.storageKey: jsonEncode(<Map<String, Object?>>[
        profileJson('a', 'https://a.example.com'),
        profileJson('b', 'https://b.example.com'),
      ]),
      ServerStore.activeKey: 'a',
    });
    final AppState state = makeState();
    await state.bootstrap();

    await state.removeServer('a');

    expect(state.servers, hasLength(1));
    expect(state.activeServerId, 'b');
    expect(state.settings.baseUrl, 'https://b.example.com');
  });

  test('重命名档案只改标签', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ServerStore.storageKey: jsonEncode(<Map<String, Object?>>[
        profileJson('a', 'https://a.example.com'),
      ]),
      ServerStore.activeKey: 'a',
    });
    final AppState state = makeState();
    await state.bootstrap();

    await state.renameServer('a', '家里的盒子');

    expect(state.activeServer?.label, '家里的盒子');
    expect(state.settings.baseUrl, 'https://a.example.com');
  });
}
