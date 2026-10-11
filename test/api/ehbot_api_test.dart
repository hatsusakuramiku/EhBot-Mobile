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

  // ---------------------------------------------------------------- M9 动作面

  test('WorkDetail：解析 jobs（含每个任务自己的 actions 与 torrent）', () async {
    final EhBotApi api = apiWith(
      MockClient(
        (http.Request request) async => jsonResponse(<String, Object?>{
          'candidate_id': '11',
          'jobs': <Map<String, Object?>>[
            <String, Object?>{
              'job_id': 77,
              'candidate_id': 11,
              'provider': <String, Object?>{
                'code': 'EH_TORRENT',
                'label': 'EH 种子',
              },
              'state': <String, Object?>{
                'code': 'WAITING_TORRENT',
                'label': '等待做种',
                'tone': 'waiting',
                'live': true,
              },
              'actions': <String, Object?>{
                'retry': false,
                'cancel': true,
                'stop_seeding': false,
              },
              'torrent': <String, Object?>{'waiting_for_peers': true},
            },
          ],
        }),
      ),
    );

    final WorkDetail detail = await api.work('11');

    expect(detail.jobs, hasLength(1));
    final JobSummary job = detail.jobs.single;
    expect(job.id, '77');
    expect(job.providerCode, 'EH_TORRENT');
    expect(job.canCancel, isTrue);
    expect(job.canRetry, isFalse);
    // `stop_seeding` 是 payload 的键，URL 里的动作名是 `stop-seeding`。
    expect(job.canStopSeeding, isFalse);
    expect(job.canSwitchSource, isTrue);
    expect(detail.jobCount, 1);
  });

  test('WorkDetail：actions 的平铺布尔与 sources 分开解析', () async {
    final EhBotApi api = apiWith(
      MockClient(
        (http.Request request) async => jsonResponse(<String, Object?>{
          'candidate_id': '11',
          'actions': <String, Object?>{
            'approve': true,
            'delete': false,
            'needs_revision': false,
            'sources': <Map<String, Object?>>[
              <String, Object?>{
                'provider': <String, Object?>{
                  'code': 'TELEGRAPH',
                  'label': '预览页',
                },
                'available': false,
                'hint': '来源消息没有预览链接',
                'action': '/candidates/11/telegraph',
              },
            ],
          },
        }),
      ),
    );

    final WorkDetail detail = await api.work('11');

    expect(detail.can('approve'), isTrue);
    expect(detail.can('delete'), isFalse);
    expect(detail.actions.sources, hasLength(1));
    expect(detail.actions.sources.single.providerCode, 'TELEGRAPH');
    expect(detail.actions.sources.single.available, isFalse);
    expect(detail.actions.sources.single.hint, '来源消息没有预览链接');
  });

  test('任务操作打 job id 与正确的动作名', () async {
    final List<String> paths = <String>[];
    final EhBotApi api = apiWith(
      MockClient((http.Request request) async {
        paths.add(request.url.path);
        return jsonResponse(<String, Object?>{'job_id': 77, 'action': 'retry'});
      }),
    );

    await api.jobAction(jobId: '77', action: kJobRetry);
    await api.jobAction(jobId: '77', action: kJobStopSeeding);

    expect(paths, <String>[
      '/api/v1/jobs/77/retry',
      '/api/v1/jobs/77/stop-seeding',
    ]);
  });

  test('优先级写 body.priority', () async {
    late String body;
    final EhBotApi api = apiWith(
      MockClient((http.Request request) async {
        body = request.body;
        return jsonResponse(<String, Object?>{'job_id': 77, 'priority': 5});
      }),
    );

    await api.jobPriority(jobId: '77', priority: 5);

    expect(body, contains('"priority":5'));
  });

  test('切源打 switch-source 并回传新 job id', () async {
    late http.Request captured;
    final EhBotApi api = apiWith(
      MockClient((http.Request request) async {
        captured = request;
        return jsonResponse(<String, Object?>{
          'job_id': 99,
          'provider': 'EXHENTAI',
        });
      }),
    );

    final String newJobId = await api.switchSource(
      jobId: '77',
      provider: 'EXHENTAI',
    );

    expect(captured.url.path, '/api/v1/jobs/77/switch-source');
    expect(captured.body, contains('"provider":"EXHENTAI"'));
    expect(newJobId, '99');
  });

  test('重新排队打 works/{id}/requeue', () async {
    late http.Request captured;
    final EhBotApi api = apiWith(
      MockClient((http.Request request) async {
        captured = request;
        return jsonResponse(<String, Object?>{'candidate_id': 11});
      }),
    );

    await api.requeueWork('11');

    expect(captured.url.path, '/api/v1/works/11/requeue');
    expect(captured.body, '{}');
  });

  test('删除候选：delete 与 delete-files', () async {
    final List<String> bodies = <String>[];
    final EhBotApi api = apiWith(
      MockClient((http.Request request) async {
        bodies.add(request.body);
        return jsonResponse(<String, Object?>{
          'action': 'delete',
          'requested': 2,
          'applied': <Object>[],
          'skipped': <Object>[],
        });
      }),
    );

    await api.deleteCandidates(candidateIds: <String>['11', '12']);
    await api.deleteCandidates(
      candidateIds: <String>['11'],
      deleteFiles: true,
    );

    expect(bodies.first, contains('"action":"delete"'));
    expect(bodies.first, contains('"candidate_ids":[11,12]'));
    expect(bodies.last, contains('"action":"delete-files"'));
  });

  test('已下载批量：repack / remove / redownload 带各自参数', () async {
    final List<String> bodies = <String>[];
    final EhBotApi api = apiWith(
      MockClient((http.Request request) async {
        bodies.add('${request.url.path} ${request.body}');
        return jsonResponse(<String, Object?>{
          'action': 'remove',
          'requested': 1,
          'applied': <Object>[],
          'skipped': <Object>[],
          'delete_files': true,
        });
      }),
    );

    await api.downloadedBatch(
      action: kDownloadedRedownload,
      candidateIds: <String>['11'],
    );
    await api.downloadedBatch(
      action: kDownloadedRemove,
      candidateIds: <String>['11'],
      deleteFiles: true,
    );

    expect(
      bodies.first,
      '/api/v1/downloaded/batch {"action":"redownload","candidate_ids":[11]}',
    );
    expect(bodies.last, contains('"action":"remove"'));
    expect(bodies.last, contains('"delete_files":true'));
  });

  test('去重走 downloaded/dedup（GET 计划 / POST 执行）', () async {
    final List<String> calls = <String>[];
    final EhBotApi api = apiWith(
      MockClient((http.Request request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.method == 'GET') {
          return jsonResponse(<String, Object?>{
            'groups': <Object>[],
            'removable': 0,
          });
        }
        return jsonResponse(<String, Object?>{'removed': 0});
      }),
    );

    await api.dedupPlan();
    await api.dedupApply();

    expect(calls, <String>[
      'GET /api/v1/downloaded/dedup',
      'POST /api/v1/downloaded/dedup',
    ]);
  });

  test('手动添加：重复回 409 时翻成「已有候选」', () async {
    final EhBotApi api = apiWith(
      MockClient(
        (http.Request request) async => errorResponse(
          'CANDIDATE_DUPLICATE',
          status: 409,
          message: '作品已存在：候选 #42',
          details: <String, Object?>{'existing_candidate_id': 42},
        ),
      ),
    );

    final ManualAddResult result = await api.manualAdd(
      'https://exhentai.org/g/1/abc/',
    );

    expect(result.isDuplicate, isTrue);
    expect(result.existingCandidateId, '42');
    expect(result.message, contains('已存在'));
  });

  test('设置分区写入用 PUT', () async {
    final List<String> calls = <String>[];
    final EhBotApi api = apiWith(
      MockClient((http.Request request) async {
        calls.add('${request.method} ${request.url.path} ${request.body}');
        return jsonResponse(<String, Object?>{'system': <String, Object?>{}});
      }),
    );

    await api.putSettingsSection(
      kSettingsSystem,
      <String, Object?>{'timezone': 'Asia/Tokyo'},
    );

    expect(calls.single, startsWith('PUT /api/v1/settings/system'));
    expect(calls.single, contains('"timezone":"Asia/Tokyo"'));
  });
}
