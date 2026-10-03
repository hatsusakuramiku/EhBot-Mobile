import 'package:ehbot_mobile/api/ehbot_api.dart';
import 'package:ehbot_mobile/ui/downloaded_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

void main() {
  testWidgets('已下载页渲染列表', (WidgetTester tester) async {
    final EhBotApi api = apiWith(fakeBackend());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DownloadedListPage(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已下载本'), findsOneWidget);
    expect(find.text('共 1 个'), findsOneWidget);
    expect(find.text('已打包'), findsOneWidget);
  });
}
