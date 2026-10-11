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
///
/// 详情页的 `jobs[]` 是**同一个形状**（EhBot `serializers.job_summary`），
/// 所以两处共用这一个类：切源与任务操作都要用到 `job_id`。
class JobSummary {
  const JobSummary({
    required this.id,
    this.candidateId = '',
    this.title = '',
    this.providerCode = '',
    this.providerLabel = '',
    this.state = const StatusView(code: '', label: ''),
    this.group = '',
    this.progressPercent = 0,
    this.errorMessage = '',
    this.note = '',
    this.priority = 0,
    this.artifactPath = '',
    this.artifactCbzPath = '',
    this.actions = const <String, bool>{},
    this.torrent = const TorrentState(),
    this.updatedAt,
  });

  factory JobSummary.fromJson(Map<String, dynamic> json) => JobSummary(
    id: asString(json['job_id']),
    candidateId: asString(json['candidate_id']),
    title: asString(json['title']),
    providerCode: asString(asMap(json['provider'])?['code']),
    providerLabel: asString(asMap(json['provider'])?['label']),
    state: StatusView.fromJson(json['state']),
    group: asString(json['group']),
    progressPercent: asInt(json['progress_percent']),
    errorMessage: asString(json['error_message']),
    note: asString(asMap(json['note'])?['label']),
    priority: asInt(json['priority']),
    artifactPath: asString(json['artifact_path']),
    artifactCbzPath: asString(json['artifact_cbz_path']),
    actions: _boolMap(json['actions']),
    torrent: TorrentState.fromJson(json['torrent']),
    updatedAt: parseTimestamp(json['updated_at']),
  );

  final String id;
  final String candidateId;
  final String title;
  final String providerCode;
  final String providerLabel;
  final StatusView state;
  final String group;
  final int progressPercent;
  final String errorMessage;
  final String note;
  final int priority;
  final String artifactPath;
  final String artifactCbzPath;

  /// 这个任务自己能做什么（后端算好的策略：停滞的种子不是失败）。
  final Map<String, bool> actions;
  final TorrentState torrent;
  final DateTime? updatedAt;

  /// 注意键名：`stop_seeding` 是下划线，而 URL 里的动作名是 `stop-seeding`。
  bool get canRetry => actions['retry'] ?? false;
  bool get canPause => actions['pause'] ?? false;
  bool get canResume => actions['resume'] ?? false;
  bool get canCancel => actions['cancel'] ?? false;
  bool get canStopSeeding => actions['stop_seeding'] ?? false;

  bool get hasAnyAction =>
      canRetry || canPause || canResume || canCancel || canStopSeeding || canSwitchSource;

  /// 只有**停滞的种子**才有切源入口——这是 WebUI 活动页的条件，
  /// 因为切源会真的结束当前这条 torrent（`DownloadService.switch_source`）。
  bool get canSwitchSource => torrent.waitingForPeers;

  String get displayTitle {
    if (title.isNotEmpty) {
      return title;
    }
    return candidateId.isEmpty ? '任务 #$id' : '候选 #$candidateId';
  }
}

/// 任务里的 torrent 转移信息（`job_summary.torrent`）。
class TorrentState {
  const TorrentState({
    this.waitingForPeers = false,
    this.seeding = false,
    this.alreadyInClient = false,
    this.stalledMinutes,
    this.detail = '',
  });

  factory TorrentState.fromJson(Object? json) {
    final Map<String, dynamic>? map = asMap(json);
    if (map == null) {
      return const TorrentState();
    }
    return TorrentState(
      waitingForPeers: asBool(map['waiting_for_peers']),
      seeding: asBool(map['seeding']),
      alreadyInClient: asBool(map['already_in_client']),
      stalledMinutes: map['stalled_minutes'] is num
          ? (map['stalled_minutes'] as num).toInt()
          : null,
      detail: asString(map['detail']),
    );
  }

  final bool waitingForPeers;
  final bool seeding;
  final bool alreadyInClient;

