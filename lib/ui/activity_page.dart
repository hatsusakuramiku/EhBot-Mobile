import 'dart:async';

import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../media/thumbnail_loader.dart';
import '../state/live_monitor.dart';
import 'candidate_detail_page.dart';
import 'widgets/async_view.dart';
import 'widgets/eh_card.dart';
import 'widgets/large_title_app_bar.dart';
import 'widgets/section_header.dart';
import 'widgets/tone_chip.dart';

/// 活动：下载 / 打包队列快照 + 已完成历史（MVP 只读）。
class ActivityPage extends StatefulWidget {
  const ActivityPage({
    super.key,
    required this.api,
    required this.thumbnails,
    this.monitor,
    this.appBarActions = const <Widget>[],
  });

  final EhBotApi api;
  final ThumbnailLoader thumbnails;
  final LiveMonitor? monitor;

  /// 顶栏动作（由 [HomeShell] 注入设置入口等）。
  final List<Widget> appBarActions;

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  late Future<(QueueSnapshot, List<JobSummary>)> _future = _load();
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

  Future<(QueueSnapshot, List<JobSummary>)> _load() async {
    final QueueSnapshot queue = await widget.api.queue();
    final List<JobSummary> history = await widget.api.history();
    return (queue, history);
  }

  void _reload() {
    if (!mounted) {
      return;
    }
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      _reload();
      await _future;
    },
    child: AsyncView<(QueueSnapshot, List<JobSummary>)>(
      future: _future,
      onRetry: _reload,
      builder: (BuildContext context, (QueueSnapshot, List<JobSummary>) data) {
        final (QueueSnapshot queue, List<JobSummary> history) = data;
        return CustomScrollView(
          slivers: <Widget>[
            EhLargeTitleAppBar(
              title: '活动',
              subtitle: queue.live ? '有任务在推进中' : '队列空闲',
              actions: widget.appBarActions,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: EhCard(
                        dense: true,
                        child: Text(
                          '下载中 ${queue.downloadCount}',
                          key: const ValueKey<String>('activity-downloads'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EhCard(
                        dense: true,
                        child: Text(
                          '打包中 ${queue.packingCount}',
                          key: const ValueKey<String>('activity-packing'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ..._sectionSlivers(context, queue, history),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    ),
  );

  List<Widget> _sectionSlivers(
    BuildContext context,
    QueueSnapshot queue,
    List<JobSummary> history,
  ) {
    final List<JobGroup> groups = <JobGroup>[
      ...queue.downloads,
      ...queue.packing,
    ];
    return <Widget>[
      if (groups.isEmpty && history.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('队列为空。')),
          ),
        ),
      for (final JobGroup group in groups) ...<Widget>[
        SliverToBoxAdapter(
          child: SectionHeader(title: '${group.label}（${group.count}）'),
        ),
        SliverList.builder(
          itemCount: group.jobs.length,
          itemBuilder: (BuildContext context, int index) =>
              _jobTile(context, group.jobs[index]),
        ),
      ],
      SliverToBoxAdapter(child: SectionHeader(title: '历史（${history.length}）')),
      if (history.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('暂无历史任务。'),
          ),
        )
      else
        SliverList.builder(
          itemCount: history.length,
          itemBuilder: (BuildContext context, int index) =>
              _jobTile(context, history[index]),
        ),
    ];
  }

  Widget _jobTile(BuildContext context, JobSummary job) {
    final bool hasCandidateId = job.candidateId.isNotEmpty;
    return ListTile(
      key: ValueKey<String>('activity-job-${job.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(job.displayTitle),
      subtitle: Text(
        job.errorMessage.isEmpty
            ? job.state.label
            : '${job.state.label} · ${job.errorMessage}',
      ),
      trailing: ToneChip.status(status: job.state),
      onTap: hasCandidateId ? () => unawaited(_openDetail(job)) : null,
    );
  }

  Future<void> _openDetail(JobSummary job) async {
    final Candidate stub = Candidate(
      id: job.candidateId,
      title: job.title,
      status: job.state,
    );
    final bool changed =
        await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (BuildContext _) => CandidateDetailPage(
              api: widget.api,
              thumbnails: widget.thumbnails,
              candidate: stub,
            ),
          ),
        ) ??
        false;
    if (changed) {
      _reload();
    }
  }
}
