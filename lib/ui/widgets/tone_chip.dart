import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../theme.dart';

/// 状态徽标 / 标签的统一实现。
///
/// 颜色按 tone 走 M3 语义色，**不再硬编码** `Colors.green.shade100` 之类；
/// 文案永远用后端 `StatusView.label`，不在客户端硬编码中文状态名。
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

  /// 直接用后端 `StatusView` 构造；空状态渲染成零尺寸。
  factory ToneChip.status({Key? key, required StatusView status}) =>
      ToneChip(
        key: key,
        label: status.label,
        tone: status.tone,
      );

  bool get _isEmpty => label.isEmpty && tone.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_isEmpty) {
      return const SizedBox.shrink();
    }
    final Color bg = _bg(context);
    final Color fg = _fg(context);
    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: EhSpacing.m,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
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
      'success' => cs.primaryContainer,
      'danger' => cs.errorContainer,
      'warning' => cs.tertiaryContainer,
      'active' => cs.tertiaryContainer,
      'waiting' => cs.secondaryContainer,
      'info' => cs.primaryContainer,
      _ => cs.surfaceContainerHighest,
    };
  }

  Color _fg(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return switch (tone) {
      'success' => cs.onPrimaryContainer,
      'danger' => cs.onErrorContainer,
      'warning' => cs.onTertiaryContainer,
      'active' => cs.onTertiaryContainer,
      'waiting' => cs.onSecondaryContainer,
      'info' => cs.onPrimaryContainer,
      _ => cs.onSurfaceVariant,
    };
  }
}