  /// `null` 表示「没停滞」，与「停滞 0 分钟」不同。
  final int? stalledMinutes;
  final String detail;
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
    this.providerCode = '',
    this.providerLabel = '',
    this.state = const StatusView(code: '', label: ''),
    this.packCode = '',
    this.packLabel = '',
    this.cbzPath = '',
    this.libraryRelativePath = '',
    this.archivePath = '',
    this.archiveSize = 0,
    this.actions = const <String, bool>{},
  });

  factory DownloadedWork.fromJson(Map<String, dynamic> json) => DownloadedWork(
    candidateId: asString(json['candidate_id']),
    title: asString(json['title']),
    artist: asString(json['artist']),
    category: asString(json['category']),
    language: asString(json['language']),
    tags: asStringList(json['tags']),
    providerCode: asString(asMap(json['provider'])?['code']),
    providerLabel: asString(asMap(json['provider'])?['label']),
    state: StatusView.fromJson(json['state']),
    packCode: asString(asMap(json['pack'])?['code']),
    packLabel: asString(asMap(json['pack'])?['label']),
    cbzPath: asString(json['cbz_path']),
    libraryRelativePath: asString(json['library_relative_path']),
    archivePath: asString(json['archive_path']),
    archiveSize: asInt(json['archive_size']),
    actions: _boolMap(json['actions']),
  );

  final String candidateId;
  final String title;
  final String artist;
  final String category;
  final String language;
  final List<String> tags;
  final String providerCode;
  final String providerLabel;
  final StatusView state;
  final String packCode;
  final String packLabel;
  final String cbzPath;

  /// 相对库根的路径（改名 / 移动表单的目录栏从这里取）。
  final String libraryRelativePath;
  final String archivePath;
  final int archiveSize;

  /// 后端算好的可做动作：`repack` / `remove` / `redownload` / `rename`。
  /// 在途的任务会同时压下 `remove` 与 `redownload`（会和 worker 抢同一行）。
  final Map<String, bool> actions;

  bool get canRepack => actions['repack'] ?? false;
  bool get canRemove => actions['remove'] ?? false;
  bool get canRedownload => actions['redownload'] ?? false;
  bool get canRename => actions['rename'] ?? false;

  /// 已打包的再打包叫「重新打包」，没打包过的是第一次「打包」。
  bool get isPacked => packCode == 'packed';

  /// 改名表单的两个预填值，与网页抽屉同一套算法：
  /// 文件名取 CBZ 路径的最后一段（去掉 `.cbz`），目录取相对路径的 dirname。
  String get renameFilename {
    final String base = cbzPath.split(RegExp(r'[\\/]')).last;
    return base.toLowerCase().endsWith('.cbz')
        ? base.substring(0, base.length - 4)
        : base;
  }

  String get renameDirectory {
    final List<String> parts = libraryRelativePath.split('/');
    if (parts.length <= 1) {
      return '';
    }
    parts.removeLast();
    return parts.join('/');
  }

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
    this.name = '',
    this.label = '',
    this.value = '',
    this.isManual = false,
    this.isLocked = false,
  });

  factory MetadataEntry.fromJson(Map<String, dynamic> json) => MetadataEntry(
    name: asString(json['field_name']),
    label: asString(json['field_label']),
    value: asString(json['field_value']),
    isManual: asBool(json['is_manual']),
    isLocked: asBool(json['is_locked']),
  );

  /// 后端字段名（`METADATA_FIELDS`，如 `Title` / `Artist`），PATCH 时要用它。
  final String name;
  final String label;
  final String value;
  final bool isManual;
  final bool isLocked;
}

/// 详情页 `actions.sources[]` 的一项：四个来源之一。
///
/// `action` 是**网页路径**（`/candidates/{id}/…`），移动端不能直接调——
/// 必须用 [providerCode] 走 `POST /api/v1/jobs/{job_id}/switch-source`。
class SourceAction {
  const SourceAction({
    this.providerCode = '',
    this.providerLabel = '',
    this.available = false,
    this.hint = '',
  });

  factory SourceAction.fromJson(Map<String, dynamic> json) => SourceAction(
    providerCode: asString(asMap(json['provider'])?['code']),
    providerLabel: asString(asMap(json['provider'])?['label']),
    available: asBool(json['available']),
    hint: asString(json['hint']),
  );

