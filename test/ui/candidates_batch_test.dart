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

  testWidgets('多选彻底删除走 delete-files，两个入口文案不同', (WidgetTester tester) async {
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

    await tester.longPress(
      find.byKey(const ValueKey<String>('candidate-11')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('candidate-batch-delete')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('压缩包与已归档的 CBZ 保留'), findsOneWidget);
    // 取消不会发请求。
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('取消'),
      ),
    );
    await tester.pumpAndSettle();
    expect(batches, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey<String>('candidate-batch-delete-files')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('还会删除已下载的压缩包'), findsOneWidget);
    await tester.tap(find.text('确认删除文件'));
    await tester.pumpAndSettle();

    expect(batches.single, contains('"action":"delete-files"'));
    expect(batches.single, contains('"candidate_ids":[11]'));
  });
}
