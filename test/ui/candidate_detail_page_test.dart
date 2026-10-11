import 'package:ehbot_mobile/api/ehbot_api.dart';
import 'package:ehbot_mobile/api/models.dart';
import 'package:ehbot_mobile/media/thumbnail_loader.dart';
import 'package:ehbot_mobile/ui/candidate_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

void main() {
  const Candidate candidate = Candidate(
    id: '11',
    title: '某本子',
    artist: '作者A',
    status: StatusView(code: 'PENDING_REVIEW', label: '待审核', tone: 'waiting'),
    cover: CoverRef(hash: 'hash-a'),
    canApprove: true,
    canReject: true,
  );

  Future<void> pumpDetail(WidgetTester tester, http.Client client) async {
    final EhBotApi api = apiWith(client);
    final ThumbnailLoader thumbnails = thumbnailsWith(client);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<bool>(
                    builder: (BuildContext context) => CandidateDetailPage(
                      api: api,
                      thumbnails: thumbnails,
                      candidate: candidate,
                    ),
                  ),
                ),
                child: const Text('打开详情'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开详情'));
    await tester.pumpAndSettle();
  }

  testWidgets('详情显示标题、状态与元数据 / 时间线', (WidgetTester tester) async {
    await pumpDetail(tester, fakeBackend());

    expect(find.byKey(const ValueKey<String>('detail-title')), findsOneWidget);
    expect(find.text('某本子'), findsWidgets);
    // 底栏是第二个 Scrollable，所以不能用 scrollUntilVisible 的默认查找；
    // 直接拖正文那一个。
    await tester.drag(
      find.byKey(const ValueKey<String>('detail-scroll')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(find.text('元数据'), findsOneWidget);
    expect(find.text('标题'), findsOneWidget);
    expect(find.text('时间线'), findsOneWidget);
    expect(find.text('入库'), findsOneWidget);
  });

  testWidgets('通过：调用批量端点并带结果返回上一页', (WidgetTester tester) async {
    final List<String> batches = <String>[];
    await pumpDetail(
      tester,
      fakeBackend(
        onRequest: (http.Request request) {
          if (request.url.path.endsWith('/candidates/batch')) {
            batches.add(request.body);
          }
        },
      ),
    );

    final Finder approve = find.byKey(const ValueKey<String>('detail-approve'));
    // 操作在固定底栏里，不需要滚动就能点到（M9-C）。
    await tester.tap(approve);
    await tester.pumpAndSettle();

    expect(batches, hasLength(1));
    expect(batches.single, contains('"action":"approve"'));
    expect(find.byType(CandidateDetailPage), findsNothing);
  });
}
