import 'dart:async';

import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../media/thumbnail_loader.dart';
import 'error_text.dart';
import 'widgets/async_view.dart';
import 'widgets/cover_thumb.dart';
import 'widgets/eh_card.dart';
import 'widgets/large_title_app_bar.dart';
import 'widgets/section_header.dart';
import 'widgets/tag_chip.dart';
import 'widgets/tone_chip.dart';

/// 作品详情：封面 + 元数据 + 时间线 + 主/次/危险三层操作。
///
/// 后端返回的 `actions` 控制哪些按钮可见；缺字段则不显示（不是禁用）。
/// `prev_id` / `next_id` 存在时才出现前后导航。
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

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AsyncView<WorkDetail>(
      future: _future,
      onRetry: _reload,
      builder: (BuildContext context, WorkDetail detail) => CustomScrollView(
        slivers: <Widget>[
          EhLargeTitleAppBar(
            title: widget.candidate.displayTitle,
            subtitle: detail.stage.label.isEmpty ? null : detail.stage.label,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList.list(
              children: <Widget>[
                _overview(context, detail),
                if (detail.filterReason.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  EhCard(
                    tone: EhCardTone.warning,
                    dense: true,
                    child: Text('过滤说明：${detail.filterReason}'),
                  ),
                ],
                if (detail.cbzPath.isNotEmpty)
                  _kv(context, '归档路径', detail.cbzPath),
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
                    ),
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
                const SizedBox(height: 20),
                _actions(context, detail),
              ],
            ),
          ),
        ],
      ),
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
          if (detail.prevId != null || detail.nextId != null) ...<Widget>[
            const SizedBox(height: 12),
            const Divider(),
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
        ],
      ),
    );
  }

  Widget _kv(
    BuildContext context,
    String label,
    String value, {
    String? trailing,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 96,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
        if (trailing != null)
          Text(trailing, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );

  Widget _actions(BuildContext context, WorkDetail detail) {
    final List<Widget> primary = <Widget>[
      if (widget.candidate.canApprove)
        FilledButton(
          key: const ValueKey<String>('detail-approve'),
          onPressed: _busy ? null : () => _review('approve'),
          child: const Text('通过'),
        ),
      if (widget.candidate.canReject)
        OutlinedButton(
          key: const ValueKey<String>('detail-reject'),
          onPressed: _busy ? null : () => _review('reject'),
          child: const Text('驳回'),
        ),
    ];
    final List<Widget> secondary = <Widget>[
      _actionButton(detail, 'fetch_metadata', label: '重获元数据'),
      _actionButton(detail, 'repack', label: '重新打包'),
      _actionButton(detail, 'reconvert', label: '重新转换'),
      _actionButton(detail, 'switch_source_ehentai', label: '切至 EH'),
      _actionButton(detail, 'switch_source_telegram', label: '切至 Telegram'),
      _actionButton(detail, 'requeue', label: '重排队'),
      _actionButton(detail, 'needs_revision', label: '需修订'),
      _actionButton(detail, 'convert', label: '转换'),
    ];
    final List<Widget> danger = <Widget>[
      _actionButton(detail, 'delete', label: '彻底删除', confirm: true),
      _actionButton(detail, 'delete_files', label: '彻底删除并删文件', confirm: true),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (primary.isNotEmpty)
          Wrap(spacing: 12, runSpacing: 8, children: primary),
        if (secondary.any((Widget w) => w is! SizedBox))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(spacing: 8, runSpacing: 8, children: secondary),
          ),
        if (danger.any((Widget w) => w is! SizedBox))
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: EhCard(
              tone: EhCardTone.warning,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.warning_amber_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '危险操作',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: danger),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _actionButton(
    WorkDetail detail,
    String name, {
    required String label,
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
    return OutlinedButton(
      key: ValueKey<String>('detail-action-$name'),
      onPressed: onPressed,
      child: Text(label),
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
