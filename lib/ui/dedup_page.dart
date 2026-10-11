import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import 'error_text.dart';
import 'theme.dart';
import 'widgets/async_view.dart';
import 'widgets/eh_card.dart';
import 'widgets/empty_state.dart';
import 'widgets/section_header.dart';
import 'widgets/tone_chip.dart';

/// 一键去重：先看计划，再确认执行。
class DedupPage extends StatefulWidget {
  const DedupPage({super.key, required this.api});

  final EhBotApi api;

  @override
  State<DedupPage> createState() => _DedupPageState();
}

class _DedupPageState extends State<DedupPage> {
  late Future<DedupPlan> _future = widget.api.dedupPlan();
  bool _busy = false;

  void _reload() {
    setState(() => _future = widget.api.dedupPlan());
  }

  Future<void> _apply() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('确认去重'),
        content: const Text('每组只保留列表中标记「保留」的那一件，其余记录与文件会被移除，且不可恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('确认去重'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      final DedupResult result = await widget.api.dedupApply();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isEmpty
                ? '已移除 ${result.removed} 件重复作品。'
                : result.message,
          ),
        ),
      );
      setState(() => _busy = false);
      _reload();
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('一键去重')),
    body: AsyncView<DedupPlan>(
      future: _future,
      onRetry: _reload,
      builder: (BuildContext context, DedupPlan plan) {
        if (plan.isEmpty) {
          return const EmptyState(
            icon: Icons.check_circle_outline,
            primary: '没有发现重复作品',
            secondary: '每个画廊 ID 只对应一条候选，无需处理',
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: <Widget>[
            EhCard(
              tone: EhCardTone.warning,
              dense: true,
              child: Text(
                '将移除 ${plan.removable} 件重复作品，涉及 ${plan.groups.length} 个画廊；'
                '确认前请逐组核对。',
              ),
            ),
            for (final DedupGroup group in plan.groups) ...<Widget>[
              SectionHeader(title: '画廊 #${group.exGid}'),
              EhCard(
                dense: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _entryRow(context, group.keep, keep: true),
                    if (group.remove.isNotEmpty) const Divider(),
                    for (final DedupEntry entry in group.remove)
                      _entryRow(context, entry, keep: false),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(EhSpacing.l),
              child: FilledButton(
                key: const ValueKey<String>('dedup-apply'),
                onPressed: _busy ? null : _apply,
                child: const Text('立即去重'),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _entryRow(
    BuildContext context,
    DedupEntry entry, {
    required bool keep,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: <Widget>[
        ToneChip(label: keep ? '保留' : '移除', tone: keep ? 'success' : 'danger'),
        const SizedBox(width: EhSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (keep && entry.reason.isNotEmpty)
                Text(entry.reason, style: Theme.of(context).textTheme.bodySmall)
              else if (!keep && entry.reason.isNotEmpty)
                Text(
                  entry.reason,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
