import 'package:ehbot_mobile/api/ehbot_api.dart';
import 'package:ehbot_mobile/media/thumbnail_loader.dart';
import 'package:ehbot_mobile/ui/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

void main() {
  testWidgets('工作台渲染候选计数、活动与需干预', (WidgetTester tester) async {
    final http.Client client = fakeBackend();
    final EhBotApi api = apiWith(client);
    final ThumbnailLoader thumbnails = thumbnailsWith(client);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardPage(api: api, thumbnails: thumbnails),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('summary-total')), findsOneWidget);
    expect(find.text('共 7 个'), findsOneWidget);
    expect(find.text('待审核 3'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('需干预（1）'), findsOneWidget);
    expect(find.text('候选 #11'), findsOneWidget);
  });

  testWidgets('工作台请求失败时给中文错误与重试', (WidgetTester tester) async {
    final http.Client client = fakeBackendFailure();
    final EhBotApi api = apiWith(client);
    final ThumbnailLoader thumbnails = thumbnailsWith(client);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardPage(api: api, thumbnails: thumbnails),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('服务器暂时不可用'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}
