import 'dart:async';

import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../media/thumbnail_loader.dart';
import 'error_text.dart';
import 'theme.dart';
import 'widgets/async_view.dart';
import 'widgets/cover_thumb.dart';
import 'widgets/eh_card.dart';
import 'widgets/job_actions.dart';
import 'widgets/large_title_app_bar.dart';
import 'widgets/section_header.dart';
import 'widgets/tag_chip.dart';
import 'widgets/tone_chip.dart';

/// 作品详情：封面 + 元数据 + 消息 + 时间线 + 任务，**操作在固定底栏**。
///
/// 三条规矩：
/// 1. 按钮可见性读后端真实的 `actions` 键（见 [WorkActions]），不自造键名——
///    M9 之前客户端按 `delete` / `switch_source_*` 取值，那些键后端从不返回，
///    于是删除与切源按钮一个都不渲染。
/// 2. 任务类动作一律用 **job id**（`job_summary.job_id`），不是候选 id。
/// 3. 后端 `/api/v1` 还没有的动作（重获元数据 / 打包 / 需修订 / 按来源拉取）
///    渲染为**禁用**并说明原因，不装成能点的按钮去撞 404。
class CandidateDetailPage extends StatefulWidget {
  const CandidateDetailPage({
    super.key,
    required this.api,
    required this.thumbnails,
    required this.candidate,
  });

  final EhBotApi api;
  final ThumbnailLoader thumbnails;
  final Candidate candidate;

  @override
  State<CandidateDetailPage> createState() => _CandidateDetailPageState();
}

class _CandidateDetailPageState extends State<CandidateDetailPage> {
  late Future<WorkDetail> _future = _load();

  /// 已加载的详情：底栏要拿 `actions` 才知道显示哪些按钮。
  WorkDetail? _detail;
  bool _busy = false;

  Future<WorkDetail> _load() async {
    final WorkDetail detail = await widget.api.work(widget.candidate.id);
    if (mounted) {
      setState(() => _detail = detail);
    }
    return detail;
  }

  void _reload() {
    setState(() => _future = _load());
  }

