import 'dart:async';

import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../state/live_monitor.dart';
import 'widgets/async_view.dart';
import 'widgets/status_chip.dart';

/// 活动：下载 / 打包队列快照 + 已完成历史（MVP 只读）。
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key, required this.api, this.monitor});

  final EhBotApi api;
  final LiveMonitor? monitor;

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
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '下载中 ${queue.downloadCount}',
                    key: const ValueKey<String>('activity-downloads'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: Text(
                    '打包中 ${queue.packingCount}',
                    key: const ValueKey<String>('activity-packing'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (queue.live)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('有任务在推进中。'),
              ),
            if (queue.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('队列为空。'),
              ),
            for (final JobGroup group in <JobGroup>[
              ...queue.downloads,
              ...queue.packing,
            ]) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 4),
                child: Text(
                  '${group.label}（${group.count}）',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final JobSummary job in group.jobs) _jobTile(job),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 4),
              child: Text(
                '历史（${history.length}）',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (history.isEmpty)
              const Text('暂无历史任务。')
            else
              for (final JobSummary job in history) _jobTile(job),
          ],
        );
      },
    ),
  );

  Widget _jobTile(JobSummary job) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(job.displayTitle),
    subtitle: Text(
      job.errorMessage.isEmpty
          ? job.state.label
          : '${job.state.label} · ${job.errorMessage}',
    ),
    trailing: StatusChip(status: job.state),
  );
}
