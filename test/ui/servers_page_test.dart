import 'dart:convert';

import 'package:ehbot_mobile/state/app_state.dart';
import 'package:ehbot_mobile/state/server_store.dart';
import 'package:ehbot_mobile/state/settings.dart';
import 'package:ehbot_mobile/ui/server_setup_page.dart';
import 'package:ehbot_mobile/ui/servers_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_thumbnail_cache.dart';
import '../support/in_memory_token_store.dart';

MockClient notFound() => MockClient(
  (http.Request request) async =>
      http.Response('{"error":{"code":"NOT_FOUND","message":"x"}}', 404),
);

Map<String, Object?> profileJson(String id, String url, {String label = ''}) =>
    <String, Object?>{
      'id': id,
      'label': label,
      'settings': AppSettings(baseUrl: url).toJson(),
    };

Future<AppState> twoServers({String active = 'a'}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    ServerStore.storageKey: jsonEncode(<Map<String, Object?>>[
      profileJson('a', 'https://a.example.com', label: '家里盒子'),
      profileJson('b', 'https://b.example.com', label: '云主机'),
    ]),
    ServerStore.activeKey: active,
  });
  final AppState state = AppState(
    settingsStore: SettingsStore(),
    serverStore: ServerStore(),
    tokenStore: InMemoryTokenStore(),
    thumbnailCache: InMemoryThumbnailCache(),
    clientFactory: (AppSettings _) => notFound(),
  );
  await state.bootstrap();
  return state;
}

void main() {
  testWidgets('服务器页列出所有档案并标出当前', (WidgetTester tester) async {
    final AppState state = await twoServers();
    await tester.pumpWidget(MaterialApp(home: ServersPage(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('家里盒子'), findsOneWidget);
    expect(find.text('云主机'), findsOneWidget);
    expect(find.text('https://a.example.com'), findsOneWidget);
    // 当前那台显示实心勾。
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('点另一台服务器会切换并自动返回', (WidgetTester tester) async {
    final AppState state = await twoServers();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext _) => ServersPage(state: state),
                  ),
                ),
                child: const Text('打开服务器'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开服务器'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('云主机'));
    await tester.pumpAndSettle();

    expect(state.activeServerId, 'b');
    expect(state.settings.baseUrl, 'https://b.example.com');
    expect(find.byType(ServersPage), findsNothing);
  });

  testWidgets('右上角 + 进入添加服务器表单', (WidgetTester tester) async {
    final AppState state = await twoServers();
    await tester.pumpWidget(MaterialApp(home: ServersPage(state: state)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('servers-add')));
    await tester.pumpAndSettle();

    expect(find.byType(ServerSetupPage), findsOneWidget);
    expect(find.text('添加服务器'), findsOneWidget);
  });

  testWidgets('删除当前服务器后回落到剩下那台', (WidgetTester tester) async {
    final AppState state = await twoServers();
    await tester.pumpWidget(MaterialApp(home: ServersPage(state: state)));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('server-menu-a')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(state.servers, hasLength(1));
    expect(state.activeServerId, 'b');
    expect(find.text('家里盒子'), findsNothing);
  });
}
