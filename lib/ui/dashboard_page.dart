import 'dart:async';

import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../state/live_monitor.dart';
import 'widgets/async_view.dart';
import 'widgets/status_chip.dart';

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
  const DashboardPage({super.key, required this.api, this.monitor});

  final EhBotApi api;

  /// 实时监视器；tick 到来时自动刷新。
  final LiveMonitor? monitor;

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
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (summary.startupErrors.isNotEmpty)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '服务端启动有告警：${summary.startupErrors.join('；')}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            _sectionTitle(context, '候选'),
            Text(
              '共 ${summary.candidateCounts['total'] ?? 0} 个',
              key: const ValueKey<String>('summary-total'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final MapEntry<String, int> entry in counts)
                  Chip(
                    label: Text(
                      '${kCandidateCountLabels[entry.key] ?? entry.key} ${entry.value}',
                    ),
                  ),
              ],
            ),
            _sectionTitle(context, '活动'),
            Row(
              children: <Widget>[
                Expanded(
                  child: _metric(
                    context,
                    value: '${summary.downloads}',
                    label: '下载中',
                    keyName: 'summary-downloads',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metric(
                    context,
                    value: '${summary.packing}',
                    label: '打包中',
                    keyName: 'summary-packing',
                  ),
                ),
              ],
            ),
            if (summary.activityLive)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('有任务在推进中。'),
              ),
            _sectionTitle(context, '需干预（${summary.attentionTotal}）'),
            if (summary.attentionItems.isEmpty)
              const Text('暂无需要注意的任务。')
            else
              for (final JobSummary job in summary.attentionItems)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(job.displayTitle),
                  subtitle: Text(
                    job.errorMessage.isEmpty
                        ? job.state.label
                        : '${job.state.label} · ${job.errorMessage}',
                  ),
                  trailing: StatusChip(status: job.state),
                ),
          ],
        );
      },
    ),
  );

  Widget _sectionTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _metric(
    BuildContext context, {
    required String value,
    required String label,
    required String keyName,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            key: ValueKey<String>(keyName),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}
