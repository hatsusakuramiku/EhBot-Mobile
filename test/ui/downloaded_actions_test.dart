import 'package:ehbot_mobile/api/ehbot_api.dart';
import 'package:ehbot_mobile/media/thumbnail_loader.dart';
import 'package:ehbot_mobile/ui/downloaded_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

Map<String, Object?> workJson({
  String id = '11',
  String packCode = 'packed',
  Map<String, Object?> actions = const <String, Object?>{
    'repack': true,
    'remove': true,
    'redownload': true,
  },
}) => <String, Object?>{
  ...downloadedJson(),
  'candidate_id': id,
  'pack': <String, Object?>{
    'code': packCode,
    'label': packCode == 'packed' ? '已打包' : '未打包',
  },
  'actions': actions,
};

MockClient backendWith(
  List<Map<String, Object?>> works, {
  void Function(http.Request request)? onRequest,
}) => MockClient((http.Request request) async {
  onRequest?.call(request);
  final String path = request.url.path;
  if (path.endsWith('/auth/whoami')) {
    return jsonResponse(whoAmIJson(kind: 'api_key'));
  }
  if (path.endsWith('/downloaded/batch')) {
    return jsonResponse(<String, Object?>{
      'action': 'remove',
      'requested': 1,
      'applied': <Map<String, Object?>>[
        <String, Object?>{'candidate_id': 11},
      ],
      'skipped': <Object>[],
      'delete_files': false,
    });
  }
  if (path.endsWith('/downloaded')) {
    return jsonResponse(<String, Object?>{
      'works': works,
      'total': works.length,
      'tab': 'all',
      'counts': <String, Object?>{'all': works.length},
      'live': false,
    });
  }
  return http.Response('{"error":{"code":"NOT_FOUND","message":"x"}}', 404);
});

Future<void> pump(WidgetTester tester, MockClient client) async {
  final EhBotApi api = apiWith(client);
  final ThumbnailLoader thumbnails = thumbnailsWith(client);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: DownloadedListPage(api: api, thumbnails: thumbnails)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final Finder finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('行内动作按后端 actions 渲染：打包 / 重新下载', (WidgetTester tester) async {
    await pump(tester, backendWith(<Map<String, Object?>>[workJson()]));

    expect(
      find.byKey(const ValueKey<String>('downloaded-repack-11')),
      findsOneWidget,
    );
    // 已打包的叫「重新打包」，没打包过的叫「打包」。
    expect(find.text('重新打包'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('downloaded-redownload-11')),
      findsOneWidget,
    );
  });

  testWidgets('在途的作品没有移除 / 重新下载入口', (WidgetTester tester) async {
    await pump(
      tester,
      backendWith(<Map<String, Object?>>[
        workJson(
          actions: <String, Object?>{'repack': true, 'remove': false, 'redownload': false},
        ),
      ]),
    );

    expect(
      find.byKey(const ValueKey<String>('downloaded-repack-11')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('downloaded-redownload-11')),
      findsNothing,
    );
  });

  testWidgets('长按多选后：移除并删除文件发 remove + delete_files', (WidgetTester tester) async {
    final List<String> bodies = <String>[];
    await pump(
      tester,
      backendWith(
        <Map<String, Object?>>[workJson()],
        onRequest: (http.Request request) {
          if (request.url.path.endsWith('/downloaded/batch')) {
            bodies.add(request.body);
          }
        },
      ),
    );

    await tester.longPress(
      find.byKey(const ValueKey<String>('downloaded-11')),
    );
    await tester.pumpAndSettle();
    expect(find.text('已选 1 个'), findsOneWidget);
    // 选中后行内动作让位给批量条。
    expect(
      find.byKey(const ValueKey<String>('downloaded-batch-remove')),
      findsOneWidget,
    );

    await tapKey(tester, 'downloaded-batch-remove-files');
    expect(find.textContaining('还会删除已归档的 CBZ'), findsOneWidget);
    await tester.tap(find.text('确认删除文件'));
    await tester.pumpAndSettle();

    expect(bodies.single, contains('"action":"remove"'));
    expect(bodies.single, contains('"delete_files":true'));
    expect(bodies.single, contains('"candidate_ids":[11]'));
  });

  testWidgets('批量重新下载发 redownload', (WidgetTester tester) async {
    final List<String> bodies = <String>[];
    await pump(
      tester,
      backendWith(
        <Map<String, Object?>>[workJson()],
        onRequest: (http.Request request) {
          if (request.url.path.endsWith('/downloaded/batch')) {
            bodies.add(request.body);
          }
        },
      ),
    );

    await tester.longPress(
      find.byKey(const ValueKey<String>('downloaded-11')),
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'downloaded-batch-redownload');
    await tester.tap(find.text('确认重新下载'));
    await tester.pumpAndSettle();

    expect(bodies.single, contains('"action":"redownload"'));
    expect(bodies.single, isNot(contains('delete_files')));
  });
}
