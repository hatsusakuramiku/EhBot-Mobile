import 'package:flutter/material.dart';

import '../../api/models.dart';

/// 状态徽标：配色跟随后端 `tone`，文案用后端 `label`（不在客户端硬编码）。
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final StatusView status;

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) {
      return const SizedBox.shrink();
    }
    final ColorScheme colors = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (status.tone) {
      'success' => (colors.primaryContainer, colors.onPrimaryContainer),
      'danger' => (colors.errorContainer, colors.onErrorContainer),
      'active' => (colors.tertiaryContainer, colors.onTertiaryContainer),
      'waiting' => (colors.secondaryContainer, colors.onSecondaryContainer),
      _ => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground),
      ),
    );
  }
}
