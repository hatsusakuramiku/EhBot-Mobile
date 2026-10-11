import 'package:flutter/material.dart';
import '../theme.dart';

enum EhCardTone {
  /// 默认卡：surface + outline（不需色块）。
  neutral,
  /// 强调卡（启动告警）：errorContainer 背景。
  warning,
  /// 主操作：primaryContainer 背景。
  primary,
}

class EhCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EhCardTone tone;
  final VoidCallback? onTap;
  final String? semanticsLabel;
  final bool dense;

  const EhCard({
    super.key,
    required this.child,
    this.padding,
    this.tone = EhCardTone.neutral,
    this.onTap,
    this.semanticsLabel,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color bg = switch (tone) {
      EhCardTone.neutral => cs.surface,
      EhCardTone.warning => cs.errorContainer,
      EhCardTone.primary => cs.primaryContainer,
    };
    final Color border = switch (tone) {
      EhCardTone.neutral => cs.outlineVariant,
      EhCardTone.warning => cs.error,
      EhCardTone.primary => cs.primary,
    };
    final Widget card = Card(
      color: bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EhRadius.card),
        side: BorderSide(color: border.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Padding(
        padding: padding ??
            EdgeInsets.all(dense ? EhSpacing.m : EhSpacing.l),
        child: child,
      ),
    );
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      child: onTap == null
          ? card
          : InkWell(
              borderRadius: BorderRadius.circular(EhRadius.card),
              onTap: onTap,
              child: card,
            ),
    );
  }
}
