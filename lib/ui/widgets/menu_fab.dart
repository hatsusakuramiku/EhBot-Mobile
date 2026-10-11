import 'package:flutter/material.dart';
import '../theme.dart';

/// 详情页底部 sticky 操作条：**主操作永远在拇指区**，**危险按钮绝对不放这里**。
class MenuFab extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final List<PopupMenuEntry<String>> secondary;
  final ValueChanged<String>? onSecondary;

  const MenuFab({
    super.key,
    required this.primaryLabel,
    this.onPrimary,
    this.secondary = const <PopupMenuEntry<String>>[],
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(EhSpacing.m),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(color: cs.outlineVariant, width: 0.5),
          ),
        ),
        child: Row(
          children: <Widget>[
            if (secondary.isNotEmpty)
              IconButton(
                tooltip: '更多操作',
                onPressed: secondary.isEmpty || onSecondary == null
                    ? null
                    : () async {
                        final String? picked = await showMenu<String>(
                          context: context,
                          position: RelativeRect.fromLTRB(
                            EhSpacing.l,
                            0,
                            EhSpacing.l,
                            80,
                          ),
                          items: secondary,
                        );
                        if (picked != null) {
                          onSecondary!(picked);
                        }
                      },
                icon: const Icon(Icons.more_vert),
              ),
            const SizedBox(width: EhSpacing.s),
            Expanded(
              child: FilledButton(
                key: ValueKey<String>('menufab-primary'),
                onPressed: onPrimary,
                child: Text(primaryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
