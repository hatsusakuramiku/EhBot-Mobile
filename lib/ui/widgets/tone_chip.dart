import 'package:flutter/material.dart';
import '../theme.dart';

/// 渲染 `StatusView` 的统一 chip。颜色按 `StatusView.tone`（后端解析），
/// 不再硬编码 `Colors.green.shade100` 等。文字大小自动按密度走。
class ToneChip extends StatelessWidget {
  final String label;
  final String tone;
  final VoidCallback? onTap;

  const ToneChip({
    super.key,
    required this.label,
    required this.tone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = _bg(context);
    final Color fg = _fg(context);
    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: EhSpacing.m,
        vertical: EhSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(EhRadius.chip),
        border: Border.all(color: fg.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
    return Semantics(
      label: label,
      button: onTap != null,
      child: onTap == null ? chip : InkWell(onTap: onTap, child: chip),
    );
  }

  Color _bg(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return switch (tone) {
      'success' => cs.tertiaryContainer,
      'danger' => cs.errorContainer,
      'warning' => Colors.amber.shade100,
      'info' => cs.primaryContainer,
      _ => cs.surfaceContainerHighest,
    };
  }

  Color _fg(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return switch (tone) {
      'success' => cs.onTertiaryContainer,
      'danger' => cs.onErrorContainer,
      'warning' => Colors.amber.shade900,
      'info' => cs.onPrimaryContainer,
      _ => cs.onSurfaceVariant,
    };
  }
}
