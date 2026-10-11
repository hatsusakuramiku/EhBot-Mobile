import 'package:ehbot_mobile/api/ehbot_api.dart';
import 'package:ehbot_mobile/media/thumbnail_loader.dart';
import 'package:ehbot_mobile/ui/activity_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

Map<String, Object?> queueJobJson({
  String id = '77',
  Map<String, Object?> actions = const <String, Object?>{'retry': true},
  bool waitingForPeers = false,
}) => <String, Object?>{
  ...jobJson(id: id),
  'actions': actions,
  'torrent': <String, Object?>{
    'waiting_for_peers': waitingForPeers,
    'seeding': false,
    'already_in_client': false,
    'detail': null,
  },
};

MockClient backendWith(
  Map<String, Object?> job, {
  void Function(http.Request request)? onRequest,
}) => MockClient((http.Request request) async {
  onRequest?.call(request);
  final String path = request.url.path;
  if (path.endsWith('/auth/whoami')) {
    return jsonResponse(whoAmIJson(kind: 'api_key'));
  }
  if (path.endsWith('/jobs/batch')) {
    return jsonResponse(<String, Object?>{
      'action': 'retry',
      'requested': 1,
      'applied': <Map<String, Object?>>[
        <String, Object?>{'job_id': 77, 'result': 'PENDING'},
      ],
      'skipped': <Object>[],
    });
  }
  if (path.contains('/jobs/')) {
    return jsonResponse(<String, Object?>{'job_id': 77, 'action': 'retry'});
  }
  if (path.endsWith('/queue')) {
    return jsonResponse(<String, Object?>{
      'downloads': <Map<String, Object?>>[
        <String, Object?>{
          'group': <String, Object?>{'code': 'active', 'label': '进行中'},
          'count': 1,
          'jobs': <Map<String, Object?>>[job],
        },
      ],
      'packing': <Object>[],
      'counts': <String, Object?>{'downloads': 1, 'packing': 0},
      'attention': <String, Object?>{'total': 0, 'reasons': <Object>[]},
      'live': true,
    });
  }
  if (path.endsWith('/history')) {
    return jsonResponse(<String, Object?>{
      'items': <Object>[],
      'total': 0,
      'limit': 50,
    });
  }
  return http.Response('{"error":{"code":"NOT_FOUND","message":"x"}}', 404);
});

Future<void> pump(WidgetTester tester, MockClient client) async {
  final EhBotApi api = apiWith(client);
  final ThumbnailLoader thumbnails = thumbnailsWith(client);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ActivityPage(api: api, thumbnails: thumbnails)),
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
  testWidgets('行内任务动作按 job_summary.actions 渲染，且打 job id', (
    WidgetTester tester,
  ) async {
    final List<String> paths = <String>[];
    await pump(
      tester,
      backendWith(
        queueJobJson(
          actions: <String, Object?>{'retry': true, 'cancel': true},
        ),
        onRequest: (http.Request request) {
          if (request.url.path.contains('/jobs/')) {
            paths.add(request.url.path);
          }
        },
      ),
    );

    await tapKey(tester, 'job-77-retry');
    expect(paths, <String>['/api/v1/jobs/77/retry']);

    await tapKey(tester, 'job-77-cancel');
    await tester.tap(find.text('确认取消'));
    await tester.pumpAndSettle();
    expect(paths, <String>['/api/v1/jobs/77/retry', '/api/v1/jobs/77/cancel']);
  });

  testWidgets('停滞的种子出现切源入口，可选预览图源与 Archive Download', (
    WidgetTester tester,
  ) async {
    final List<String> bodies = <String>[];
    await pump(
      tester,
      backendWith(
        queueJobJson(waitingForPeers: true),
        onRequest: (http.Request request) {
          if (request.url.path.endsWith('/switch-source')) {
            bodies.add(request.body);
          }
        },
      ),
    );

    await tapKey(tester, 'job-77-switch-TELEGRAPH');
    expect(find.textContaining('缩到宽 1280'), findsOneWidget);
    await tester.tap(find.text('确认改用预览图源'));
    await tester.pumpAndSettle();
    expect(bodies.single, contains('"provider":"TELEGRAPH"'));
  });

  testWidgets('多选批量重试走 jobs/batch，带 job_ids', (WidgetTester tester) async {
    final List<String> bodies = <String>[];
    await pump(
      tester,
      backendWith(
        queueJobJson(),
        onRequest: (http.Request request) {
          if (request.url.path.endsWith('/jobs/batch')) {
            bodies.add(request.body);
          }
        },
      ),
    );

    await tester.longPress(
      find.byKey(const ValueKey<String>('activity-job-77')),
    );
    await tester.pumpAndSettle();
    expect(find.text('已选 1 个'), findsOneWidget);

    await tapKey(tester, 'activity-batch-retry');
    expect(bodies.single, contains('"action":"retry"'));
    expect(bodies.single, contains('"job_ids":[77]'));
  });

  testWidgets('批量优先级越界时先拦下，不发请求', (WidgetTester tester) async {
    final List<String> bodies = <String>[];
    await pump(
      tester,
      backendWith(
        queueJobJson(),
        onRequest: (http.Request request) {
          if (request.url.path.endsWith('/jobs/batch')) {
            bodies.add(request.body);
          }
        },
      ),
    );

    await tester.longPress(
      find.byKey(const ValueKey<String>('activity-job-77')),
    );
    await tester.pumpAndSettle();

    await tapKey(tester, 'activity-batch-priority');
    await tester.enterText(
      find.byKey(const ValueKey<String>('activity-priority-input')),
      '0',
    );
    await tester.tap(find.byKey(const ValueKey<String>('activity-priority-apply')));
    await tester.pumpAndSettle();
    expect(bodies, isEmpty);
    expect(find.textContaining('需在 1 到 999 之间'), findsOneWidget);
  });

  testWidgets('批量调整优先级带 priority', (WidgetTester tester) async {
    final List<String> bodies = <String>[];
    await pump(
      tester,
      backendWith(
        queueJobJson(),
        onRequest: (http.Request request) {
          if (request.url.path.endsWith('/jobs/batch')) {
            bodies.add(request.body);
          }
        },
      ),
    );

    await tester.longPress(
      find.byKey(const ValueKey<String>('activity-job-77')),
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'activity-batch-priority');
    await tester.enterText(
      find.byKey(const ValueKey<String>('activity-priority-input')),
      '5',
    );
    await tester.tap(find.byKey(const ValueKey<String>('activity-priority-apply')));
    await tester.pumpAndSettle();
    expect(bodies.single, contains('"action":"priority"'));
    expect(bodies.single, contains('"priority":5'));
  });
}
