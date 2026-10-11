import 'package:http/http.dart' as http;

import 'auth_client.dart';
import 'events.dart';
import 'json_io.dart';
import 'models.dart';

/// `/api/v1` 数据端点：读为主，另含候选审核（走批量端点，单个也是批量）。
///
/// 响应解析全部容错（见 `models.dart` 的解析助手），后端多 / 少一个键不会崩。
class EhBotApi {
  EhBotApi(this.client);

  final AuthClient client;

  Future<Summary> summary() async =>
      Summary.fromJson(_ok(await client.get('/api/v1/summary')));

  Future<CandidatePage> candidates({
    String tab = 'pending',
    String search = '',
    int page = 1,
    int pageSize = 30,
  }) async {
    final http.Response response = await client.get(
      '/api/v1/candidates',
      query: <String, String>{
        'tab': tab,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'page': '$page',
        'page_size': '$pageSize',
      },
    );
    return CandidatePage.fromJson(_ok(response));
  }

  Future<WorkDetail> work(String candidateId) async =>
      WorkDetail.fromJson(_ok(await client.get('/api/v1/works/$candidateId')));

  /// 通过 / 驳回。[action] 取 `approve` 或 `reject`。
  Future<ReviewBatchResult> review({
    required String action,
    required List<String> candidateIds,
  }) async {
    final http.Response response = await client.postJson(
      '/api/v1/candidates/batch',
      body: <String, Object?>{
        'action': action,
        'candidate_ids': candidateIds.map(_asId).toList(),
      },
    );
    return ReviewBatchResult.fromJson(_ok(response));
  }

  Future<QueueSnapshot> queue() async =>
      QueueSnapshot.fromJson(_ok(await client.get('/api/v1/queue')));

  Future<List<JobSummary>> history({int limit = 50}) async {
    final Map<String, dynamic> json = _ok(
      await client.get(
        '/api/v1/history',
        query: <String, String>{'limit': '$limit'},
      ),
    );
    return asMapList(json['items']).map(JobSummary.fromJson).toList();
  }

  /// Trigger an action on a candidate. Backend may return the updated work;
  /// we ignore the body for now and let the caller reload.
  Future<void> jobAction({required String id, required String action}) async {
    await client.postJson(
      '/api/v1/jobs/$id/$action',
      body: const <String, Object?>{},
    );
  }

  Future<DownloadedPage> downloaded({
    String tab = 'all',
    String search = '',
    int page = 1,
    int pageSize = 30,
  }) async {
    final http.Response response = await client.get(
      '/api/v1/downloaded',
      query: <String, String>{
        'tab': tab,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'page': '$page',
        'page_size': '$pageSize',
      },
    );
    return DownloadedPage.fromJson(_ok(response));
  }

  Future<ClientMeta> meta() async =>
      ClientMeta.fromJson(_ok(await client.get('/api/v1/meta')));

  /// 手动添加任务（粘贴链接）。后端未实现时抛 404 的 `ApiException`。
  Future<ManualAddResult> manualAdd(String url) async {
    final http.Response response = await client.postJson(
      '/api/v1/candidates/manual',
      body: <String, Object?>{'url': url},
    );
    return ManualAddResult.fromJson(_ok(response));
  }

  /// 一键去重的计划（只读）。
  Future<DedupPlan> dedupPlan() async =>
      DedupPlan.fromJson(_ok(await client.get('/api/v1/dedup/plan')));

  /// 执行去重。
  Future<DedupResult> dedupApply({bool apply = true}) async {
    final http.Response response = await client.postJson(
      '/api/v1/dedup',
      body: <String, Object?>{'apply': apply},
    );
    return DedupResult.fromJson(_ok(response));
  }

  /// 历史日志。[level] 为展示下限，空串表示「全部」。
  Future<LogsPageData> logs({String level = '', int limit = 200}) async {
    final http.Response response = await client.get(
      '/api/v1/logs',
      query: <String, String>{
        if (level.isNotEmpty) 'level': level,
        'limit': '$limit',
      },
    );
    return LogsPageData.fromJson(_ok(response));
  }

  /// 实时日志流（SSE）。后端未实现时抛 404。
  Stream<LiveEvent> logsStream() =>
      SseEventSource(client: client, path: '/api/v1/logs/stream').connect();

  /// 设置分区快照（M8-E）：`connections` / `sources` / `parse` / `auto-approval` /
  /// `archive` / `paths` / `ai` / `passwords` / `system`。
  ///
  /// 后端未实现时抛 404 的 `ApiException`，由页面切成「后端未就绪」态。
  Future<Map<String, dynamic>> settingsSection(String section) async =>
      _ok(await client.get('/api/v1/settings/$section'));

  Map<String, dynamic> _ok(http.Response response) =>
      decodeJsonObject(ensureSuccess(response));

  Object _asId(String id) => int.tryParse(id) ?? id;
}
