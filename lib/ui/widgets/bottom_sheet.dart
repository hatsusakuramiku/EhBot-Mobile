import 'package:flutter/material.dart';

import '../theme.dart';

/// 包一层 `showModalBottomSheet`：圆角 / 拖把 / 安全区 / 半屏起步 / 全屏可选。
class EhBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = true,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(EhRadius.sheet),
        ),
      ),
      builder: builder,
    );
  }
}