  /// 统一的动作外壳：置忙 → 跑 → 提示 → 重载；失败给中文说明。
  Future<void> _guard(
    Future<void> Function() action, {
    String done = '',
    bool popOnSuccess = false,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      if (done.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
      if (popOnSuccess) {
        Navigator.of(context).pop(true);
        return;
      }
      _reload();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error))));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// 通过 / 驳回：走批量端点（单个也是批量），成功后回上一页刷新列表。
  Future<void> _review(String action) => _guard(
    () async {
      final ReviewBatchResult result = await widget.api.review(
        action: action,
        candidateIds: <String>[widget.candidate.id],
      );
      final String verb = action == 'approve' ? '通过' : '驳回';
      final String message = result.skipped.isEmpty
          ? '已$verb ${result.applied} 个候选。'
          : '已$verb ${result.applied} 个；${result.skipped.length} 个被跳过：'
                '${result.skipped.first}';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    },
    popOnSuccess: true,
  );

  /// 彻底删除：`delete`（留文件）/ `delete-files`（连文件一起）。
  Future<void> _delete({required bool deleteFiles}) async {
    final bool ok = await confirmDialog(
      context,
      title: deleteFiles ? '彻底删除并删除文件' : '彻底删除这件作品',
      message: deleteFiles
          ? '除候选的全部记录外，还会删除已下载的压缩包与已归档的 CBZ；此操作不可恢复。'
          : '候选记录、消息、元数据与审核历史都会删除，已下载的压缩包与已归档的 CBZ 保留；'
                '此操作不可恢复。',
      confirmLabel: deleteFiles ? '确认删除文件' : '确认彻底删除',
    );
    if (!ok || !mounted) {
      return;
    }
    await _guard(
      () async {
        final ReviewBatchResult result = await widget.api.deleteCandidates(
          candidateIds: <String>[widget.candidate.id],
          deleteFiles: deleteFiles,
        );
        final String message = result.applied > 0
            ? '已删除这件作品。'
            : '删除被拒绝：${result.skipped.isEmpty ? '服务端没有说明原因' : result.skipped.first}';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      popOnSuccess: true,
    );
  }

  Future<void> _runJobAction(JobSummary job, JobActionSpec spec) async {
    if (spec.confirm != null) {
      final bool ok = await confirmDialog(
        context,
        title: spec.label,
        message: spec.confirm!,
        confirmLabel: spec.label,
      );
      if (!ok || !mounted) {
        return;
      }
    }
    await _guard(
      () => widget.api.jobAction(jobId: job.id, action: spec.action),
      done: '已${spec.label}：任务 #${job.id}',
    );
  }

  Future<void> _switchSource(JobSummary job, SwitchSourceTarget target) async {
    final bool ok = await confirmDialog(
      context,
      title: target.confirmTitle,
      message: target.confirmMessage,
      confirmLabel: target.confirmLabel,
    );
    if (!ok || !mounted) {
      return;
    }
    await _guard(
      () => widget.api.switchSource(jobId: job.id, provider: target.provider),
      done: '已改用 ${target.label}（原任务 #${job.id} 已结束）',
    );
  }

  Future<void> _editMetadata(MetadataEntry entry) async {
    final MetadataEditResult? result = await showDialog<MetadataEditResult>(
      context: context,
      builder: (BuildContext c) => MetadataEditor(entry: entry),
    );
    if (result == null || !mounted) {
      return;
    }
    await _guard(
      () => widget.api.updateMetadata(
        candidateId: widget.candidate.id,
        fields: <String, String>{entry.name: result.value},
        locks: result.locked == entry.isLocked
            ? const <String, bool>{}
            : <String, bool>{entry.name: result.locked},
      ),
      done: '已保存 ${entry.label.isEmpty ? entry.name : entry.label}',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AsyncView<WorkDetail>(
      future: _future,
      onRetry: _reload,
      builder: (BuildContext context, WorkDetail detail) => CustomScrollView(
        key: const ValueKey<String>('detail-scroll'),
        slivers: <Widget>[
          EhLargeTitleAppBar(
            title: widget.candidate.displayTitle,
            subtitle: detail.stage.label.isEmpty ? null : detail.stage.label,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList.list(children: _content(context, detail)),
          ),
        ],
      ),
    ),
    bottomNavigationBar: _detail == null
        ? null
        : _actionBar(context, _detail!),
  );

  List<Widget> _content(BuildContext context, WorkDetail detail) => <Widget>[
    _overview(context, detail),
    if (detail.warnings.isNotEmpty || detail.warningHint.isNotEmpty) ...<Widget>[
      const SizedBox(height: EhSpacing.m),
      EhCard(
        tone: EhCardTone.warning,
        dense: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final StatusView warning in detail.warnings)
                  ToneChip.status(status: warning),
              ],
            ),
            if (detail.warningHint.isNotEmpty) ...<Widget>[
              if (detail.warnings.isNotEmpty) const SizedBox(height: 4),
              Text(detail.warningHint),
            ],
          ],
        ),
      ),
    ],
    if (detail.filterReason.isNotEmpty || detail.filterOrigin.isNotEmpty) ...[
      const SizedBox(height: EhSpacing.m),
      EhCard(
        tone: EhCardTone.warning,
        dense: true,
        child: Text(
          detail.filterOrigin.isEmpty
              ? '过滤说明：${detail.filterReason}'
              : '过滤说明（${detail.filterOrigin}）：${detail.filterReason}',
        ),
      ),
    ],
    if (detail.jobs.isNotEmpty) ...<Widget>[
      const SectionHeader(title: '任务'),
      for (final JobSummary job in detail.jobs) _jobCard(context, job),
    ],
    if (detail.metadata.isNotEmpty) ...<Widget>[
      const SectionHeader(title: '元数据'),
      for (final MetadataEntry entry in detail.metadata)
        _kv(
          context,
          entry.label,
          entry.value,
          trailing: entry.isLocked
              ? '已锁定'
              : (entry.isManual ? '手动' : null),
          onTap: entry.name.isEmpty ? null : () => _editMetadata(entry),
        ),
    ],
    if (detail.rawMetadata.isNotEmpty) ...<Widget>[
      const SectionHeader(title: '原始元数据'),
      for (final MetadataEntry entry in detail.rawMetadata)
        _kv(context, entry.label, entry.value),
    ],
    if (detail.archivePath.isNotEmpty ||
        detail.cbzPath.isNotEmpty ||
        detail.exGid.isNotEmpty ||
        detail.torrentHash.isNotEmpty) ...<Widget>[
      const SectionHeader(title: '归档与来源'),
      if (detail.exGid.isNotEmpty) _kv(context, '画廊 ID', detail.exGid),
      if (detail.previewUrl.isNotEmpty) _kv(context, '预览页', detail.previewUrl),
      if (detail.torrentCount != null)
        _kv(context, '种子数', '${detail.torrentCount}'),
      if (detail.torrentHash.isNotEmpty) _kv(context, '种子 Hash', detail.torrentHash),
      if (detail.magnetUrl.isNotEmpty) _kv(context, '磁力链', detail.magnetUrl),
      if (detail.archivePath.directory.isNotEmpty)
        _kv(context, '归档目录', detail.archivePath.directory),
      if (detail.archivePath.filename.isNotEmpty)
        _kv(context, '归档文件名', detail.archivePath.filename),
      if (detail.cbzPath.isNotEmpty) _kv(context, 'CBZ 路径', detail.cbzPath),
    ],
    if (detail.messages.isNotEmpty) ...<Widget>[
      const SectionHeader(title: '来源消息'),
      for (final WorkMessage message in detail.messages)
        _messageCard(context, message),
    ],
    if (detail.timeline.isNotEmpty) ...<Widget>[
      const SectionHeader(title: '时间线'),
      for (final TimelineEntry entry in detail.timeline)
        _kv(
          context,
          entry.label,
          entry.reason,
          trailing: _formatTime(entry.createdAt),
        ),
    ],
  ];

  /// 固定操作底栏：横向可滚动，主操作在最左，危险动作在最右。
  ///
  /// WebUI 的动作条是 `position: sticky`（`.ui-actionbar`），这里对应
  /// `Scaffold.bottomNavigationBar`——不必滑到底就能操作。
  Widget _actionBar(BuildContext context, WorkDetail detail) {
    final List<Widget> row = <Widget>[
      if (detail.can('approve'))
        FilledButton(
          key: const ValueKey<String>('detail-approve'),
          onPressed: _busy ? null : () => _review('approve'),
          child: const Text('通过'),
        ),
      if (detail.can('reject'))
        OutlinedButton(
          key: const ValueKey<String>('detail-reject'),
          onPressed: _busy ? null : () => _review('reject'),
          child: const Text('驳回'),
        ),
      if (detail.can('needs_revision'))
        _pending(
          'detail-action-needs_revision',
          '要求修订',
          kActionEndpointMissingHint,
        ),
      if (detail.can('requeue'))
        OutlinedButton(
          key: const ValueKey<String>('detail-action-requeue'),
          onPressed: _busy
              ? null
              : () => _guard(
                  () => widget.api.requeueWork(widget.candidate.id),
                  done: '已重新排队。',
                ),
          child: const Text('重新排队'),
        ),
      if (detail.can('fetch_metadata'))
        _pending(
          'detail-action-fetch_metadata',
          '拉取元数据',
          kActionEndpointMissingHint,
        ),
      if (detail.can('reconvert') || detail.can('convert'))
        _pending(
          'detail-action-convert',
          detail.can('reconvert') ? '重新打包' : '打包为 CBZ',
          kActionEndpointMissingHint,
        ),
      for (final SourceAction source in detail.actions.sources)
        _pending(
          'detail-action-source-${source.providerCode}',
          source.providerLabel.isEmpty
              ? source.providerCode
              : source.providerLabel,
          source.available
              ? kActionEndpointMissingHint
              : (source.hint.isEmpty ? '这个来源现在不可用' : source.hint),
        ),
      if (rowHasContent(detail))
        const _ActionDivider(),
      OutlinedButton(
        key: const ValueKey<String>('detail-delete'),
        onPressed: _busy ? null : () => _delete(deleteFiles: false),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        child: const Text('彻底删除'),
      ),
      OutlinedButton(
        key: const ValueKey<String>('detail-delete-files'),
        onPressed: _busy ? null : () => _delete(deleteFiles: true),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        child: const Text('彻底删除并删文件'),
      ),
    ];

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: EhSpacing.l),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < row.length; i++) ...<Widget>[
                  if (i > 0 && row[i] is! _ActionDivider)
                    const SizedBox(width: EhSpacing.s),
                  row[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 「后端 /api/v1 还没有这个动作」的禁用按钮：能看见、知道为什么不能点。
  Widget _pending(String key, String label, String reason) => Tooltip(
    message: reason,
    child: OutlinedButton(
      key: ValueKey<String>(key),
      onPressed: null,
      child: Text(label),
    ),
  );

  Widget _overview(BuildContext context, WorkDetail detail) {
    final CoverRef? cover = detail.cover ?? widget.candidate.cover;
    final List<String> tags = detail.tags.isNotEmpty
        ? detail.tags
        : widget.candidate.tags;
    final String artist = detail.artist.isNotEmpty
        ? detail.artist
        : widget.candidate.artist;
    final String category = detail.category.isNotEmpty
        ? detail.category
        : widget.candidate.category;
    final String language = detail.language.isNotEmpty
        ? detail.language
        : widget.candidate.language;
    return EhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CoverThumb(
                loader: widget.thumbnails,
                hash: cover?.hash,
                width: 96,
                height: 128,
                radius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      detail.displayTitle,
                      key: const ValueKey<String>('detail-title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        ToneChip.status(status: detail.status),
                        ToneChip.status(status: detail.stage),
                        if (artist.isNotEmpty) TagChip(label: artist),
                        if (category.isNotEmpty) TagChip(label: category),
                        if (language.isNotEmpty) TagChip(label: language),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                for (final String tag in tags) TagChip(label: tag),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _jobCard(BuildContext context, JobSummary job) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: EhCard(
      key: ValueKey<String>('detail-job-${job.id}'),
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  job.providerLabel.isEmpty
                      ? '任务 #${job.id}'
                      : '${job.providerLabel}（#${job.id}）',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              ToneChip.status(status: job.state),
            ],
          ),
          if (job.errorMessage.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(job.errorMessage),
          ] else if (job.note.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(job.note),
          ] else if (job.torrent.detail.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(job.torrent.detail, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (job.state.live && job.progressPercent > 0) ...<Widget>[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: job.progressPercent / 100),
          ],
          JobActionsBar(
            job: job,
            busy: _busy,
            onRun: (JobActionSpec spec) => unawaited(_runJobAction(job, spec)),
            onSwitchSource: (SwitchSourceTarget target) =>
                unawaited(_switchSource(job, target)),
          ),
        ],
      ),
    ),
  );

  Widget _messageCard(BuildContext context, WorkMessage message) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: EhCard(
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  message.chatTitle,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              Text(
                _formatTime(message.date),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          if (message.text.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(message.text),
          ],
          if (message.attachments.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (final WorkAttachment attachment in message.attachments) ...[
                  ToneChip.status(status: attachment.kind),
                  if (attachment.fileName.isNotEmpty)
                    Text(
                      attachment.fileName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ],
            ),
          ],
        ],
      ),
    ),
  );

  Widget _kv(
    BuildContext context,
    String label,
    String value, {
    String? trailing,
    VoidCallback? onTap,
  }) {
    final Widget body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (trailing != null)
            Text(trailing, style: Theme.of(context).textTheme.bodySmall),
          if (onTap != null) const Icon(Icons.edit_outlined, size: 16),
        ],
      ),
    );
    if (onTap == null) {
      return body;
    }
    return InkWell(
      key: ValueKey<String>('detail-metadata-$label'),
      onTap: onTap,
      child: body,
    );
  }
}

