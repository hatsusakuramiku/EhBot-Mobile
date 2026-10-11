import 'package:ehbot_mobile/state/app_state.dart';
import 'package:ehbot_mobile/state/settings.dart';
import 'package:ehbot_mobile/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../support/http_stubs.dart';
import '../support/in_memory_thumbnail_cache.dart';
import '../support/in_memory_token_store.dart';

Future<AppState> makeBootstrappedState(http.Client client) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    SettingsStore.storageKey: '{"base_url":"https://ehbot.example.com"}',
  });
  final AppState state = AppState(
    settingsStore: SettingsStore(),
    tokenStore: InMemoryTokenStore()..apiKey = 'ehk_x',
    thumbnailCache: InMemoryThumbnailCache(),
    clientFactory: (AppSettings _) => client,
  );
  await state.bootstrap();
  return state;
}

void main() {
  testWidgets('设置页展示多个分区与退出按钮', (WidgetTester tester) async {
    final http.Client client = fakeBackend();
    final AppState state = await makeBootstrappedState(client);
    await tester.pumpWidget(MaterialApp(home: SettingsPage(state: state)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('当前凭据'), 100);
    expect(find.text('当前凭据'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('服务器'), 100);
    expect(find.text('服务器'), findsOneWidget);
    // 服务器那一块是通往 ServersPage 的入口（可编辑、可切换多台）。
    expect(
      find.byKey(const ValueKey<String>('settings-open-servers')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('后端分区设置'), 100);
    expect(find.text('后端分区设置'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('外部服务'), 200);
    expect(find.text('外部服务'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('settings-logout')),
      100,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-logout')),
      findsOneWidget,
    );
  });
}
