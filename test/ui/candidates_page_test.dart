import 'package:ehbot_mobile/api/ehbot_api.dart';
import 'package:ehbot_mobile/media/thumbnail_loader.dart';
import 'package:ehbot_mobile/ui/candidates_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

void main() {
  Future<void> pump(WidgetTester tester, http.Client client) async {
    final EhBotApi api = apiWith(client);
    final ThumbnailLoader thumbnails = thumbnailsWith(client);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CandidatesPage(api: api, thumbnails: thumbnails),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('候选列表渲染卡片（标题 / 作者 / 状态）', (WidgetTester tester) async {
    await pump(tester, fakeBackend());

    expect(find.text('某本子'), findsOneWidget);
    expect(find.text('作者A'), findsOneWidget);
    expect(find.text('待审核'), findsWidgets);
    expect(find.text('共 3 个'), findsOneWidget);
  });

  testWidgets('切 tab 会带新 tab 重新请求', (WidgetTester tester) async {
    final List<String> tabs = <String>[];
    await pump(
      tester,
      fakeBackend(
        onRequest: (http.Request request) {
          if (request.url.path.endsWith('/candidates')) {
            tabs.add(request.url.queryParameters['tab'] ?? '');
          }
        },
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('candidate-tab-approved')),
    );
    await tester.pumpAndSettle();

    expect(tabs.first, 'pending');
    expect(tabs.last, 'approved');
  });

  testWidgets('只有一页时不显示「加载更多」', (WidgetTester tester) async {
    await pump(tester, fakeBackend());

    expect(
      find.byKey(const ValueKey<String>('candidate-load-more')),
      findsNothing,
    );
  });

  testWidgets('还有下一页时显示「加载更多」', (WidgetTester tester) async {
    await pump(
      tester,
      MockClient((http.Request request) async {
        if (request.url.path.contains('/thumbnails/')) {
          return tinyPngResponse();
        }
        return jsonResponse(candidatesPageJson(total: 60, pages: 2));
      }),
    );

    expect(
      find.byKey(const ValueKey<String>('candidate-load-more')),
      findsOneWidget,
    );
  });
}
