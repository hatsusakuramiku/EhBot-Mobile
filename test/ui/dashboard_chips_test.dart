import 'package:ehbot_mobile/api/ehbot_api.dart';
import 'package:ehbot_mobile/media/thumbnail_loader.dart';
import 'package:ehbot_mobile/ui/candidate_detail_page.dart';
import 'package:ehbot_mobile/ui/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

void main() {
  testWidgets('仪表盘 chip 点击触发 onOpenCandidates 与切 tab', (
    WidgetTester tester,
  ) async {
    final http.Client client = fakeBackend();
    final EhBotApi api = apiWith(client);
    final ThumbnailLoader thumbnails = thumbnailsWith(client);
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardPage(
            api: api,
            thumbnails: thumbnails,
            onOpenCandidates: (String tab) => opened = tab,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('dashboard-chip-pending_review')),
    );
    await tester.pump();

    expect(opened, 'pending_review');
  });

  testWidgets('“需审查”行 onTap 推送 CandidateDetailPage', (
    WidgetTester tester,
  ) async {
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

    final Finder attn = find.byKey(const ValueKey<String>('dashboard-attn-77'));
    expect(attn, findsOneWidget);
    await tester.tap(attn);
    await tester.pumpAndSettle();

    expect(find.byType(CandidateDetailPage), findsOneWidget);
  });
}
