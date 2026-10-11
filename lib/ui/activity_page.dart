import 'dart:async';

import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import '../media/thumbnail_loader.dart';
import '../state/live_monitor.dart';
import 'candidate_detail_page.dart';
import 'error_text.dart';
import 'theme.dart';
import 'widgets/async_view.dart';
import 'widgets/eh_card.dart';
import 'widgets/job_actions.dart';
import 'widgets/large_title_app_bar.dart';
import 'widgets/section_header.dart';
import 'widgets/selection_bar.dart';
import 'widgets/tone_chip.dart';

/// 活动：下载 / 打包队列快照 + 已完成历史，带任务操作与批量条。
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

  /// 多选（只对队列里的任务；历史是过去，没有可执行的动作）。
  final Set<String> _selected = <String>{};
  bool _busy = false;

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

  void _toggleSelection(String jobId) {
    setState(() {
      if (!_selected.remove(jobId)) {
        _selected.add(jobId);
      }
    });
  }

  void _clearSelection() => setState(_selected.clear);

  /// 行内任务动作：单个也是批量端点之外的单任务端点。
  Future<void> _runJobAction(JobSummary job, JobActionSpec spec) async {
    if (spec.confirm != null) {
      final bool ok = await confirmDialog(
        context,
        title: spec.label,
        message: spec.confirm!,
        confirmLabel: spec.confirmLabel ?? spec.label,
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

  Future<void> _guard(Future<void> Function() action, {String done = ''}) async {
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

  /// 批量动作（WebUI 活动页批量条的同义词）：恢复 / 暂停 / 重试 / 取消 / 优先级。
  Future<void> _runBatch(String action, {String done = '', int? priority}) async {
    if (_selected.isEmpty || _busy) {
      return;
    }
    final List<String> ids = _selected.toList();
    setState(() => _busy = true);
    try {
      final ReviewBatchResult result = await widget.api.jobBatch(
        action: action,
        jobIds: ids,
        priority: priority,
      );
      if (!mounted) {
        return;
      }
      final String message = result.skipped.isEmpty
          ? '$done ${result.applied} 个任务'
          : '$done ${result.applied} 个；${result.skipped.length} 个被跳过：'
                '${result.skipped.first}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      _clearSelection();
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

  Future<void> _askPriority() async {
    final int? value = await showDialog<int>(
      context: context,
      builder: (BuildContext c) => const PriorityDialog(),
    );
    if (value == null || !mounted) {
      return;
    }
    if (value < kMinJobPriority || value > kMaxJobPriority) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('优先级需在 $kMinJobPriority 到 $kMaxJobPriority 之间。'),
        ),
      );
      return;
    }
    await _runBatch('priority', done: '已调整优先级', priority: value);
  }

  /// 取消是不可逆的（任务终止、候选回「已通过」、停放中的种子会从 qBittorrent 移走），
  /// 所以先确认——文案与 WebUI 批量条的确认一致。
  Future<void> _confirmCancelJobs() async {
    final bool ok = await confirmDialog(
      context,
      title: '取消选中的任务',
      message:
          '任务会终止，候选保持「已通过」，可立即切换来源或重新入队；'
          '停放中的种子会同时从 qBittorrent 移除（不删除已下载的文件）。',
      confirmLabel: '确认取消',
    );
    if (!ok || !mounted) {
      return;
    }
    await _runBatch(kJobCancel, done: '已取消');
  }

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _future;
          },
          child: AsyncView<(QueueSnapshot, List<JobSummary>)>(
            future: _future,
            onRetry: _reload,
            builder:
                (BuildContext context, (QueueSnapshot, List<JobSummary>) data) {
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
                                key: const ValueKey<String>(
                                  'activity-downloads',
                                ),
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
        ),
      ),
      if (_selected.isNotEmpty) _bulkBar(context),
    ],
  );

  /// 批量条：与 WebUI 活动页同义的五个动作。
  Widget _bulkBar(BuildContext context) => SelectionBar(
    count: _selected.length,
    busy: _busy,
    clearKey: const ValueKey<String>('activity-batch-cancel'),
    onClear: _clearSelection,
    actions: <Widget>[
      OutlinedButton(
        key: const ValueKey<String>('activity-batch-resume'),
        onPressed: _busy
            ? null
            : () => unawaited(_runBatch('resume', done: '已恢复')),
        child: const Text('批量恢复'),
      ),
      OutlinedButton(
        key: const ValueKey<String>('activity-batch-pause'),
        onPressed: _busy
            ? null
            : () => unawaited(_runBatch('pause', done: '已暂停')),
        child: const Text('批量暂停'),
      ),
      OutlinedButton(
        key: const ValueKey<String>('activity-batch-retry'),
        onPressed: _busy
            ? null
            : () => unawaited(_runBatch(kJobRetry, done: '已重试')),
        child: const Text('批量重试'),
      ),
      OutlinedButton(
        key: const ValueKey<String>('activity-batch-priority'),
        onPressed: _busy ? null : () => unawaited(_askPriority()),
        child: const Text('调整优先级'),
      ),
      OutlinedButton(
        key: const ValueKey<String>('activity-batch-cancel-jobs'),
        onPressed: _busy
            ? null
            : () => unawaited(_confirmCancelJobs()),
        child: const Text('批量取消'),
      ),
    ],
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
    final bool selected = _selected.contains(job.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          key: ValueKey<String>('activity-job-${job.id}'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: _selected.isEmpty
              ? null
              : Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? Theme.of(context).colorScheme.primary : null,
                ),
          title: Text(job.displayTitle),
          subtitle: Text(
            job.errorMessage.isEmpty
                ? job.state.label
                : '${job.state.label} · ${job.errorMessage}',
          ),
          trailing: ToneChip.status(status: job.state),
          onTap: _selected.isNotEmpty
              ? () => _toggleSelection(job.id)
              : (hasCandidateId ? () => unawaited(_openDetail(job)) : null),
          onLongPress: () => _toggleSelection(job.id),
        ),
        if (_selected.isEmpty && job.hasAnyAction)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, EhSpacing.s),
            child: JobActionsBar(
              job: job,
              busy: _busy,
              onRun: (JobActionSpec spec) =>
                  unawaited(_runJobAction(job, spec)),
              onSwitchSource: (SwitchSourceTarget target) =>
                  unawaited(_switchSource(job, target)),
            ),
          ),
      ],
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

/// 批量优先级输入。
///
/// 独立成 StatefulWidget 的原因同 `MetadataEditor`：它自己持有
/// `TextEditingController`，由调用方在弹窗退场动画期间 dispose 会让 TextField
/// 拿到已释放的 controller。
class PriorityDialog extends StatefulWidget {
  const PriorityDialog({super.key});

  @override
  State<PriorityDialog> createState() => _PriorityDialogState();
}

class _PriorityDialogState extends State<PriorityDialog> {
  final TextEditingController _input = TextEditingController(text: '100');

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('调整优先级'),
    content: TextField(
      key: const ValueKey<String>('activity-priority-input'),
      controller: _input,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: '优先级',
        helperText: '数值越小越靠前（$kMinJobPriority–$kMaxJobPriority）',
        border: const OutlineInputBorder(),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const ValueKey<String>('activity-priority-apply'),
        onPressed: () =>
            Navigator.of(context).pop(int.tryParse(_input.text.trim())),
        child: const Text('应用'),
      ),
    ],
  );
}
