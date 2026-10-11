import 'package:flutter/material.dart';
import '../theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String primary;
  final String? secondary;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.primary,
    this.secondary,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(EhSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 56, color: cs.onSurfaceVariant),
              const SizedBox(height: EhSpacing.l),
              Text(primary, style: tt.titleMedium, textAlign: TextAlign.center),
              if (secondary != null) ...<Widget>[
                const SizedBox(height: EhSpacing.s),
                Text(
                  secondary!,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              if (onAction != null && actionLabel != null) ...<Widget>[
                const SizedBox(height: EhSpacing.xl),
                FilledButton.tonal(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
