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

/// `actions.sources[]` 的一项，形状照抄 EhBot `work_actions._source_actions`。
Map<String, Object?> sourceJson(
  String code,
  String label, {
  bool available = true,
  String hint = '',
}) => <String, Object?>{
  'provider': <String, Object?>{'code': code, 'label': label},
  'available': available,
  'hint': hint,
  'action': '/candidates/11/$code',
};

/// 详情快照，可覆盖 `actions` 与 `jobs`。
Map<String, Object?> detailJson({
  Map<String, Object?> actions = const <String, Object?>{},
  List<Map<String, Object?>> jobs = const <Map<String, Object?>>[],
  List<Map<String, Object?>> metadata = const <Map<String, Object?>>[],
}) => <String, Object?>{
  ...workDetailJson(),
  'actions': actions,
  'jobs': jobs,
  if (metadata.isNotEmpty) 'metadata': metadata,
};

/// 带 `actions` / `torrent` 的任务，形状照抄 `job_summary`。
Map<String, Object?> jobJsonWith(
  String id, {
  Map<String, Object?> actions = const <String, Object?>{},
  bool waitingForPeers = false,
  String label = '下载中',
}) => <String, Object?>{
  ...jobJson(id: id, label: label),
  'actions': actions,
  'torrent': <String, Object?>{
    'waiting_for_peers': waitingForPeers,
    'seeding': false,
    'already_in_client': false,
    'detail': null,
  },
};