  final String providerCode;
  final String providerLabel;
  final bool available;
  final String hint;
}

/// `/works/{id}` 的 `actions`：平铺布尔 + 四个来源。
///
/// 真实键（EhBot `app/api/works.py::work_actions`）：`approve` / `reject` /
/// `needs_revision` / `requeue` / `edit_metadata` / `fetch_metadata` /
/// `convert` / `reconvert` / `edit_archive_path` / `sources[]`。
/// **没有** `delete` / `delete_files` / `repack` / `switch_source_*`。
class WorkActions {
  const WorkActions({
    this.flags = const <String, bool>{},
    this.sources = const <SourceAction>[],
  });

  factory WorkActions.fromJson(Object? json) {
    final Map<String, dynamic>? map = asMap(json);
    if (map == null) {
      return const WorkActions();
    }
    return WorkActions(
      flags: _boolMap(map),
      sources: asMapList(map['sources']).map(SourceAction.fromJson).toList(),
    );
  }

  final Map<String, bool> flags;
  final List<SourceAction> sources;

  bool get isEmpty => flags.isEmpty && sources.isEmpty;

  /// True only when the backend explicitly says the named action is allowed.
  bool can(String name) => flags[name] ?? false;
}

/// 来源消息的一条附件（`messages[].attachments[]`）。
class WorkAttachment {
  const WorkAttachment({
    this.kind = const StatusView(code: '', label: ''),
    this.fileName = '',
  });

  factory WorkAttachment.fromJson(Map<String, dynamic> json) => WorkAttachment(
    kind: StatusView.fromJson(json['kind']),
    fileName: asString(json['file_name']),
  );

  final StatusView kind;
  final String fileName;
}

/// 来源消息（`messages[]`）。
class WorkMessage {
  const WorkMessage({
    this.chatTitle = '',
    this.messageId = '',
    this.text = '',
    this.attachments = const <WorkAttachment>[],
    this.date,
  });

  factory WorkMessage.fromJson(Map<String, dynamic> json) => WorkMessage(
    chatTitle: asString(json['chat_title']),
    messageId: asString(json['message_id']),
    text: asString(json['message_text']),
    attachments: asMapList(json['attachments'])
        .map(WorkAttachment.fromJson)
        .toList(),
    date: parseTimestamp(json['message_date']),
  );

  final String chatTitle;
  final String messageId;
  final String text;
  final List<WorkAttachment> attachments;
  final DateTime? date;
}

/// 归档路径表单的当前值（`archive_path`）。
class ArchivePathView {
  const ArchivePathView({this.directory = '', this.filename = ''});

  factory ArchivePathView.fromJson(Object? json) {
    final Map<String, dynamic>? map = asMap(json);
    if (map == null) {
      return const ArchivePathView();
    }
    return ArchivePathView(
      directory: asString(map['directory']),
      filename: asString(map['filename']),
    );
  }

  final String directory;
  final String filename;

  bool get isEmpty => directory.isEmpty && filename.isEmpty;

  bool get isNotEmpty => !isEmpty;
}

