import 'api_exception.dart';

/// 解析后端时间戳（ISO-8601 字符串）；无法解析时返回 `null`。
DateTime? parseTimestamp(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

/// `GET /api/v1/auth/whoami` 的响应。
class WhoAmI {
  const WhoAmI({
    required this.username,
    required this.kind,
    this.expiresAt,
    this.mustChangePassword = false,
  });

  factory WhoAmI.fromJson(Map<String, dynamic> json) => WhoAmI(
    username: asString(json['username']),
    kind: asString(json['kind']),
    expiresAt: parseTimestamp(json['expires_at']),
    mustChangePassword: asBool(json['must_change_password']),
  );

  final String username;
  final String kind;

  /// `null` 表示不过期（API Key）。
  final DateTime? expiresAt;
  final bool mustChangePassword;
}

/// `POST /api/v1/auth/login` 与 `/refresh` 的响应。
class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresIn = 0,
  });

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    final Object? access = json['access_token'];
    final Object? refresh = json['refresh_token'];
    if (access is! String || refresh is! String) {
      throw const ApiException(
        code: ApiException.invalidResponse,
        message: 'token 响应缺少 access_token / refresh_token。',
      );
    }
    return TokenPair(
      accessToken: access,
      refreshToken: refresh,
      tokenType: asString(json['token_type'], 'Bearer'),
      expiresIn: asInt(json['expires_in']),
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
}

// ---------------------------------------------------------------- M3 数据模型

/// 后端状态词：`code` 是原始状态，`label`/`tone`/`live` 是后端解析好的展示词。
///
/// 文案一律用 [label]，不在客户端硬编码中文状态名——后端加一个状态时，
/// 界面自动跟上（见 EhBot `app/api/status.py`）。
class StatusView {
  const StatusView({
    required this.code,
    required this.label,
    this.tone = 'muted',
    this.live = false,
  });

  factory StatusView.fromJson(Object? json) {
    if (json is! Map) {
      return const StatusView(code: '', label: '');
    }
    return StatusView(
      code: asString(json['code']),
      label: asString(json['label']),
      tone: asString(json['tone'], 'muted'),
      live: asBool(json['live']),
    );
  }

  final String code;
  final String label;

  /// `muted` / `waiting` / `active` / `success` / `danger`。
  final String tone;
  final bool live;

  bool get isEmpty => code.isEmpty && label.isEmpty;
}

/// 封面引用：只暴露缩略图 hash，客户端不接触上游 CDN。
class CoverRef {
  const CoverRef({required this.hash});

  static CoverRef? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final String hash = asString(json['hash']);
    return hash.isEmpty ? null : CoverRef(hash: hash);
  }

  final String hash;
}

/// 候选（`/candidates` 列表项，`candidate_summary`）。
class Candidate {
  const Candidate({
    required this.id,
    required this.title,
    this.artist = '',
    this.category = '',
    this.language = '',
    this.tags = const <String>[],
    this.status = const StatusView(code: '', label: ''),
    this.cover,
    this.canApprove = false,
    this.canReject = false,
  });

  factory Candidate.fromJson(Map<String, dynamic> json) => Candidate(
    id: asString(json['candidate_id']),
    title: asString(json['title']),
    artist: asString(json['artist']),
    category: asString(json['category']),
    language: asString(json['language']),
    tags: asStringList(json['tags']),
    status: StatusView.fromJson(json['status']),
    cover: CoverRef.fromJson(json['cover']),
    canApprove: asBool(_action(json['actions'], 'approve')),
    canReject: asBool(_action(json['actions'], 'reject')),
  );

  final String id;
  final String title;
  final String artist;
  final String category;
  final String language;
  final List<String> tags;
  final StatusView status;
  final CoverRef? cover;
  final bool canApprove;
  final bool canReject;

  String get displayTitle => title.isEmpty ? '未命名' : title;
}

/// 候选列表的一页（含 tab / 搜索 / 计数回显）。
class CandidatePage {
  const CandidatePage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
    this.pageSize = 30,
    this.counts = const <String, int>{},
    this.tabCounts = const <String, int>{},
    this.tab = '',
    this.search = '',
  });

  factory CandidatePage.fromJson(Map<String, dynamic> json) => CandidatePage(
    items: asMapList(json['items']).map(Candidate.fromJson).toList(),
    total: asInt(json['total']),
    page: asInt(json['page'], 1),
    pages: asInt(json['pages'], 1),
    pageSize: asInt(json['page_size'], 30),
    counts: asIntMap(json['counts']),
    tabCounts: asIntMap(json['tab_counts']),
    tab: asString(json['tab']),
    search: asString(json['search']),
  );

  final List<Candidate> items;
  final int total;
  final int page;
  final int pages;
  final int pageSize;
  final Map<String, int> counts;
  final Map<String, int> tabCounts;
  final String tab;
  final String search;
}