MockClient backendWithDetail(
  Map<String, Object?> body, {
  void Function(http.Request request)? onRequest,
}) => MockClient((http.Request request) async {
  onRequest?.call(request);
  final String path = request.url.path;
  if (path.contains('/thumbnails/')) {
    return tinyPngResponse();
  }
  if (path.endsWith('/auth/whoami')) {
    return jsonResponse(whoAmIJson(kind: 'api_key'));
  }
  if (path.endsWith('/candidates/batch')) {
    return jsonResponse(<String, Object?>{
      'action': 'delete',
      'requested': 1,
      'applied': <Map<String, Object?>>[
        <String, Object?>{'candidate_id': 11},
      ],
      'skipped': <Object>[],
    });
  }
  if (path.contains('/works/')) {
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
  // 从一个占位页 push 详情：删除成功会 pop 回来，所以详情必须是**压栈**的，
  // 不能是 `home:` 的根路由。
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (BuildContext _) => CandidateDetailPage(
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

/// 底栏是横向可滚动的：右边的按钮可能不在视口里，先滚到可见。
Future<void> tapKey(WidgetTester tester, String key) async {
  final Finder finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('底栏按后端真实 actions 渲染，且不需要滚动就能点通过', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      backendWithDetail(
        detailJson(
          actions: <String, Object?>{
            'approve': true,
            'reject': true,
            'needs_revision': false,
            'requeue': false,
            // 客户端 M9 之前按这些键取值——后端从不返回，按钮因此永不渲染。
            'delete': false,
            'delete_files': false,
            'repack': false,
            'switch_source_ehentai': false,
          },
        ),
      ),
    );

    // 通过 / 驳回在固定底栏里，不必滑到正文末尾。
    expect(find.byKey(const ValueKey<String>('detail-approve')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('detail-reject')), findsOneWidget);
    // 假键不再产生按钮。
    expect(
      find.byKey(const ValueKey<String>('detail-action-repack')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('detail-action-switch_source_ehentai')),
      findsNothing,
    );
    // 删除是中性的：后端不给信号，两个入口始终在（服务端会拒不可删的状态）。
    expect(find.byKey(const ValueKey<String>('detail-delete')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('detail-delete-files')),
      findsOneWidget,
    );
  });

  testWidgets('后端还没有的动作渲染为禁用并说明原因', (WidgetTester tester) async {
    await pump(
      tester,
      backendWithDetail(
        detailJson(
          actions: <String, Object?>{
            'needs_revision': true,
            'fetch_metadata': true,
            'convert': true,
            'sources': <Map<String, Object?>>[
              sourceJson('EH_TORRENT', 'EH 种子'),
              sourceJson('EXHENTAI', 'Archive Download', available: false, hint: '没有关联画廊'),
            ],
          },
        ),
      ),
    );

    final ButtonStyleButton needsRevision = tester.widget<ButtonStyleButton>(
      find.byKey(const ValueKey<String>('detail-action-needs_revision')),
    );
    expect(needsRevision.onPressed, isNull);

    final ButtonStyleButton convert = tester.widget<ButtonStyleButton>(
      find.byKey(const ValueKey<String>('detail-action-convert')),
    );
    expect(convert.onPressed, isNull);

    // 四个来源：可用的与不可用的都能看见，但都不能调（/api/v1 还没有这个端点）。
    for (final String code in <String>['EH_TORRENT', 'EXHENTAI']) {
      final ButtonStyleButton source = tester.widget<ButtonStyleButton>(
        find.byKey(ValueKey<String>('detail-action-source-$code')),
      );
      expect(source.onPressed, isNull, reason: '$code 应当禁用');
    }
    expect(find.text('EH 种子'), findsOneWidget);
  });

  testWidgets('重新排队打 works/{id}/requeue', (WidgetTester tester) async {
    final List<String> calls = <String>[];
    await pump(
      tester,
      backendWithDetail(
        detailJson(actions: <String, Object?>{'requeue': true}),
        onRequest: (http.Request request) {
          if (request.url.path.contains('/requeue')) {
            calls.add(request.url.path);
          }
        },
      ),
    );

    await tapKey(tester, 'detail-action-requeue');
    expect(calls, <String>['/api/v1/works/11/requeue']);
  });

  testWidgets('任务动作打 job id，不打候选 id', (WidgetTester tester) async {
    final List<String> calls = <String>[];
    await pump(
      tester,
      backendWithDetail(
        detailJson(
          jobs: <Map<String, Object?>>[
            jobJsonWith(
              '77',
              actions: <String, Object?>{'retry': true, 'cancel': true},
            ),
          ],
        ),
        onRequest: (http.Request request) {
          if (request.url.path.contains('/jobs/')) {
            calls.add(request.url.path);
          }
        },
      ),
    );

    await tapKey(tester, 'job-77-retry');
    expect(calls, <String>['/api/v1/jobs/77/retry']);

    // 取消要确认。
    await tapKey(tester, 'job-77-cancel');
    expect(calls, <String>['/api/v1/jobs/77/retry']);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(calls, <String>['/api/v1/jobs/77/retry', '/api/v1/jobs/77/cancel']);
  });

  testWidgets('停滞的种子可切源，EXHENTAI 先确认消耗 GP', (WidgetTester tester) async {
    final List<http.Request> calls = <http.Request>[];
    await pump(
      tester,
      backendWithDetail(
        detailJson(
          jobs: <Map<String, Object?>>[jobJsonWith('77', waitingForPeers: true)],
        ),
        onRequest: calls.add,
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('job-77-switch-EXHENTAI')),
      findsOneWidget,
    );

    await tapKey(tester, 'job-77-switch-EXHENTAI');
    expect(find.text('确认消耗 GP'), findsOneWidget);
    await tester.tap(find.text('确认消耗 GP'));
    await tester.pumpAndSettle();

    final http.Request switchCall = calls.firstWhere(
      (http.Request request) => request.url.path.endsWith('/switch-source'),
    );
    expect(switchCall.url.path, '/api/v1/jobs/77/switch-source');
    expect(switchCall.body, contains('"provider":"EXHENTAI"'));
  });

  testWidgets('不在停滞中的任务没有切源入口', (WidgetTester tester) async {
    await pump(
      tester,
      backendWithDetail(
        detailJson(
          jobs: <Map<String, Object?>>[jobJsonWith('77')],
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('job-77-switch-TELEGRAPH')), findsNothing);
  });

  testWidgets('彻底删除：action=delete，记录删掉、文件留下', (WidgetTester tester) async {
    final List<String> bodies = <String>[];
    await pump(
      tester,
      backendWithDetail(
        detailJson(),
        onRequest: (http.Request request) {
          if (request.url.path.endsWith('/candidates/batch')) {
            bodies.add(request.body);
          }
        },
      ),
    );

    await tapKey(tester, 'detail-delete');
    expect(find.textContaining('压缩包与已归档的 CBZ 保留'), findsOneWidget);
    await tester.tap(find.text('确认彻底删除'));
    await tester.pumpAndSettle();

    expect(bodies.single, contains('"action":"delete"'));
    expect(bodies.single, contains('"candidate_ids":[11]'));
    // 删除成功后回上一页（列表据此刷新）。
    expect(find.byType(CandidateDetailPage), findsNothing);
  });

  testWidgets('彻底删除并删文件：action=delete-files', (WidgetTester tester) async {
    final List<String> bodies = <String>[];
    await pump(
      tester,
      backendWithDetail(
        detailJson(),
        onRequest: (http.Request request) {
          if (request.url.path.endsWith('/candidates/batch')) {
            bodies.add(request.body);
          }
        },
      ),
    );

    await tapKey(tester, 'detail-delete-files');
    expect(find.textContaining('还会删除已下载的压缩包'), findsOneWidget);
    await tester.tap(find.text('确认删除文件'));
    await tester.pumpAndSettle();

    expect(bodies.single, contains('"action":"delete-files"'));
  });

  testWidgets('元数据可改值并锁定，PATCH field_name', (WidgetTester tester) async {
    final List<String> bodies = <String>[];
    await pump(
      tester,
      backendWithDetail(
        detailJson(
          metadata: <Map<String, Object?>>[
            <String, Object?>{
              'field_name': 'Title',
              'field_label': '标题',
              'field_value': '旧标题',
              'is_manual': false,
              'is_locked': false,
            },
          ],
        ),
        onRequest: (http.Request request) {
          if (request.url.path.endsWith('/metadata')) {
            bodies.add('${request.method} ${request.url.path} ${request.body}');
          }
        },
      ),
    );

    await tapKey(tester, 'detail-metadata-标题');
    await tester.enterText(
      find.byKey(const ValueKey<String>('metadata-value')),
      '新标题',
    );
    await tester.tap(find.byKey(const ValueKey<String>('metadata-lock')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('metadata-save')));
    await tester.pumpAndSettle();

    expect(bodies, hasLength(1));
    expect(bodies.single, startsWith('PATCH /api/v1/works/11/metadata'));
    expect(bodies.single, contains('"Title":"新标题"'));
    expect(bodies.single, contains('"locks":{"Title":true}'));
  });
}
