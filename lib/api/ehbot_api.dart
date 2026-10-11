import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'auth_client.dart';
import 'events.dart';
import 'json_io.dart';
import 'models.dart';

/// 候选删除动作（EhBot `CANDIDATE_DELETE_ACTIONS`）：走同一个 `candidates/batch`。
const String kCandidateDeleteAction = 'delete';
const String kCandidateDeleteFilesAction = 'delete-files';

/// 已下载批量动作（EhBot `DOWNLOADED_BATCH_ACTIONS`）。
const String kDownloadedRepack = 'repack';
const String kDownloadedRemove = 'remove';
const String kDownloadedRedownload = 'redownload';

/// 任务生命周期动作（EhBot `JOB_ACTIONS`）：`POST /api/v1/jobs/{job_id}/{action}`。
const String kJobRetry = 'retry';
const String kJobPause = 'pause';
const String kJobResume = 'resume';
const String kJobCancel = 'cancel';

/// `stop-seeding` 是**路径**里的拼法；`job_summary.actions` 里对应的键是 `stop_seeding`。
const String kJobStopSeeding = 'stop-seeding';

/// 任务优先级范围（EhBot `app/downloads/models.py`：`MIN_JOB_PRIORITY` / `MAX_JOB_PRIORITY`）。
const int kMinJobPriority = 1;
const int kMaxJobPriority = 999;

