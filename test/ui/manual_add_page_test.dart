import 'package:ehbot_mobile/api/ehbot_api.dart';
import 'package:ehbot_mobile/media/thumbnail_loader.dart';
import 'package:ehbot_mobile/ui/manual_add_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

void main() {
  Future<void> pump(WidgetTester tester, MockClient client) async {
    final EhBotApi api = apiWith(client);
    final ThumbnailLoader thumbnails = thumbnailsWith(client);
    await tester.pumpWidget(
      MaterialApp(home: ManualAddPage(api: api, thumbnails: thumbnails)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('手动添加成功后提示已入队', (WidgetTester tester) async {
    await pump(
      tester,
      MockClient((http.Request request) async {
        if (request.url.path.contains('/candidates/manual')) {
          return jsonResponse(<String, Object?>{'candidate_id': '42'});
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('manual-url')),
      'https://exhentai.org/g/1/abc/',
    );
    await tester.tap(find.byKey(const ValueKey<String>('manual-submit')));
    await tester.pumpAndSettle();

    expect(find.text('已加入下载队列'), findsOneWidget);
  });

  testWidgets('重复链接给出已有候选入口', (WidgetTester tester) async {
    await pump(
      tester,
      MockClient((http.Request request) async {
        if (request.url.path.contains('/candidates/manual')) {
          return jsonResponse(<String, Object?>{'existing_candidate_id': '7'});
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('manual-url')),
      'https://exhentai.org/g/1/abc/',
    );
    await tester.tap(find.byKey(const ValueKey<String>('manual-submit')));
    await tester.pumpAndSettle();

    expect(find.text('这件作品已经在库里'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('manual-open-existing')),
      findsOneWidget,
    );
  });

  testWidgets('后端未实现时给出 404 说明', (WidgetTester tester) async {
    await pump(
      tester,
      MockClient((http.Request request) async =>
          errorResponse('NOT_FOUND', status: 404, message: 'no route')),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('manual-url')),
      'https://exhentai.org/g/1/abc/',
    );
    await tester.tap(find.byKey(const ValueKey<String>('manual-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('后端还没有'), findsOneWidget);
  });
}
