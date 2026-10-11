import 'dart:convert';

import 'package:ehbot_mobile/state/app_state.dart';
import 'package:ehbot_mobile/state/settings.dart';
import 'package:ehbot_mobile/state/theme_store.dart';
import 'package:ehbot_mobile/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/http_stubs.dart';
import '../support/in_memory_thumbnail_cache.dart';
import '../support/in_memory_token_store.dart';

Future<AppState> bootstrapped() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    SettingsStore.storageKey: jsonEncode(
      const AppSettings(baseUrl: 'https://ehbot.example.com').toJson(),
    ),
  });
  final AppState state = AppState(
    settingsStore: SettingsStore(),
    tokenStore: InMemoryTokenStore(),
    thumbnailCache: InMemoryThumbnailCache(),
    clientFactory: (AppSettings _) => fakeBackend(),
  );
  await state.bootstrap();
  return state;
}

void main() {
  test('默认外观为跟随系统 + 默认 seed', () async {
    final AppState state = await bootstrapped();
    expect(state.themeSettings.mode, ThemeMode.system);
    expect(state.themeSettings.seed, ThemeSettings.kDefaultSeed);
  });

  test('切换主题模式与配色会持久化', () async {
    final AppState state = await bootstrapped();

    await state.setThemeMode(ThemeMode.dark);
    await state.setSeedColor(ThemeSettings.presets.last);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeStore.modeKey), 'dark');
    expect(
      prefs.getInt(ThemeStore.seedKey),
      ThemeSettings.presets.last.toARGB32(),
    );

    // 重新加载能读回（注意不要再 setMockInitialValues，否则会清空存储）。
    final AppState reloaded = AppState(
      settingsStore: SettingsStore(),
      tokenStore: InMemoryTokenStore(),
      thumbnailCache: InMemoryThumbnailCache(),
      clientFactory: (AppSettings _) => fakeBackend(),
    );
    await reloaded.bootstrap();
    expect(reloaded.themeSettings.mode, ThemeMode.dark);
    expect(reloaded.themeSettings.seed, ThemeSettings.presets.last);
  });

  testWidgets('设置页外观区暴露模式与配色控件', (WidgetTester tester) async {
    final AppState state = await bootstrapped();
    await tester.pumpWidget(MaterialApp(home: SettingsPage(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('外观'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('appearance-mode')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey<String>(
          'appearance-swatch-${ThemeSettings.presets.first.toARGB32()}',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        ValueKey<String>(
          'appearance-swatch-${ThemeSettings.presets[3].toARGB32()}',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(state.themeSettings.seed, ThemeSettings.presets[3]);
  });
}
