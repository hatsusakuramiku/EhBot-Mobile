import 'package:flutter/material.dart';
import '../theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        EhSpacing.l,
        EhSpacing.xl,
        EhSpacing.l,
        EhSpacing.s,
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(title, style: tt.titleMedium)),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: EhSpacing.m,
                vertical: EhSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(EhRadius.chip),
              ),
              child: Text(
                '$count',
                style: tt.labelMedium?.copyWith(color: cs.onPrimaryContainer),
              ),
            ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: EhSpacing.m),
            trailing!,
          ],
        ],
      ),
    );
  }
}
