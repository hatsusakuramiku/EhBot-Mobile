import 'package:flutter/material.dart';

/// M3 大标题 AppBar（`SliverAppBar.large` 形态）。放在页面自己的
/// `CustomScrollView` 里，滚动时折叠成普通 AppBar。
///
/// 页面不再各写一个 `SliverAppBar`，标题 / 副标 / 动作都从这里进。
class EhLargeTitleAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final bool pinned;
  final PreferredSizeWidget? bottom;

  const EhLargeTitleAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.leading,
    this.pinned = true,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) => SliverAppBar.large(
    leading: leading,
    title: subtitle == null
        ? Text(title)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
    pinned: pinned,
    actions: actions,
    bottom: bottom,
    scrolledUnderElevation: 0,
    backgroundColor: Theme.of(context).colorScheme.surface,
  );
}
