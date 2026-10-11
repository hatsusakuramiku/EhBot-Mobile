import 'package:flutter/material.dart';

/// 设计 token（间距 / 圆角 / 动效时长 / 断点）。所有页面只能引用这些常量，
/// 不能再硬编码 `EdgeInsets.all(16)` / `BorderRadius.circular(12)`。
abstract final class EhSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

abstract final class EhRadius {
  static const double card = 16;
  static const double chip = 12;
  static const double sheet = 28;
  static const double button = 20;
}

abstract final class EhAnim {
  /// 100 ms 左右（按钮按下 / chip 切换）。
  static const Duration fast = Duration(milliseconds: 150);
  /// 250 ms（sheet / 切页）。
  static const Duration medium = Duration(milliseconds: 250);
  /// 350 ms（大块入出场 / 数字滚动）。
  static const Duration slow = Duration(milliseconds: 350);
}

abstract final class EhBreakpoints {
  /// < 600 sp：手机竖屏（默认）。
  static const double compact = 600;
  /// 600–840 sp：大手机横 / 平板。
  static const double medium = 840;
  /// ≥ 840 sp：平板横 / 桌面。
  static const double expanded = 1200;
}

/// 按屏宽给网格列数：< 600 手机 1 列、≥ 600 大手机 2 列、≥ 840 平板/桌面 3 列。
int ehColumnsForWidth(
  double width, {
  int narrow = 1,
  int wide = 2,
  int extraWide = 3,
}) {
  if (width >= EhBreakpoints.medium) {
    return extraWide;
  }
  if (width >= EhBreakpoints.compact) {
    return wide;
  }
  return narrow;
}

/// 应用主题。浅 / 深双轨，Seed 粉红 `0xFFE91E63`（EH 类内容的强调色偏好）。
class AppTheme {
  /// Seed color。
  static const Color seed = Color(0xFFE91E63);

  /// 把后端的 `StatusView.tone`（`success / danger / warning / info / muted`）
  /// 投影成 M3 的语义色。列表、详情页、告警条统一用。
  static Color toneColor(BuildContext context, String tone) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return switch (tone) {
      'success' => cs.tertiary,
      'danger' => cs.error,
      'warning' => cs.tertiaryContainer,
      'info' => cs.primary,
      _ => cs.onSurfaceVariant,
    };
  }

  /// 与 [toneColor] 配套的前景色。文案 vs 背景 ≥ 4.5:1（M7 测试断言）。
  static Color onToneColor(BuildContext context, String tone) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return switch (tone) {
      'success' => cs.onTertiary,
      'danger' => cs.onError,
      'warning' => cs.onTertiaryContainer,
      'info' => cs.onPrimary,
      _ => cs.onSurface,
    };
  }

  static ThemeData light() {
    final ColorScheme cs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return _buildTheme(cs, Brightness.light);
  }

  static ThemeData dark() {
    final ColorScheme cs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return _buildTheme(cs, Brightness.dark);
  }

  /// 把当前 `Theme.of(...).colorScheme` 的色调应用到 surface / outline 默认值。
  static ThemeData _buildTheme(ColorScheme cs, Brightness _) {
    final TextTheme text = _buildTextTheme(cs);
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      brightness: cs.brightness,
      scaffoldBackgroundColor: cs.surface,
      textTheme: text,
      // 卡片：0/1 elevation，靠 outline 区分层级（M3 推荐）。
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EhRadius.card),
          side: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      // 按钮：圆角 + tonal 替代旧 `OutlinedButton` 默认矩形。
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: EhSpacing.xl,
            vertical: EhSpacing.m,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EhRadius.button),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: EhSpacing.xl,
            vertical: EhSpacing.m,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EhRadius.button),
          ),
        ),
      ),
      // Chip：圆角 12，密度舒适。
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EhRadius.chip),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      // 大标题 / 普通 AppBar。
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: cs.onSurface),
      ),
      // 底部 sheet：圆角 28。
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(EhRadius.sheet),
          ),
        ),
      ),
      // divider 用 outlineVariant 替代 hard-coded grey。
      dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 0.5),
      // 触达目标 ≥ 48 dp。
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );
  }

  static TextTheme _buildTextTheme(ColorScheme cs) {
    final Color onSurface = cs.onSurface;
    return TextTheme(
      displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400, color: onSurface),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400, color: onSurface),
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: onSurface),
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w400, color: onSurface),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w400, color: onSurface),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: onSurface),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: onSurface),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: onSurface),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: onSurface),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: onSurface),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: onSurface),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: onSurface),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: onSurface),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: onSurface),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: onSurface),
    );
  }

}
