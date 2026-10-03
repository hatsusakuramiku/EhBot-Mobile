import 'dart:convert';

import 'package:ehbot_mobile/state/app_state.dart';
import 'package:ehbot_mobile/state/settings.dart';
import 'package:ehbot_mobile/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/http_stubs.dart';
import '../support/in_memory_thumbnail_cache.dart';
import '../support/in_memory_token_store.dart';

const AppSettings kSettings = AppSettings(baseUrl: 'https://ehbot.example.com');

Future<AppState> pumpLoginPage(WidgetTester tester, http.Client client) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    SettingsStore.storageKey: jsonEncode(kSettings.toJson()),
  });
  final AppState state = AppState(
    settingsStore: SettingsStore(),
    tokenStore: InMemoryTokenStore(),
    thumbnailCache: InMemoryThumbnailCache(),
    clientFactory: (AppSettings _) => client,
  );
  await state.bootstrap();
  await tester.pumpWidget(EhBotApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('登录页有密码与 API Key 两个 tab', (WidgetTester tester) async {
    await pumpLoginPage(
      tester,
      MockClient((http.Request request) async => http.Response('{}', 404)),
    );

    expect(
      find.byKey(const ValueKey<String>('login-password')),
      findsOneWidget,
    );
    expect(find.widgetWithText(Tab, '密码'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'API Key'), findsOneWidget);
  });

  testWidgets('密码错误显示中文提示且留在登录页', (WidgetTester tester) async {
    await pumpLoginPage(
      tester,
      MockClient(
        (http.Request request) async =>
            errorResponse('AUTH_INVALID_CREDENTIALS', status: 401),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('login-password')),
      'wrong-password',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('login-submit-password')),
    );
    await tester.pumpAndSettle();

    expect(find.text('密码不正确，请重试。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('login-password')),
      findsOneWidget,
    );
  });

  testWidgets('API Key 无效显示重新粘贴提示', (WidgetTester tester) async {
    await pumpLoginPage(
      tester,
      MockClient(
        (http.Request request) async =>
            errorResponse('NOT_AUTHENTICATED', status: 401),
      ),
    );

    await tester.tap(find.widgetWithText(Tab, 'API Key'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('login-apikey')),
      'ehk_bad',
    );
    await tester.tap(find.byKey(const ValueKey<String>('login-submit-apikey')));
    await tester.pumpAndSettle();

    expect(find.textContaining('API Key 无效'), findsOneWidget);
  });
}
