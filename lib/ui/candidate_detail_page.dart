import 'dart:async';

import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../media/thumbnail_loader.dart';
import 'error_text.dart';
import 'widgets/async_view.dart';
import 'widgets/status_chip.dart';
import 'widgets/thumbnail_image.dart';

/// 详情页：先封面 + 元数据 + 时间线 + 通过 / 驳回 + M6 新增的重获 / 重打 / 重转 / 切源 / 重排队 / 删除。
///
/// 后端返回的 `actions` 字段控制哪些按钮可见；缺字段则不显示（不是禁用）。
///
/// 前后寲选项仅在后端返回 `prev_id` / `next_id`时出现；点击后 push 同一个页面但换 candidateId。
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
  late Future<WorkDetail> _future = widget.api.work(widget.candidate.id);
  bool _busy = false;

  void _reload() {
    setState(() => _future = widget.api.work(widget.candidate.id));
  }

  Future<void> _review(String action) async {
    setState(() => _busy = true);
    try {
      final ReviewBatchResult result = await widget.api.review(
        action: action,
        candidateIds: <String>[widget.candidate.id],
      );
      if (!mounted) {
        return;
      }
      final String verb = action == 'approve' ? '通过' : '驳回';
      final String message = result.skipped.isEmpty
          ? '已$verb ${result.applied} 个候选。'
          : '已$verb ${result.applied} 个；${result.skipped.length} 个被跳过：${result.skipped.first}';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(describeError(error))));
    }
  }

  Future<void> _jobAction(String action) async {
    final String id = widget.candidate.id;
    try {
      await widget.api.jobAction(id: id, action: action);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$action: ok')));
      _reload();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(describeError(error))));
    }
  }

  Future<void> _confirmAndRun(String action, String label) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: Text('确认$label'),
        content: Text('确定要“$label”？该操作不可撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(label),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _jobAction(action);
    }
  }

  void _openSibling(String? id) {
    if (id == null || id.isEmpty) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<bool>(
        builder: (BuildContext _) => CandidateDetailPage(
          api: widget.api,
          thumbnails: widget.thumbnails,
          candidate: Candidate(id: id, title: ''),
        ),
      ),
    );
  }

  Widget _actionButton(
    WorkDetail detail,
    String name, {
    required String label,
    bool filled = false,
    bool confirm = false,
  }) {
    if (!detail.can(name)) {
      return const SizedBox.shrink();
    }
    final VoidCallback? onPressed = _busy
        ? null
        : () {
            if (confirm) {
              unawaited(_confirmAndRun(name, label));
            } else {
              unawaited(_jobAction(name));
            }
          };
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: filled
          ? FilledButton(
              key: ValueKey<String>('detail-action-$name'),
              onPressed: onPressed,
              child: Text(label),
            )
          : OutlinedButton(
              key: ValueKey<String>('detail-action-$name'),
              onPressed: onPressed,
              child: Text(label),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CoverRef? cover = widget.candidate.cover;
    return Scaffold(
      appBar: AppBar(title: Text(widget.candidate.displayTitle)),
      body: AsyncView<WorkDetail>(
        future: _future,
        onRetry: _reload,
        builder: (BuildContext context, WorkDetail detail) => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (cover != null)
                  SizedBox(
                    width: 96,
                    height: 128,
                    child: ThumbnailImage(
                      loader: widget.thumbnails,
                      hash: cover.hash,
                    ),
                  ),
                if (cover != null) const SizedBox(width: 12),
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
                        runSpacing: 8,
                        children: <Widget>[
                          StatusChip(status: detail.status),
                          StatusChip(status: detail.stage),
                          if (detail.artist.isNotEmpty)
                            Chip(label: Text(detail.artist)),
                          if (detail.category.isNotEmpty)
                            Chip(label: Text(detail.category)),
                          if (detail.language.isNotEmpty)
                            Chip(label: Text(detail.language)),
                        ],
                      ),
                      if (detail.tags.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(detail.tags.join(' · ')),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (detail.prevId != null || detail.nextId != null) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  if (detail.prevId != null)
                    TextButton.icon(
                      key: const ValueKey<String>('detail-prev'),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('上一作品'),
                      onPressed: () => _openSibling(detail.prevId),
                    ),
                  const Spacer(),
                  if (detail.nextId != null)
                    TextButton.icon(
                      key: const ValueKey<String>('detail-next'),
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('下一作品'),
                      onPressed: () => _openSibling(detail.nextId),
                    ),
                ],
              ),
            ],
            if (detail.filterReason.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('过滤说明：${detail.filterReason}'),
            ],
            if (detail.cbzPath.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('装成：${detail.cbzPath}'),
            ],
            if (detail.metadata.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              Text('元数据', style: Theme.of(context).textTheme.titleMedium),
              for (final MetadataEntry entry in detail.metadata)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.label),
                  subtitle: Text(entry.value),
                  trailing: entry.isManual || entry.isLocked
                      ? Text(entry.isLocked ? '已锁定' : '手动')
                      : null,
                ),
            ],
            if (detail.timeline.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              Text('时间线', style: Theme.of(context).textTheme.titleMedium),
              for (final TimelineEntry entry in detail.timeline)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.label),
                  subtitle: Text(entry.reason),
                  trailing: Text(
                    _formatTime(entry.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 0,
              runSpacing: 0,
              children: <Widget>[
                if (widget.candidate.canApprove)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: FilledButton(
                      key: const ValueKey<String>('detail-approve'),
                      onPressed: _busy ? null : () => _review('approve'),
                      child: const Text('通过'),
                    ),
                  ),
                if (widget.candidate.canReject)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: OutlinedButton(
                      key: const ValueKey<String>('detail-reject'),
                      onPressed: _busy ? null : () => _review('reject'),
                      child: const Text('驳回'),
                    ),
                  ),
                _actionButton(detail, 'fetch_metadata', label: '重获元数据'),
                _actionButton(detail, 'repack', label: '重新打包'),
                _actionButton(detail, 'reconvert', label: '重新转换'),
                _actionButton(detail, 'switch_source_ehentai', label: '切至 EH'),
                _actionButton(
                  detail,
                  'switch_source_telegram',
                  label: '切至 Telegram',
                ),
                _actionButton(detail, 'requeue', label: '重排队'),
                _actionButton(detail, 'needs_revision', label: '需修订'),
                _actionButton(detail, 'convert', label: '转换'),
                _actionButton(detail, 'delete', label: '轻度删除', confirm: true),
                _actionButton(
                  detail,
                  'delete_files',
                  label: '底度删除',
                  confirm: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime? time) {
  if (time == null) {
    return '';
  }
  final DateTime local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