/// 设置分区里**已有 PUT 写入**的三个（R67–R69）。
const String kSettingsConnections = 'connections';
const String kSettingsSystem = 'system';
const String kSettingsPasswords = 'passwords';

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

  /// 彻底删除候选（[deleteFiles] 为真则连压缩包与 CBZ 一起删）。
  ///
  /// 与通过 / 驳回同一个端点：后端按 `delete` / `delete-files` 分派到
  /// `apply_candidate_delete_batch`（EhBot R64）。取不到删的状态由服务端判定，
  /// 被拒的候选出现在结果的 `skipped` 里。
  Future<ReviewBatchResult> deleteCandidates({
    required List<String> candidateIds,
    bool deleteFiles = false,
  }) async {
    final http.Response response = await client.postJson(
      '/api/v1/candidates/batch',
      body: <String, Object?>{
        'action': deleteFiles
            ? kCandidateDeleteFilesAction
            : kCandidateDeleteAction,
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

  /// 任务生命周期操作：`retry` / `pause` / `resume` / `cancel` / `stop-seeding`。
  ///
  /// [jobId] 必须是**任务 id**（`job_summary.job_id`），不是候选 id——传候选 id
  /// 会 404 / 400，这正是 M9 之前的老 bug。
  Future<void> jobAction({
    required String jobId,
    required String action,
  }) async {
    await client.postJson(
      '/api/v1/jobs/$jobId/$action',
      body: const <String, Object?>{},
    );
  }

  /// 调整任务优先级（`POST /api/v1/jobs/{job_id}/priority`）。
  Future<void> jobPriority({
    required String jobId,
    required int priority,
  }) async {
    await client.postJson(
      '/api/v1/jobs/$jobId/priority',
      body: <String, Object?>{'priority': priority},
    );
  }

  /// 切换下载来源，返回**新任务 id**（切源会替换任务）。
  ///
  /// [provider] 取自详情页 `actions.sources[].provider.code`
  /// （`TELEGRAM` / `TELEGRAM_USER` / `EXHENTAI` / `TELEGRAPH` / `EH_TORRENT`）。
  /// 那个 `action` 字段是网页路径，不能直接调。
  Future<String> switchSource({
    required String jobId,
    required String provider,
  }) async {
    final Map<String, dynamic> json = _ok(
      await client.postJson(
        '/api/v1/jobs/$jobId/switch-source',
        body: <String, Object?>{'provider': provider},
      ),
    );
    return asString(json['job_id']);
  }

  /// 重新排队（`POST /api/v1/works/{candidate_id}/requeue`，EhBot R65）。
  ///
  /// 只在 `actions.requeue` 为真时才有意义：后端只接受
  /// `REJECTED` / `NEEDS_REVISION` / `FAILED` 三种状态。
  Future<void> requeueWork(String candidateId, {String note = ''}) async {
    await client.postJson(
      '/api/v1/works/$candidateId/requeue',
      body: <String, Object?>{if (note.isNotEmpty) 'note': note},
    );
  }

  /// 改元数据 / 锁定字段（`PATCH /api/v1/works/{candidate_id}/metadata`）。
  ///
  /// [fields] / [locks] 各自独立，至少给一个。字段名必须是后端
  /// `METADATA_FIELDS` 里的名字（`Title` / `Artist` / …），也就是
  /// `WorkDetail.metadata[].name`；不认识的字段会 400 `METADATA_FIELD_INVALID`。
  Future<void> updateMetadata({
    required String candidateId,
    Map<String, String> fields = const <String, String>{},
    Map<String, bool> locks = const <String, bool>{},
  }) async {
    await client.patchJson(
      '/api/v1/works/$candidateId/metadata',
      body: <String, Object?>{
        if (fields.isNotEmpty) 'fields': fields,
        if (locks.isNotEmpty) 'locks': locks,
      },
    );
  }

  /// 要求修订（`POST /api/v1/works/{candidate_id}/needs-revision`，EhBot R70）。
  ///
  /// [reason] 是落审计的那句话，**后端要求非空**：没有理由的「要求修订」
  /// 是一句没人能执行的请求，所以空串会得到 400 `REVISION_REASON_REQUIRED`。
  Future<void> requestRevision(String candidateId, String reason) async {
    await client.postJson(
      '/api/v1/works/$candidateId/needs-revision',
      body: <String, Object?>{'reason': reason},
    );
  }

  /// 打包 / 重新打包（`POST /api/v1/works/{candidate_id}/convert`，EhBot R70）。
  ///
  /// 一个端点两件事：后端按作品幂等，第二次按下就是把那条打包任务重新置为待跑
  /// （落回它替换的那个文件，不会造出 `book (2).cbz`）。返回任务 id。
  /// 还没下载过任何产物时后端回 400 `ARCHIVE_NOT_READY`。
  Future<String> convertWork(String candidateId) async {
    final Map<String, dynamic> json = _ok(
      await client.postJson(
        '/api/v1/works/$candidateId/convert',
        body: const <String, Object?>{},
      ),
    );
    return asString(json['job_id']);
  }

  /// 重获元数据（`POST /api/v1/works/{candidate_id}/fetch-metadata`，EhBot R71）。
  ///
  /// 没有关联画廊时后端回 400 `CANDIDATE_HAS_NO_EX_REFERENCE`；
  /// 没配 ExHentai 连接时回 503。
  Future<void> fetchMetadata(String candidateId) async {
    await client.postJson(
      '/api/v1/works/$candidateId/fetch-metadata',
      body: const <String, Object?>{},
    );
  }

  /// 按来源拉取（`POST /api/v1/works/{candidate_id}/sources/{provider}`，EhBot R72）。
  ///
  /// [provider] 用详情页 `actions.sources[].provider.code`
  /// （`TELEGRAM` / `TELEGRAM_USER` / `EXHENTAI` / `TELEGRAPH` / `EH_TORRENT`）。
  /// 一律是「再拉一次」；`EXHENTAI` 会消耗 GP，确认是客户端的事。返回任务 id。
  Future<String> pullSource({
    required String candidateId,
    required String provider,
  }) async {
    final Map<String, dynamic> json = _ok(
      await client.postJson(
        '/api/v1/works/$candidateId/sources/$provider',
        body: const <String, Object?>{},
      ),
    );
    return asString(json['job_id']);
  }

  /// 改名 / 移动已下载作品（`POST /api/v1/downloaded/{id}/rename`，EhBot R73）。
  ///
  /// **两栏都要发**：只给 [filename] 等于把文件移到库根。页面的抽屉是从
  /// 作品当前路径预填两栏再发的，这里照做。返回 `moved`——false 表示
  /// 「文件名未变更」，不是失败。
  Future<bool> renameDownloaded({
    required String candidateId,
    required String filename,
    required String directory,
    bool repack = false,
  }) async {
    final Map<String, dynamic> json = _ok(
      await client.postJson(
        '/api/v1/downloaded/$candidateId/rename',
        body: <String, Object?>{
          'filename': filename,
          'directory': directory,
          if (repack) 'repack': true,
        },
      ),
    );
    return asBool(json['moved']);
  }

  /// 已下载作品的批量动作：`repack` / `remove`（+[deleteFiles]）/ `redownload`。
  ///
  /// [repack] 只对 `redownload` 有意义（重新下载时顺带重新打包）。
  Future<ReviewBatchResult> downloadedBatch({
    required String action,
    required List<String> candidateIds,
    bool deleteFiles = false,
    bool repack = false,
  }) async {
    final http.Response response = await client.postJson(
      '/api/v1/downloaded/batch',
      body: <String, Object?>{
        'action': action,
        'candidate_ids': candidateIds.map(_asId).toList(),
        if (deleteFiles) 'delete_files': true,
        if (repack) 'repack': true,
      },
    );
    return ReviewBatchResult.fromJson(_ok(response));
  }

  /// 任务的批量动作：`retry` / `pause` / `resume` / `cancel`，
  /// 也可以调 `priority`（那时要带 [priority]）。
  ///
  /// 走 `/api/v1/jobs/batch`——与 WebUI 活动页的批量条同一个后端协程，
  /// 所以两边的「一个坏任务不会refuse另外四十九个」行为一致。
  Future<ReviewBatchResult> jobBatch({
    required String action,
    required List<String> jobIds,
    int? priority,
  }) async {
    final http.Response response = await client.postJson(
      '/api/v1/jobs/batch',
      body: <String, Object?>{
        'action': action,
        'job_ids': jobIds.map(_asId).toList(),
        'priority': ?priority,
      },
    );
    return ReviewBatchResult.fromJson(_ok(response));
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

  /// 手动添加任务（粘贴链接）。
  ///
  /// 重复不是错误：后端回 **409** `CANDIDATE_DUPLICATE`，已有候选 id 在
  /// `error.details.existing_candidate_id`（EhBot R66）。这里翻成
  /// [ManualAddResult]，让页面直接给「查看已有候选」入口。
  Future<ManualAddResult> manualAdd(String url) async {
    final http.Response response = await client.postJson(
      '/api/v1/candidates/manual',
      body: <String, Object?>{'url': url},
    );
    if (response.statusCode == 409) {
      final ApiException error = errorFromResponse(response);
      final String existing = asString(
        asMap(error.details)?['existing_candidate_id'],
      );
      return ManualAddResult(
        existingCandidateId: existing.isEmpty ? null : existing,
        message: error.message,
        duplicate: true,
      );
    }
    return ManualAddResult.fromJson(_ok(response));
  }

  /// 一键去重的计划（只读）。
  Future<DedupPlan> dedupPlan() async =>
      DedupPlan.fromJson(_ok(await client.get('/api/v1/downloaded/dedup')));

  /// 执行去重（后端不接受 body 参数，一个 POST 就是「执行」）。
  Future<DedupResult> dedupApply() async {
    final http.Response response = await client.postJson(
      '/api/v1/downloaded/dedup',
      body: const <String, Object?>{},
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

  /// 写入设置分区（R67–R69 只有 `connections` / `system` / `passwords` 三区）。
  ///
  /// 响应是该分区**写入后**的快照。`passwords` 的 `api-key-generate` 会在
  /// 响应里多带一次明文 `api_key_plaintext`，且只有那一次。
  Future<Map<String, dynamic>> putSettingsSection(
    String section,
    Map<String, Object?> body,
  ) async => _ok(
    await client.putJson('/api/v1/settings/$section', body: body),
  );

  Map<String, dynamic> _ok(http.Response response) =>
      decodeJsonObject(ensureSuccess(response));

  Object _asId(String id) => int.tryParse(id) ?? id;
}