/// `GET /api/v1/works/{candidate_id}` 的详情。
///
/// 注意：JSON 详情**不含**顶层 `artist` / `category` / `tags` / `cover`，
/// 也**不含** `prev_id` / `next_id`（只有 HTML 页面有）。这些字段这里保留，
/// 是为了让列表页把已有的候选信息透传进来做兜底。
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
    this.filterOrigin = '',
    this.warningHint = '',
    this.warnings = const <StatusView>[],
    this.exGid = '',
    this.previewUrl = '',
    this.torrentCount,
    this.torrentHash = '',
    this.magnetUrl = '',
    this.cbzPath = '',
    this.archivePath = const ArchivePathView(),
    this.metadata = const <MetadataEntry>[],
    this.rawMetadata = const <MetadataEntry>[],
    this.messages = const <WorkMessage>[],
    this.timeline = const <TimelineEntry>[],
    this.actions = const WorkActions(),
    this.jobs = const <JobSummary>[],
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
    filterOrigin: asString(json['filter_origin']),
    warningHint: asString(json['warning_hint']),
    warnings: asMapList(json['warnings'])
        .map(StatusView.fromJson)
        .toList(),
    exGid: asString(json['ex_gid']),
    previewUrl: asString(json['preview_url']),
    torrentCount: json['torrent_count'] is num
        ? (json['torrent_count'] as num).toInt()
        : null,
    torrentHash: asString(json['torrent_hash']),
    magnetUrl: asString(json['magnet_url']),
    cbzPath: asString(asMap(json['archive'])?['path']),
    archivePath: ArchivePathView.fromJson(json['archive_path']),
    metadata: asMapList(json['metadata']).map(MetadataEntry.fromJson).toList(),
    rawMetadata: asMapList(json['raw_metadata'])
        .map(MetadataEntry.fromJson)
        .toList(),
    messages: asMapList(json['messages']).map(WorkMessage.fromJson).toList(),
    timeline: asMapList(json['timeline']).map(TimelineEntry.fromJson).toList(),
    actions: WorkActions.fromJson(json['actions']),
    jobs: asMapList(json['jobs']).map(JobSummary.fromJson).toList(),
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

  /// 谁给出了这个过滤裁决：`自动规则` / `人工` / `来源元数据规则`；空串表示无从解释。
  final String filterOrigin;
  final String warningHint;
  final List<StatusView> warnings;
  final String exGid;
  final String previewUrl;

  /// `null` 表示尚未查询（与「确认没有种子」不同）。
  final int? torrentCount;
  final String torrentHash;
  final String magnetUrl;
  final String cbzPath;
  final ArchivePathView archivePath;
  final List<MetadataEntry> metadata;
  final List<MetadataEntry> rawMetadata;
  final List<WorkMessage> messages;
  final List<TimelineEntry> timeline;

  /// 当前可见动作（真实键见 [WorkActions] 的注释）。
  final WorkActions actions;
  final List<JobSummary> jobs;
  final bool live;

  String get displayTitle => title.isEmpty ? 'work #$id' : title;

  int get jobCount => jobs.length;

  bool get hasGallery => exGid.isNotEmpty;

  /// 已经有归档产物了（`archive.path` 非空 = 后端说这本书已经打包过）。
  bool get isPackaged => cbzPath.isNotEmpty;

  /// True only when the backend explicitly says the named action is allowed.
  bool can(String name) => actions.can(name);
}

