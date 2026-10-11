import 'package:flutter/material.dart';

import '../../api/ehbot_api.dart';
import '../../api/models.dart';

/// 任务生命周期里的一个动作（WebUI 活动页那一套）。
///
/// `action` 是 URL 里的拼法（`POST /api/v1/jobs/{job_id}/{action}`），
/// 可见性一律来自 `job_summary.actions`——客户端不自己推导状态机，
/// 那是后端算好的策略（「停滞的种子不是失败」）。
class JobActionSpec {
  const JobActionSpec({required this.action, required this.label, this.confirm});

  final String action;
  final String label;

  /// 需要二次确认时的正文；null 表示直接执行。
  final String? confirm;
}

/// 这个任务自己能做的事，按 WebUI 的顺序。
List<JobActionSpec> jobActionSpecs(JobSummary job) => <JobActionSpec>[
  if (job.canRetry) const JobActionSpec(action: kJobRetry, label: '重试'),
  if (job.canResume) const JobActionSpec(action: kJobResume, label: '继续'),
  if (job.canPause) const JobActionSpec(action: kJobPause, label: '暂停'),
  if (job.canCancel)
    const JobActionSpec(
      action: kJobCancel,
      label: '取消',
      confirm: '取消这个任务？已经下载 / 打包出来的文件会保留。',
    ),
  if (job.canStopSeeding)
    const JobActionSpec(
      action: kJobStopSeeding,
      label: '停止做种',
      confirm: '从 qBittorrent 移除这个条目？已归档的文件保留在原处。',
    ),
];

/// 一个切源目标。
class SwitchSourceTarget {
  const SwitchSourceTarget({
    required this.provider,
    required this.label,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.confirmLabel,
  });

  final String provider;
  final String label;
  final String confirmTitle;
  final String confirmMessage;
  final String confirmLabel;
}

/// 切源的两个目标，与 WebUI 活动页的字面一致。
///
/// 只有这两个：后端 `DownloadService.switch_source` 对其它 provider 直接
/// `PROVIDER_UNSUPPORTED`，所以给别的按钮就是给一个必然失败的按钮。
/// 两条都会结束当前那条 torrent，所以都要先确认——一条掉到阅读级、一条花 GP，
/// 都不是误触该承担的决定。
const List<SwitchSourceTarget> kSwitchSourceTargets = <SwitchSourceTarget>[
  SwitchSourceTarget(
    provider: 'TELEGRAPH',
    label: '改用预览图源',
    confirmTitle: '改用预览图源',
    confirmMessage:
        '当前种子会从 qBittorrent 移除，改从预览页抓取：'
        '成品是统一缩到宽 1280 的重编码版本，约为原档 5%–10%。',
    confirmLabel: '确认改用预览图源',
  ),
  SwitchSourceTarget(
    provider: 'EXHENTAI',
    label: '用 Archive Download',
    confirmTitle: '用 Archive Download 取原档',
    confirmMessage:
        '当前种子会从 qBittorrent 移除，改用 ExHentai 的 Archive Download 取原档，'
        '这会消耗 GP。',
    confirmLabel: '确认消耗 GP',
  ),
];

/// 一个任务的操作按钮排。可见性全由 [job] 决定；点击只回调，不做网络。
class JobActionsBar extends StatelessWidget {
  const JobActionsBar({
    super.key,
    required this.job,
    required this.onRun,
    required this.onSwitchSource,
    this.busy = false,
  });

  final JobSummary job;

  /// 执行一个生命周期动作（`retry` / `pause` / …），确认文案由调用方按
  /// [JobActionSpec.confirm] 弹。
  final void Function(JobActionSpec spec) onRun;

  /// 切换到另一个来源。
  final void Function(SwitchSourceTarget target) onSwitchSource;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final List<JobActionSpec> specs = jobActionSpecs(job);
    final bool canSwitch = job.canSwitchSource;
    if (specs.isEmpty && !canSwitch) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        for (final JobActionSpec spec in specs)
          OutlinedButton(
            key: ValueKey<String>('job-${job.id}-${spec.action}'),
            onPressed: busy ? null : () => onRun(spec),
            child: Text(spec.label),
          ),
        if (canSwitch)
          for (final SwitchSourceTarget target in kSwitchSourceTargets)
            TextButton(
              key: ValueKey<String>('job-${job.id}-switch-${target.provider}'),
              onPressed: busy ? null : () => onSwitchSource(target),
              child: Text(target.label),
            ),
      ],
    );
  }
}

/// 弹一次「确认 / 取消」；确认返回 true。
///
/// 切源与删除这类动作都结束某样东西（一条 torrent、一份文件），
/// 文案要说清结束的是什么，而不是一律「不可撤销」。
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(c).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}
