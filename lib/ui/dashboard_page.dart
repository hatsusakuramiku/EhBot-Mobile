import 'dart:async';

import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../media/thumbnail_loader.dart';
import '../state/live_monitor.dart';
import 'candidate_detail_page.dart';
import 'dedup_page.dart';
import 'manual_add_page.dart';
import 'widgets/async_view.dart';
import 'widgets/eh_card.dart';
import 'widgets/large_title_app_bar.dart';
import 'widgets/metric_strip.dart';
import 'widgets/section_header.dart';
import 'widgets/tone_chip.dart';

/// 候选计数键（`CANDIDATE_COUNT_KEYS`）→ 中文标签。
const Map<String, String> kCandidateCountLabels = <String, String>{
  'discovered': '已发现',
  'pending_review': '待审核',
  'needs_info': '待补充',
  'needs_revision': '需要修订',
  'approved': '已通过',
  'processing': '处理中',
  'downloaded': '已下载',
  'rejected': '已驳回',
  'failed': '失败',
};

/// 工作台：候选计数、活动概况、需干预清单。
class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.api,
    required this.thumbnails,
    this.monitor,
    this.candidatesTab,
    this.onOpenCandidates,
    this.appBarActions = const <Widget>[],
  });

  final EhBotApi api;
  final ThumbnailLoader thumbnails;

  /// 实时监视器；tick 到来时自动刷新。
  final LiveMonitor? monitor;

  /// Shared with [CandidatesPage]. Dashboard chips update it; the candidates
  /// tab strip listens so the two views agree on the active filter (M6).
  final ValueNotifier<String>? candidatesTab;

  /// Jump straight to the candidates list with the given sub-tab. Wired by
  /// [HomeShell] so the bottom-nav destination changes at the same time.
  final ValueChanged<String>? onOpenCandidates;

  /// 顶栏动作（由 [HomeShell] 注入设置入口等）。
  final List<Widget> appBarActions;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Summary> _future = widget.api.summary();
  StreamSubscription<int>? _ticks;

  @override
  void initState() {
    super.initState();
    _ticks = widget.monitor?.ticks.listen((int _) => _reload());
  }

  @override
  void dispose() {
    _ticks?.cancel();
    super.dispose();
  }

  void _reload() {
    if (!mounted) {
      return;
    }
    setState(() => _future = widget.api.summary());
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      _reload();
      await _future;
    },
    child: AsyncView<Summary>(
      future: _future,
      onRetry: _reload,
      builder: (BuildContext context, Summary summary) {
        final List<MapEntry<String, int>> counts = summary
            .candidateCounts
            .entries
            .where(
              (MapEntry<String, int> entry) =>
                  entry.key != 'total' && entry.value > 0,
            )
            .toList();
        return CustomScrollView(
          slivers: <Widget>[
            EhLargeTitleAppBar(
              title: '工作台',
              subtitle: '总览 · 需处理 ${summary.attentionTotal}',
              actions: widget.appBarActions,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (summary.startupErrors.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: EhCard(
                          tone: EhCardTone.warning,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Icon(Icons.warning_amber_rounded),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '服务端启动有告警：'
                                  '${summary.startupErrors.join('；')}',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SectionHeader(title: '候选'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '共 ${summary.candidateCounts['total'] ?? 0} 个',
                        key: const ValueKey<String>('summary-total'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    _countGrid(context, counts),
                    const SectionHeader(title: '活动'),
                    MetricStrip(
                      items: <MetricStripItem>[
                        MetricStripItem(
                          key: const ValueKey<String>('summary-downloads'),
                          label: '下载中',
                          value: summary.downloads,
                          icon: Icons.downloading_outlined,
                        ),
                        MetricStripItem(
                          key: const ValueKey<String>('summary-packing'),
                          label: '打包中',
                          value: summary.packing,
                          icon: Icons.inventory_2_outlined,
                        ),
                        MetricStripItem(
                          label: '需干预',
                          value: summary.attentionTotal,
                          icon: Icons.priority_high_outlined,
                        ),
                      ],
                    ),
                    SectionHeader(title: '需干预（${summary.attentionTotal}）'),
                    if (summary.attentionItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('暂无需要注意的任务。'),
                      )
                    else
                      for (final JobSummary job in summary.attentionItems)
                        _attentionTile(context, job),
                    const SectionHeader(title: '快捷操作'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: EhCard(
                              key: const ValueKey<String>(
                                'dashboard-manual-add',
                              ),
                              dense: true,
                              onTap: () => _open(
                                ManualAddPage(
                                  api: widget.api,
                                  thumbnails: widget.thumbnails,
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  const Icon(Icons.add_link_outlined, size: 18),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '手动添加',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: EhCard(
                              key: const ValueKey<String>('dashboard-dedup'),
                              dense: true,
                              onTap: () => _open(DedupPage(api: widget.api)),
                              child: Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.cleaning_services_outlined,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '一键去重',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _countGrid(BuildContext context, List<MapEntry<String, int>> counts) =>
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int columns = constraints.maxWidth >= 600 ? 4 : 2;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: <Widget>[
                for (final MapEntry<String, int> entry in counts)
                  EhCard(
                    key: ValueKey<String>('dashboard-chip-${entry.key}'),
                    onTap: widget.onOpenCandidates == null
                        ? null
                        : () => widget.onOpenCandidates!(entry.key),
                    semanticsLabel:
                        '${kCandidateCountLabels[entry.key] ?? entry.key} '
                        '${entry.value}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          '${entry.value}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${kCandidateCountLabels[entry.key] ?? entry.key} '
                          '${entry.value}',
                          style: Theme.of(context).textTheme.labelMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      );

  Widget _attentionTile(BuildContext context, JobSummary job) => ListTile(
    key: ValueKey<String>('dashboard-attn-${job.id}'),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    leading: const SizedBox(
      width: 40,
      height: 56,
      child: Icon(Icons.report_gmailerrorred_outlined),
    ),
    title: Text(job.displayTitle),
    subtitle: Text(
      job.errorMessage.isEmpty
          ? job.state.label
          : '${job.state.label} · ${job.errorMessage}',
    ),
    trailing: ToneChip.status(status: job.state),
    onTap: job.candidateId.isEmpty
        ? null
        : () => _openAttention(context, job.candidateId),
  );

  Future<void> _openAttention(BuildContext context, String candidateId) async {
    final bool changed =
        await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (BuildContext _) => CandidateDetailPage(
              api: widget.api,
              thumbnails: widget.thumbnails,
              candidate: Candidate(id: candidateId, title: ''),
            ),
          ),
        ) ??
        false;
    if (changed) {
      _reload();
    }
  }

  void _open(Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (BuildContext _) => page));
  }
}