/// 活动任务（`job_summary`），队列与历史共用。
class JobSummary {
  const JobSummary({
    required this.id,
    this.candidateId = '',
    this.title = '',
    this.providerLabel = '',
    this.state = const StatusView(code: '', label: ''),
    this.group = '',
    this.progressPercent = 0,
    this.errorMessage = '',
    this.note = '',
    this.updatedAt,
  });

  factory JobSummary.fromJson(Map<String, dynamic> json) => JobSummary(
    id: asString(json['job_id']),
    candidateId: asString(json['candidate_id']),
    title: asString(json['title']),
    providerLabel: asString(asMap(json['provider'])?['label']),
    state: StatusView.fromJson(json['state']),
    group: asString(json['group']),
    progressPercent: asInt(json['progress_percent']),
    errorMessage: asString(json['error_message']),
    note: asString(asMap(json['note'])?['label']),
    updatedAt: parseTimestamp(json['updated_at']),
  );

  final String id;
  final String candidateId;
  final String title;
  final String providerLabel;
  final StatusView state;
  final String group;
  final int progressPercent;
  final String errorMessage;
  final String note;
  final DateTime? updatedAt;

  String get displayTitle {
    if (title.isNotEmpty) {
      return title;
    }
    return candidateId.isEmpty ? '任务 #$id' : '候选 #$candidateId';
  }
}

/// 队列里的一个分组（后端已分好组，客户端不重新分组）。
class JobGroup {
  const JobGroup({
    required this.label,
    required this.count,
    required this.jobs,
  });

  factory JobGroup.fromJson(Map<String, dynamic> json) => JobGroup(
    label: asString(asMap(json['group'])?['label']),
    count: asInt(json['count']),
    jobs: asMapList(json['jobs']).map(JobSummary.fromJson).toList(),
  );

  final String label;
  final int count;
  final List<JobSummary> jobs;
}

/// `GET /api/v1/queue` 的快照。
class QueueSnapshot {
  const QueueSnapshot({
    this.downloads = const <JobGroup>[],
    this.packing = const <JobGroup>[],
    this.downloadCount = 0,
    this.packingCount = 0,
    this.attentionTotal = 0,
    this.live = false,
  });

  factory QueueSnapshot.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? counts = asMap(json['counts']);
    return QueueSnapshot(
      downloads: asMapList(json['downloads']).map(JobGroup.fromJson).toList(),
      packing: asMapList(json['packing']).map(JobGroup.fromJson).toList(),
      downloadCount: asInt(counts?['downloads']),
      packingCount: asInt(counts?['packing']),
      attentionTotal: asInt(asMap(json['attention'])?['total']),
      live: asBool(json['live']),
    );
  }

  final List<JobGroup> downloads;
  final List<JobGroup> packing;
  final int downloadCount;
  final int packingCount;
  final int attentionTotal;
  final bool live;

  bool get isEmpty => downloads.isEmpty && packing.isEmpty;
}

/// 工作台概览（`GET /api/v1/summary`）。
/// 工作台概览（`GET /api/v1/summary`）。
class Summary {
  const Summary({
    this.candidateCounts = const <String, int>{},
    this.downloads = 0,
    this.packing = 0,
    this.activityLive = false,
    this.attentionTotal = 0,
    this.attentionItems = const <JobSummary>[],
    this.startupErrors = const <String>[],
    this.connections = const <String, ConnectionInfo>{},
  });

  factory Summary.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? activity = asMap(json['activity']);
    final Map<String, dynamic>? attention = asMap(json['attention']);
    return Summary(
      candidateCounts: asIntMap(json['candidates']),
      downloads: asInt(activity?['downloads']),
      packing: asInt(activity?['packing']),
      activityLive: asBool(activity?['live']),
      attentionTotal: asInt(attention?['total']),
      attentionItems: asMapList(attention?['items'])
          .map(JobSummary.fromJson)
          .toList(),
      startupErrors: asStringList(json['startup_errors']),
      connections: _parseConnections(json['connections']),
    );
  }

  final Map<String, int> candidateCounts;
  final int downloads;
  final int packing;
  final bool activityLive;
  final int attentionTotal;
  final List<JobSummary> attentionItems;
  final List<String> startupErrors;
  final Map<String, ConnectionInfo> connections;
}

