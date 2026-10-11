import 'package:flutter/material.dart';

import '../theme.dart';

/// 多选状态下贴在底部的工具条（与 WebUI 的 bulk toolbar 同义）。
///
/// 只负责排布：`已选 N` + 取消 + 调用方给的动作按钮。选中集合本身由页面持有，
/// 因为「点一行是切换选中还是打开详情」是页面自己的事。
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    required this.onClear,
    required this.actions,
    this.clearKey,
    this.busy = false,
  });

  final int count;
  final VoidCallback onClear;
  final List<Widget> actions;

  /// 取消按钮的 key（测试用）。
  final Key? clearKey;
  final bool busy;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 3,
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: EhSpacing.l,
          vertical: EhSpacing.s,
        ),
        child: Row(
          children: <Widget>[
            Text('已选 $count 个'),
            const SizedBox(width: EhSpacing.m),
            TextButton(
              key: clearKey,
              onPressed: busy ? null : onClear,
              child: const Text('取消'),
            ),
            for (final Widget action in actions) ...<Widget>[
              const SizedBox(width: EhSpacing.s),
              action,
            ],
          ],
        ),
      ),
    ),
  );
}
