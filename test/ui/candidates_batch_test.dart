import 'package:ehbot_mobile/ui/candidates_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

void main() {
  testWidgets('长按候选进入多选，批量通过走批量端点', (WidgetTester tester) async {
    final List<String> batches = <String>[];
    final http.Client client = fakeBackend(
      onRequest: (http.Request request) {
        if (request.url.path.endsWith('/candidates/batch')) {
          batches.add(request.body);
        }
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CandidatesPage(
            api: apiWith(client),
            thumbnails: thumbnailsWith(client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 未选之前没有批量条。
    expect(
      find.byKey(const ValueKey<String>('candidate-batch-approve')),
      findsNothing,
    );

    await tester.longPress(
      find.byKey(const ValueKey<String>('candidate-11')),
    );
    await tester.pumpAndSettle();

    expect(find.text('已选 1 个'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('candidate-batch-approve')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('candidate-batch-approve')),
    );
    await tester.pumpAndSettle();

    expect(batches, hasLength(1));
    expect(batches.single, contains('"action":"approve"'));
    // 批量完成后退出选择模式。
    expect(find.text('已选 1 个'), findsNothing);
  });

  testWidgets('取消按钮退出多选', (WidgetTester tester) async {
    final http.Client client = fakeBackend();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CandidatesPage(
            api: apiWith(client),
            thumbnails: thumbnailsWith(client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey<String>('candidate-11')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('candidate-batch-cancel')),
    );
    await tester.pumpAndSettle();

    expect(find.text('已选 1 个'), findsNothing);
  });

  testWidgets('右滑候选触发通过', (WidgetTester tester) async {
    final List<String> batches = <String>[];
    final http.Client client = fakeBackend(
      onRequest: (http.Request request) {
        if (request.url.path.endsWith('/candidates/batch')) {
          batches.add(request.body);
        }
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CandidatesPage(
            api: apiWith(client),
            thumbnails: thumbnailsWith(client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey<String>('candidate-swipe-11')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();

    expect(batches, isNotEmpty);
    expect(batches.first, contains('"action":"approve"'));
  });
}
