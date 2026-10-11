import 'package:ehbot_mobile/api/ehbot_api.dart';
import 'package:ehbot_mobile/api/models.dart';
import 'package:ehbot_mobile/media/thumbnail_loader.dart';
import 'package:ehbot_mobile/ui/candidate_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

Map<String, Object?> detailWith(Map<String, Object?> actions) =>
    <String, Object?>{...workDetailJson(), 'actions': actions};

MockClient backendWithDetail(Map<String, Object?> body) =>
    MockClient((http.Request request) async {
      if (request.url.path.contains('/thumbnails/')) {
        return tinyPngResponse();
      }
      if (request.url.path.endsWith('/summary')) {
        return jsonResponse(summaryJson());
      }
      if (request.url.path.endsWith('/auth/whoami')) {
        return jsonResponse(whoAmIJson(kind: 'api_key'));
      }
      if (request.url.path.contains('/works/')) {
        return jsonResponse(body);
      }
      return http.Response('{"error":{"code":"NOT_FOUND","message":"x"}}', 404);
    });

Future<void> pump(WidgetTester tester, MockClient client) async {
  final EhBotApi api = apiWith(client);
  final ThumbnailLoader thumbnails = thumbnailsWith(client);
  const Candidate candidate = Candidate(
    id: '11',
    title: 't',
    canApprove: true,
    canReject: true,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CandidateDetailPage(
          api: api,
          thumbnails: thumbnails,
          candidate: candidate,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('作品详情按 actions 渲染重打 / 重获按钮', (WidgetTester tester) async {
    await pump(
      tester,
      backendWithDetail(
        detailWith(<String, Object?>{
          'approve': true,
          'repack': true,
          'fetch_metadata': true,
          'delete_files': false,
        }),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('detail-approve')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('detail-action-repack')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('detail-action-fetch_metadata')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('detail-action-delete_files')),
      findsNothing,
    );
  });

  testWidgets('prev/next 按钮仅在后端返回时出现', (WidgetTester tester) async {
    await pump(
      tester,
      backendWithDetail(<String, Object?>{
        ...workDetailJson(),
        'prev_id': '10',
        'next_id': '12',
      }),
    );
    expect(find.byKey(const ValueKey<String>('detail-prev')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('detail-next')), findsOneWidget);
  });

  testWidgets('actions 全缺时仅留通过/驳回', (WidgetTester tester) async {
    await pump(
      tester,
      backendWithDetail(<String, Object?>{
        ...workDetailJson(),
        'actions': <String, Object?>{},
      }),
    );
    expect(
      find.byKey(const ValueKey<String>('detail-approve')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('detail-reject')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('detail-action-repack')),
      findsNothing,
    );
  });
}
