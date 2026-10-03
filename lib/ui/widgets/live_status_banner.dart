import 'package:flutter/material.dart';

import '../../state/live_monitor.dart';

/// 实时状态横幅：只在不健康时出现（断流 → 已回退轮询），带手动重试。
class LiveStatusBanner extends StatelessWidget {
  const LiveStatusBanner({super.key, required this.monitor});

  final LiveMonitor monitor;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: monitor,
    builder: (BuildContext context, Widget? child) {
      if (monitor.status != LiveStatus.polling) {
        return const SizedBox.shrink();
      }
      final ColorScheme colors = Theme.of(context).colorScheme;
      return Container(
        width: double.infinity,
        color: colors.secondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '实时连接已断开，已回退轮询。',
                key: const ValueKey<String>('live-banner-text'),
                style: TextStyle(color: colors.onSecondaryContainer),
              ),
            ),
            TextButton(
              key: const ValueKey<String>('live-banner-retry'),
              onPressed: monitor.retryStream,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    },
  );
}