/// 一条外部连接：Telegram / ExHentai。
class ConnectionInfo {
  const ConnectionInfo({
    this.label = '',
    this.identity,
    this.state = const StatusView(code: '', label: ''),
  });

  factory ConnectionInfo.fromJson(Map<String, dynamic> json) => ConnectionInfo(
    label: asString(json['label']),
    identity: asStringOrNull(json['identity']),
    state: StatusView.fromJson(json['state']),
  );

  final String label;
  final String? identity;
  final StatusView state;
}

Map<String, ConnectionInfo> _parseConnections(Object? raw) {
  final Map<String, dynamic>? map = asMap(raw);
  if (map == null) return const <String, ConnectionInfo>{};
  return <String, ConnectionInfo>{
    for (final MapEntry<String, dynamic> entry in map.entries)
      entry.key: ConnectionInfo.fromJson(
        asMap(entry.value) ?? const <String, dynamic>{},
      ),
  };
}

String? asStringOrNull(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return value;
}

class DownloadedWork {
  const DownloadedWork({
    required this.candidateId,
    this.title = '',
    this.artist = '',
    this.category = '',
    this.language = '',
    this.tags = const <String>[],
    this.providerLabel = '',
    this.state = const StatusView(code: '', label: ''),
    this.packLabel = '',
    this.cbzPath = '',
    this.archivePath = '',
    this.archiveSize = 0,
  });

  factory DownloadedWork.fromJson(Map<String, dynamic> json) => DownloadedWork(
    candidateId: asString(json['candidate_id']),
    title: asString(json['title']),
    artist: asString(json['artist']),
    category: asString(json['category']),
    language: asString(json['language']),
    tags: asStringList(json['tags']),
    providerLabel: asString(asMap(json['provider'])?['label']),
    state: StatusView.fromJson(json['state']),
    packLabel: asString(asMap(json['pack'])?['label']),
    cbzPath: asString(json['cbz_path']),
    archivePath: asString(json['archive_path']),
    archiveSize: asInt(json['archive_size']),
  );

  final String candidateId;
  final String title;
  final String artist;
  final String category;
  final String language;
  final List<String> tags;
  final String providerLabel;
  final StatusView state;
  final String packLabel;
  final String cbzPath;
  final String archivePath;
  final int archiveSize;

  String get displayTitle => title.isEmpty ? '候选 #$candidateId' : title;
}

/// `GET /api/v1/downloaded` 的一页。
///
/// 注意：该端点的列表键是 `works`（不是通用信封的 `items`），这里两种都认。
class DownloadedPage {
  const DownloadedPage({
    required this.items,
    required this.total,
    this.tab = '',
    this.counts = const <String, int>{},
    this.live = false,
  });

  factory DownloadedPage.fromJson(Map<String, dynamic> json) {
    final Object? list = json['works'] ?? json['items'];
    return DownloadedPage(
      items: asMapList(list).map(DownloadedWork.fromJson).toList(),
      total: asInt(json['total']),
      tab: asString(json['tab']),
      counts: asIntMap(json['counts']),
      live: asBool(json['live']),
    );
  }

  final List<DownloadedWork> items;
  final int total;
  final String tab;
  final Map<String, int> counts;
  final bool live;
}

/// 详情页的时间线条目（`timeline`）。
class TimelineEntry {
  const TimelineEntry({this.label = '', this.reason = '', this.createdAt});

  factory TimelineEntry.fromJson(Map<String, dynamic> json) => TimelineEntry(
    label: asString(asMap(json['action_view'])?['label']),
    reason: asString(json['reason']),
    createdAt: parseTimestamp(json['created_at']),
  );

  final String label;
  final String reason;
  final DateTime? createdAt;
}

/// 详情页的元数据条目（`metadata`）。
class MetadataEntry {
  const MetadataEntry({
    this.label = '',
    this.value = '',
    this.isManual = false,
    this.isLocked = false,
  });

  factory MetadataEntry.fromJson(Map<String, dynamic> json) => MetadataEntry(
    label: asString(json['field_label']),
    value: asString(json['field_value']),
    isManual: asBool(json['is_manual']),
    isLocked: asBool(json['is_locked']),
  );

  final String label;
  final String value;
  final bool isManual;
  final bool isLocked;
}

/// `GET /api/v1/works/{candidate_id}` 的详情。
class WorkDetail {
  const WorkDetail({
    required this.id,
    this.title = '',
    this.status = const StatusView(code: '', label: ''),
    this.stage = const StatusView(code: '', label: ''),
    this.artist = '',
    this.category = '',
    this.language = '',
    this.tags = const <String>[],
    this.cover,
    this.filterReason = '',
    this.cbzPath = '',
    this.metadata = const <MetadataEntry>[],
    this.timeline = const <TimelineEntry>[],
    this.actions = const <String, bool>{},
    this.prevId,
    this.nextId,
    this.jobCount = 0,
    this.live = false,
  });

