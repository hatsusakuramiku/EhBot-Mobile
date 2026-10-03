import 'package:ehbot_mobile/state/app_state.dart';
import 'package:ehbot_mobile/state/settings.dart';
import 'package:ehbot_mobile/ui/server_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_thumbnail_cache.dart';
import '../support/in_memory_token_store.dart';

Future<AppState> pumpSetupPage(WidgetTester tester, http.Client client) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppState state = AppState(
    settingsStore: SettingsStore(),
    tokenStore: InMemoryTokenStore(),
    thumbnailCache: InMemoryThumbnailCache(),
    clientFactory: (AppSettings _) => client,
  );
  await tester.pumpWidget(MaterialApp(home: ServerSetupPage(state: state)));
  return state;
}

void main() {
  testWidgets('非法地址保存被拦下并提示', (WidgetTester tester) async {
    await pumpSetupPage(
      tester,
      MockClient((http.Request request) async => http.Response('{}', 200)),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('server-url')),
      'ehbot.example.com',
    );
    await tester.tap(find.byKey(const ValueKey<String>('server-save')));
    await tester.pumpAndSettle();

    expect(find.text('地址要以 http:// 或 https:// 开头。'), findsOneWidget);
  });

  testWidgets('输入明文 http 显示告警，未勾选时不能保存', (WidgetTester tester) async {
    await pumpSetupPage(
      tester,
      MockClient((http.Request request) async => http.Response('{}', 200)),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('server-url')),
      'http://192.168.1.5:8000',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('当前是明文 http'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('server-save')));
    await tester.pumpAndSettle();
    expect(find.text('明文 http 需要勾选「允许明文（不安全）」。'), findsOneWidget);
  });

  testWidgets('测试连接显示探测结果', (WidgetTester tester) async {
    await pumpSetupPage(
      tester,
      MockClient((http.Request request) async {
        if (request.url.path == '/healthz') {
          return http.Response('ok', 200);
        }
        return http.Response('{"error":{"code":"NOT_AUTHENTICATED"}}', 401);
      }),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('server-url')),
      'https://ehbot.example.com',
    );
    await tester.tap(find.byKey(const ValueKey<String>('server-test')));
    await tester.pumpAndSettle();

    expect(find.text('服务器可达，移动端鉴权已启用。'), findsOneWidget);
  });
}
