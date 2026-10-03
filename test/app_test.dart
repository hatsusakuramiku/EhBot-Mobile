import 'package:ehbot_mobile/state/app_state.dart';
import 'package:ehbot_mobile/state/settings.dart';
import 'package:ehbot_mobile/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/in_memory_thumbnail_cache.dart';
import 'support/in_memory_token_store.dart';

AppState makeState() => AppState(
  settingsStore: SettingsStore(),
  tokenStore: InMemoryTokenStore(),
  thumbnailCache: InMemoryThumbnailCache(),
  clientFactory: (AppSettings _) =>
      MockClient((http.Request request) async => http.Response('{}', 200)),
);

void main() {
  testWidgets('loading 阶段显示进度指示器', (WidgetTester tester) async {
    await tester.pumpWidget(EhBotApp(state: makeState()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('没有服务器设置时进「连接服务器」页', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppState state = makeState();

    await state.bootstrap();
    await tester.pumpWidget(EhBotApp(state: state));
    await tester.pump();

    expect(find.text('连接服务器'), findsOneWidget);
  });
}
