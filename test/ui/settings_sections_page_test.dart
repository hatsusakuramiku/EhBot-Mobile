import 'package:ehbot_mobile/ui/settings_sections_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

void main() {
  testWidgets('设置分区中心列出全部九区', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsSectionsPage(
          api: apiWith(
            MockClient(
              (http.Request request) async =>
                  jsonResponse(<String, Object?>{'ok': true}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(kSettingsSections, hasLength(9));
    for (final SettingsSection s in kSettingsSections) {
      expect(
        find.byKey(ValueKey<String>('settings-section-${s.code}')),
        findsOneWidget,
        reason: '缺少分区 ${s.code}',
      );
    }
  });

  testWidgets('后端返回数据时按 key/value 渲染', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsSectionView(
          api: apiWith(
            MockClient(
              (http.Request request) async => jsonResponse(<String, Object?>{
                'torrent_enabled': true,
                'limits': <String, Object?>{'max_depth': 3},
              }),
            ),
          ),
          section: kSettingsSections.first,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('外部连接'), findsWidgets);
    expect(find.text('torrent_enabled'), findsOneWidget);
    expect(find.text('limits.max_depth'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('后端未实现时给出 404 说明', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsSectionView(
          api: apiWith(
            MockClient(
              (http.Request request) async =>
                  errorResponse('NOT_FOUND', status: 404, message: 'no route'),
            ),
          ),
          section: kSettingsSections.first,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('后端还没有'), findsOneWidget);
  });
}
