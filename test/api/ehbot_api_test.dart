import 'dart:convert';

import 'package:ehbot_mobile/api/api_exception.dart';
import 'package:ehbot_mobile/api/ehbot_api.dart';
import 'package:ehbot_mobile/api/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

void main() {
  test('候选列表：拼查询参数并解析 items / tab_counts / cover', () async {
    late http.Request captured;
    final EhBotApi api = apiWith(
      MockClient((http.Request request) async {
        captured = request;
        return jsonResponse(candidatesPageJson());
      }),
    );

    final CandidatePage page = await api.candidates(
      tab: 'approved',
      search: '作者A',
      page: 2,
    );

    expect(captured.url.path, '/api/v1/candidates');
    expect(captured.url.queryParameters, <String, String>{
      'tab': 'approved',
      'search': '作者A',
      'page': '2',
      'page_size': '30',
    });
    expect(page.items, hasLength(1));
    expect(page.items.first.title, '某本子');
    expect(page.items.first.status.label, '待审核');
    expect(page.items.first.cover?.hash, 'hash-a');
    expect(page.items.first.canApprove, isTrue);
    expect(page.tabCounts['pending'], 1);
    expect(page.total, 3);
  });

  test('候选没有封面时不构造 CoverRef', () async {
    final EhBotApi api = apiWith(
      MockClient(
        (http.Request request) async => jsonResponse(
          candidatesPageJson(
            items: <Map<String, Object?>>[candidateJson(coverHash: null)],
          ),
        ),
      ),
    );

    final CandidatePage page = await api.candidates();

    expect(page.items.first.cover, isNull);
  });

  test('工作台概览：候选计数 / 活动 / 需干预', () async {
    final EhBotApi api = apiWith(
      MockClient((http.Request request) async => jsonResponse(summaryJson())),
    );

    final Summary summary = await api.summary();

    expect(summary.candidateCounts['total'], 7);
    expect(summary.candidateCounts['pending_review'], 3);
    expect(summary.downloads, 1);
    expect(summary.activityLive, isTrue);
    expect(summary.attentionTotal, 1);
    expect(summary.attentionItems.single.state.label, '下载中');
    expect(summary.attentionItems.single.providerLabel, 'Telegram');
  });

  test('已下载：认 works 键，也兼容 items 键', () async {
    final EhBotApi worksApi = apiWith(
      MockClient(
        (http.Request request) async => jsonResponse(<String, Object?>{
          'works': <Map<String, Object?>>[downloadedJson()],
          'total': 1,
        }),
      ),
    );
    final EhBotApi itemsApi = apiWith(
      MockClient(
        (http.Request request) async => jsonResponse(<String, Object?>{
          'items': <Map<String, Object?>>[downloadedJson()],
          'total': 1,
        }),
      ),
    );

    final DownloadedPage a = await worksApi.downloaded();
    final DownloadedPage b = await itemsApi.downloaded();

    expect(a.items.single.displayTitle, '已下载本');
    expect(a.items.single.state.label, '已下载');
    expect(a.items.single.packLabel, '已打包');
    expect(b.items, hasLength(1));
  });

  test('审核：candidate_ids 发数字，解析 applied / skipped', () async {
    late http.Request captured;
    final EhBotApi api = apiWith(
      MockClient((http.Request request) async {
        captured = request;
        return jsonResponse(<String, Object?>{
          'action': 'approve',
          'requested': 2,
          'applied': <Map<String, Object?>>[
            <String, Object?>{'candidate_id': 11},
          ],
          'skipped': <Map<String, Object?>>[
            <String, Object?>{
              'candidate_id': 12,
              'code': 'NOT_REVIEWABLE',
              'message': '状态不可审核',
            },
          ],
        });
      }),
    );

    final ReviewBatchResult result = await api.review(
      action: 'approve',
      candidateIds: <String>['11', '12'],
    );

    expect(captured.url.path, '/api/v1/candidates/batch');
    expect(jsonDecode(captured.body), <String, Object?>{
      'action': 'approve',
      'candidate_ids': <Object>[11, 12],
    });
    expect(result.requested, 2);
    expect(result.applied, 1);
    expect(result.skipped.single, '状态不可审核');
  });

  test('详情：解析元数据与时间线', () async {
    final EhBotApi api = apiWith(
      MockClient(
        (http.Request request) async => jsonResponse(workDetailJson()),
      ),
    );

    final WorkDetail detail = await api.work('11');

    expect(detail.displayTitle, '某本子');
    expect(detail.stage.label, '审核');
    expect(detail.metadata.single.label, '标题');
    expect(detail.timeline.single.label, '入库');
    expect(detail.timeline.single.createdAt, isNotNull);
  });

  test('后端错误信封透传成 ApiException', () async {
    final EhBotApi api = apiWith(
      MockClient(
        (http.Request request) async => errorResponse(
          'CANDIDATE_NOT_FOUND',
          message: '候选不存在或已被删除',
          status: 404,
        ),
      ),
    );

    await expectLater(
      api.work('999'),
      throwsA(
        isA<ApiException>()
            .having((ApiException e) => e.code, 'code', 'CANDIDATE_NOT_FOUND')
            .having((ApiException e) => e.statusCode, 'statusCode', 404),
      ),
    );
  });

  test('历史：解析 items 列表', () async {
    final EhBotApi api = apiWith(
      MockClient(
        (http.Request request) async => jsonResponse(<String, Object?>{
          'items': <Map<String, Object?>>[jobJson(id: '88', label: '已完成')],
          'total': 1,
          'limit': 50,
        }),
      ),
    );

    final List<JobSummary> history = await api.history();

    expect(history.single.id, '88');
    expect(history.single.state.label, '已完成');
  });

  test('meta：读取轮询间隔', () async {
    final EhBotApi api = apiWith(
      MockClient(
        (http.Request request) async => jsonResponse(<String, Object?>{
          'polling': <String, Object?>{
            'interval_ms': 5000,
            'idle_interval_ms': 30000,
          },
          'timezone': 'Asia/Shanghai',
        }),
      ),
    );

    final ClientMeta meta = await api.meta();

    expect(meta.pollingInterval, const Duration(seconds: 5));
    expect(meta.idleInterval, const Duration(seconds: 30));
    expect(meta.timezone, 'Asia/Shanghai');
  });
}