/// 元数据编辑对话框的结果。
class MetadataEditResult {
  const MetadataEditResult({required this.value, required this.locked});

  final String value;
  final bool locked;
}

/// 改一个元数据字段的值，顺带（可选）锁定它。
///
/// 独立成 StatefulWidget 是因为它自己持有 `TextEditingController`：
/// 在弹窗的退场动画还在跑的时候由调用方 `dispose`，会让 TextField
/// 拿到一个已经释放的 controller。
class MetadataEditor extends StatefulWidget {
  const MetadataEditor({super.key, required this.entry});

  final MetadataEntry entry;

  @override
  State<MetadataEditor> createState() => _MetadataEditorState();
}

class _MetadataEditorState extends State<MetadataEditor> {
  late final TextEditingController _value = TextEditingController(
    text: widget.entry.value,
  );
  late bool _locked = widget.entry.isLocked;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.entry.label.isEmpty ? widget.entry.name : widget.entry.label,
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          key: const ValueKey<String>('metadata-value'),
          controller: _value,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(
            labelText: '值',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: EhSpacing.s),
        CheckboxListTile(
          key: const ValueKey<String>('metadata-lock'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _locked,
          onChanged: (bool? v) => setState(() => _locked = v ?? false),
          title: const Text('锁定'),
          subtitle: const Text('锁定后重获元数据不会覆盖这个值'),
        ),
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const ValueKey<String>('metadata-save'),
        onPressed: () => Navigator.of(context).pop(
          MetadataEditResult(value: _value.text, locked: _locked),
        ),
        child: const Text('保存'),
      ),
    ],
  );
}

/// 危险动作与普通动作之间的竖分隔线。
class _ActionDivider extends StatelessWidget {
  const _ActionDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: EhSpacing.s),
    child: SizedBox(
      height: 28,
      child: VerticalDivider(
        width: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
  );
}

/// 底栏里有没有「非删除」的动作——决定要不要那条分隔线。
bool rowHasContent(WorkDetail detail) =>
    detail.can('approve') ||
    detail.can('reject') ||
    detail.can('needs_revision') ||
    detail.can('requeue') ||
    detail.can('fetch_metadata') ||
    detail.can('convert') ||
    detail.can('reconvert') ||
    detail.actions.sources.isNotEmpty;

String _formatTime(DateTime? time) {
  if (time == null) {
    return '';
  }
  final DateTime local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