  factory WorkDetail.fromJson(Map<String, dynamic> json) => WorkDetail(
    id: asString(json['candidate_id']),
    title: asString(json['title']),
    status: StatusView.fromJson(json['status']),
    stage: StatusView.fromJson(json['stage']),
    artist: asString(json['artist']),
    category: asString(json['category']),
    language: asString(json['language']),
    tags: asStringList(json['tags']),
    cover: CoverRef.fromJson(json['cover']),
    filterReason: asString(json['filter_reason']),
    cbzPath: asString(asMap(json['archive'])?['path']),
    metadata: asMapList(json['metadata']).map(MetadataEntry.fromJson).toList(),
    timeline: asMapList(json['timeline']).map(TimelineEntry.fromJson).toList(),
    actions: _workActionMap(json['actions']),
    prevId: _nullableString(json['prev_id']),
    nextId: _nullableString(json['next_id']),
    jobCount: asMapList(json['jobs']).length,
    live: asBool(json['live']),
  );

  final String id;
  final String title;
  final StatusView status;
  final StatusView stage;
  final String artist;
  final String category;
  final String language;
  final List<String> tags;
  final CoverRef? cover;
  final String filterReason;
  final String cbzPath;
  final List<MetadataEntry> metadata;
  final List<TimelineEntry> timeline;
  final Map<String, bool> actions;
  final String? prevId;
  final String? nextId;
  final int jobCount;
  final bool live;

  String get displayTitle => title.isEmpty ? 'work #$id' : title;

  /// True only when the backend explicitly says the named action is allowed.
  bool can(String name) => actions[name] ?? false;
}

/// Parse the flat `actions` block on a work into `name -> bool` (M6).
Map<String, bool> _workActionMap(Object? raw) {
  final Map<String, dynamic>? map = asMap(raw);
  if (map == null) return const <String, bool>{};
  return <String, bool>{
    for (final MapEntry<String, dynamic> entry in map.entries)
      entry.key: asBool(entry.value),
  };
}

/// Empty string collapses to null so missing keys are indistinguishable from blanks.
String? _nullableString(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return value;
}

class ReviewBatchResult {
  const ReviewBatchResult({
    required this.requested,
    required this.applied,
    this.skipped = const <String>[],
  });

  factory ReviewBatchResult.fromJson(Map<String, dynamic> json) =>
      ReviewBatchResult(
        requested: asInt(json['requested']),
        applied: asMapList(json['applied']).length,
        skipped: asMapList(json['skipped'])
            .map(
              (Map<String, dynamic> item) => asString(item['message'], '被跳过'),
            )
            .toList(),
      );

  final int requested;
  final int applied;
  final List<String> skipped;
}

/// `/api/v1/meta` 里客户端需要的调参值。
class ClientMeta {
  const ClientMeta({
    this.pollingInterval = const Duration(seconds: 10),
    this.idleInterval = const Duration(seconds: 60),
    this.timezone = 'UTC',
  });

  factory ClientMeta.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? polling = asMap(json['polling']);
    return ClientMeta(
      pollingInterval: Duration(
        milliseconds: asInt(polling?['interval_ms'], 10000),
      ),
      idleInterval: Duration(
        milliseconds: asInt(polling?['idle_interval_ms'], 60000),
      ),
      timezone: asString(json['timezone'], 'UTC'),
    );
  }

  final Duration pollingInterval;
  final Duration idleInterval;
  final String timezone;
}

// ------------------------------------------------------------------ 解析助手

String asString(Object? value, [String fallback = '']) =>
    value is String ? value : (value == null ? fallback : '$value');

int asInt(Object? value, [int fallback = 0]) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

bool asBool(Object? value, [bool fallback = false]) =>
    value is bool ? value : fallback;

Map<String, dynamic>? asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<Map<String, dynamic>> asMapList(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const <Map<String, dynamic>>[];

List<String> asStringList(Object? value) => value is List
    ? value
          .map((Object? item) => asString(item))
          .where((String s) => s.isNotEmpty)
          .toList()
    : const <String>[];

Map<String, int> asIntMap(Object? value) => value is Map
    ? value.map<String, int>(
        (Object? key, Object? item) =>
            MapEntry<String, int>('$key', asInt(item)),
      )
    : const <String, int>{};

Object? _action(Object? actions, String name) => asMap(actions)?[name];
