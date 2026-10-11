import 'package:flutter/material.dart';
import '../theme.dart';

class TagChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  const TagChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color bg = selected ? cs.secondaryContainer : cs.surfaceContainerHigh;
    final Color fg = selected ? cs.onSecondaryContainer : cs.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(EhRadius.chip),
      onTap: onTap,
      child: Semantics(
        label: label,
        button: onTap != null,
        selected: selected,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: EhSpacing.m,
            vertical: EhSpacing.s,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(EhRadius.chip),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.6),
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
          ),
        ),
      ),
    );
  }
}