/// Parse a `{name: bool}` block (work `actions`, job `actions`) into a map.
///
/// Non-boolean values collapse to false: `actions` on a work carries a
/// `sources` **list** beside the flags, and that list is read by its own parser.
Map<String, bool> _boolMap(Object? raw) {
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

// ------------------------------------------------------------ M8 模型

/// `POST /api/v1/candidates/manual` 的结果。
///
/// 命中重复时后端回 `existing_candidate_id`，页面据此给「查看已有候选」按钮。
class ManualAddResult {
  const ManualAddResult({
    this.candidateId,
    this.existingCandidateId,
    this.message = '',
    this.duplicate = false,
  });

  factory ManualAddResult.fromJson(Map<String, dynamic> json) =>
      ManualAddResult(
        candidateId: _nullableString(json['candidate_id']),
        existingCandidateId: _nullableString(json['existing_candidate_id']),
        message: asString(json['message']),
        duplicate: asBool(json['duplicate']),
      );

  final String? candidateId;
  final String? existingCandidateId;
  final String message;

  /// 后端把重复报成 **409** `CANDIDATE_DUPLICATE`（EhBot R66），
  /// 所以这个标记由 `EhBotApi.manualAdd` 在 409 分支上置位，而不是解析 200 的响应体。
  final bool duplicate;

  bool get isDuplicate => duplicate || existingCandidateId != null;
}

/// 去重计划里的一件作品。
class DedupEntry {
  const DedupEntry({
    required this.candidateId,
    this.title = '',
    this.status = const StatusView(code: '', label: ''),
    this.packLabel = '',
    this.pageCount,
    this.reason = '',
  });

  factory DedupEntry.fromJson(Map<String, dynamic> json) => DedupEntry(
    candidateId: asString(json['candidate_id']),
    title: asString(json['title']),
    status: StatusView.fromJson(json['status']),
    packLabel: asString(json['pack_label']),
    pageCount: json['page_count'] is num
        ? (json['page_count'] as num).toInt()
        : null,
    reason: asString(json['reason']),
  );

  final String candidateId;
  final String title;
  final StatusView status;
  final String packLabel;
  final int? pageCount;
  final String reason;

  String get displayTitle => title.isEmpty ? '作品 #$candidateId' : title;
}

/// 一个重复画廊分组：保留一件、移除其余。
class DedupGroup {
  const DedupGroup({
    required this.exGid,
    required this.keep,
    this.remove = const <DedupEntry>[],
  });

  factory DedupGroup.fromJson(Map<String, dynamic> json) => DedupGroup(
    exGid: asString(json['ex_gid']),
    keep: DedupEntry.fromJson(asMap(json['keep']) ?? const <String, dynamic>{}),
    remove: asMapList(json['remove']).map(DedupEntry.fromJson).toList(),
  );

  final String exGid;
  final DedupEntry keep;
  final List<DedupEntry> remove;
}

/// `GET /api/v1/dedup/plan`。
class DedupPlan {
  const DedupPlan({this.groups = const <DedupGroup>[], this.removable = 0});

  factory DedupPlan.fromJson(Map<String, dynamic> json) => DedupPlan(
    groups: asMapList(json['groups']).map(DedupGroup.fromJson).toList(),
    removable: asInt(json['removable']),
  );

  final List<DedupGroup> groups;
  final int removable;

  bool get isEmpty => groups.isEmpty;
}

/// `POST /api/v1/dedup`。
class DedupResult {
  const DedupResult({this.removed = 0, this.message = ''});

  factory DedupResult.fromJson(Map<String, dynamic> json) => DedupResult(
    removed: asInt(json['removed']),
    message: asString(json['message']),
  );

  final int removed;
  final String message;
}

/// 一条运行日志（`GET /api/v1/logs` 与 `/logs/stream`）。
class LogEntry {
  const LogEntry({
    required this.level,
    this.timestamp,
    this.logger = '',
    this.event = '',
    this.raw = '',
    this.errorMessage = '',
    this.errorCode = '',
    this.jobId = '',
    this.candidateId = '',
    this.requestId = '',
    this.exception = '',
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    level: StatusView.fromJson(json['level']),
    timestamp: parseTimestamp(json['timestamp']),
    logger: asString(json['logger']),
    event: asString(json['event']),
    raw: asString(json['raw']),
    errorMessage: asString(json['error_message']),
    errorCode: asString(json['error_code']),
    jobId: asString(json['job_id']),
    candidateId: asString(json['candidate_id']),
    requestId: asString(json['request_id']),
    exception: asString(json['exception']),
  );

  final StatusView level;
  final DateTime? timestamp;
  final String logger;
  final String event;
  final String raw;
  final String errorMessage;
  final String errorCode;
  final String jobId;
  final String candidateId;
  final String requestId;
  final String exception;

  String get message => raw.isNotEmpty ? raw : event;
}

/// 日志等级筛选项（`code` 为空表示「全部」）。
class LogLevelOption {
  const LogLevelOption({required this.code, required this.label});

  factory LogLevelOption.fromJson(Map<String, dynamic> json) => LogLevelOption(
    code: asString(json['code']),
    label: asString(json['label']),
  );

  final String code;
  final String label;
}

/// `GET /api/v1/logs` 的一页。
class LogsPageData {
  const LogsPageData({
    this.entries = const <LogEntry>[],
    this.levels = const <LogLevelOption>[],
    this.level = '',
    this.limit = 200,
  });

  factory LogsPageData.fromJson(Map<String, dynamic> json) => LogsPageData(
    entries: asMapList(json['entries']).map(LogEntry.fromJson).toList(),
    levels: asMapList(json['levels']).map(LogLevelOption.fromJson).toList(),
    level: asString(json['level']),
    limit: asInt(json['limit'], 200),
  );

  final List<LogEntry> entries;
  final List<LogLevelOption> levels;
  final String level;
  final int limit;
}

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
