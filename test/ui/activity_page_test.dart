import 'package:ehbot_mobile/api/ehbot_api.dart';
import 'package:ehbot_mobile/ui/activity_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

void main() {
  testWidgets('活动页渲染队列分组与历史', (WidgetTester tester) async {
    final EhBotApi api = apiWith(fakeBackend());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActivityPage(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('activity-downloads')),
      findsOneWidget,
    );
    expect(find.text('下载中 1'), findsOneWidget);
    expect(find.text('进行中（1）'), findsOneWidget);
    expect(find.text('历史（1）'), findsOneWidget);
    expect(find.text('已完成'), findsWidgets);
  });
}
