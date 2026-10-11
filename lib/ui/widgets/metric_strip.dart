import 'package:flutter/material.dart';
import '../theme.dart';
import 'eh_card.dart';

/// 横向数字卡（下载 / 打包 / 需干预），点击切换 tab。
class MetricStrip extends StatelessWidget {
  final List<MetricStripItem> items;

  const MetricStrip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: EhSpacing.l),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: EhSpacing.m),
        itemBuilder: (BuildContext context, int i) => items[i],
      ),
    );
  }
}

class MetricStripItem extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onTap;
  final IconData? icon;

  const MetricStripItem({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return EhCard(
      tone: EhCardTone.neutral,
      padding: const EdgeInsets.symmetric(
        horizontal: EhSpacing.l,
        vertical: EhSpacing.s,
      ),
      onTap: onTap,
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: EhSpacing.xs),
                ],
                Text(label, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: EhSpacing.xs),
            _AnimatedCount(target: value),
          ],
        ),
      ),
    );
  }
}

/// 350 ms 数字滚动（M7 §6 表里"数字滚动"条目）。
class _AnimatedCount extends StatelessWidget {
  final int target;
  const _AnimatedCount({required this.target});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target.toDouble()),
      duration: EhAnim.slow,
      curve: Curves.easeOut,
      builder: (BuildContext context, double v, Widget? _) => Text(
        v.toInt().toString(),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
