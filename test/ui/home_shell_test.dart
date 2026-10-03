import 'dart:convert';

import 'package:ehbot_mobile/state/app_state.dart';
import 'package:ehbot_mobile/state/settings.dart';
import 'package:ehbot_mobile/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/http_stubs.dart';
import '../support/in_memory_thumbnail_cache.dart';
import '../support/in_memory_token_store.dart';

void main() {
  testWidgets('登录后看到四页外壳并落在工作台', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SettingsStore.storageKey: jsonEncode(
        const AppSettings(baseUrl: 'https://ehbot.example.com').toJson(),
      ),
    });
    final AppState state = AppState(
      settingsStore: SettingsStore(),
      tokenStore: InMemoryTokenStore()..apiKey = 'ehk_x',
      thumbnailCache: InMemoryThumbnailCache(),
      clientFactory: (AppSettings _) => fakeBackend(),
    );

    await state.bootstrap();
    await tester.pumpWidget(EhBotApp(state: state));
    await tester.pumpAndSettle();

    final Finder nav = find.byType(NavigationBar);
    expect(nav, findsOneWidget);
    for (final String label in <String>['工作台', '候选', '活动', '已下载']) {
      expect(
        find.descendant(of: nav, matching: find.text(label)),
        findsOneWidget,
        reason: '导航栏缺少 $label',
      );
    }
    expect(find.byKey(const ValueKey<String>('summary-total')), findsOneWidget);
  });
}
