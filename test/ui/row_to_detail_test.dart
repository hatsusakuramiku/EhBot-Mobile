import 'package:ehbot_mobile/api/ehbot_api.dart';
import 'package:ehbot_mobile/media/thumbnail_loader.dart';
import 'package:ehbot_mobile/ui/activity_page.dart';
import 'package:ehbot_mobile/ui/candidate_detail_page.dart';
import 'package:ehbot_mobile/ui/candidates_page.dart';
import 'package:ehbot_mobile/ui/downloaded_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

Future<void> pumpToDetail(
  WidgetTester tester,
  Widget page,
  String tileKey,
) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey<String>(tileKey)));
  await tester.pumpAndSettle();
  expect(find.byType(CandidateDetailPage), findsOneWidget);
}

void main() {
  testWidgets('候选列表行 onTap 推送候选详情', (WidgetTester tester) async {
    final http.Client client = fakeBackend();
    final EhBotApi api = apiWith(client);
    final ThumbnailLoader thumbnails = thumbnailsWith(client);
    await pumpToDetail(
      tester,
      CandidatesPage(api: api, thumbnails: thumbnails),
      'candidate-11',
    );
  });

  testWidgets('活动 job 点击推送详情', (WidgetTester tester) async {
    final http.Client client = fakeBackend();
    final EhBotApi api = apiWith(client);
    final ThumbnailLoader thumbnails = thumbnailsWith(client);
    await pumpToDetail(
      tester,
      ActivityPage(api: api, thumbnails: thumbnails),
      'activity-job-77',
    );
  });

  testWidgets('已下载行 onTap 推送详情', (WidgetTester tester) async {
    final http.Client client = fakeBackend();
    final EhBotApi api = apiWith(client);
    final ThumbnailLoader thumbnails = thumbnailsWith(client);
    await pumpToDetail(
      tester,
      DownloadedListPage(api: api, thumbnails: thumbnails),
      'downloaded-11',
    );
  });
}
