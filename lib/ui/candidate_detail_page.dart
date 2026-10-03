import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../media/thumbnail_loader.dart';
import 'error_text.dart';
import 'widgets/async_view.dart';
import 'widgets/status_chip.dart';
import 'widgets/thumbnail_image.dart';

/// 候选详情：元数据 + 时间线 + 通过 / 驳回。
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
          : '已$verb ${result.applied} 个；${result.skipped.length} 个被跳过：'
                '${result.skipped.first}';
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
            if (cover != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ThumbnailImage(
                  loader: widget.thumbnails,
                  hash: cover.hash,
                ),
              ),
            const SizedBox(height: 16),
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
                if (widget.candidate.artist.isNotEmpty)
                  Chip(label: Text(widget.candidate.artist)),
                if (widget.candidate.category.isNotEmpty)
                  Chip(label: Text(widget.candidate.category)),
                if (widget.candidate.language.isNotEmpty)
                  Chip(label: Text(widget.candidate.language)),
              ],
            ),
            if (widget.candidate.tags.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(widget.candidate.tags.join(' · ')),
            ],
            if (detail.filterReason.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text('过滤说明：${detail.filterReason}'),
            ],
            if (detail.cbzPath.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text('归档：${detail.cbzPath}'),
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
            Row(
              children: <Widget>[
                if (widget.candidate.canApprove)
                  FilledButton(
                    key: const ValueKey<String>('detail-approve'),
                    onPressed: _busy ? null : () => _review('approve'),
                    child: const Text('通过'),
                  ),
                if (widget.candidate.canApprove && widget.candidate.canReject)
                  const SizedBox(width: 12),
                if (widget.candidate.canReject)
                  OutlinedButton(
                    key: const ValueKey<String>('detail-reject'),
                    onPressed: _busy ? null : () => _review('reject'),
                    child: const Text('驳回'),
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
