import 'package:flutter/material.dart';

/// M3 大标题 AppBar：`SliverAppBar.large` 形态。pin / 浮动由父 `CustomScrollView`
/// 控制。中间内部 padding 留给 operator 用副标。
class EhLargeTitleAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  const EhLargeTitleAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.leading,
  });

  @override
  Widget build(BuildContext context) => SliverAppBar.large(
        leading: leading,
        title: Text(title),
        pinned: true,
        actions: actions,
        flexibleSpace: subtitle == null
            ? null
            : FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(
                  start: 56,
                  bottom: 16,
                ),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
      );
}
