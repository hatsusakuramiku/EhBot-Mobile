import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ehbot_mobile/ui/theme.dart';

void main() {
  group('AppTheme', () {
    testWidgets('light & dark themes both valid', (WidgetTester tester) async {
      ThemeData light = AppTheme.light();
      ThemeData dark = AppTheme.dark();
      expect(light.useMaterial3, true);
      expect(dark.useMaterial3, true);
      // 颜色不同
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
    });

    testWidgets('toneColor picks semantic colors',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (BuildContext context) {
            final Color success =
                AppTheme.toneColor(context, 'success');
            final Color danger = AppTheme.toneColor(context, 'danger');
            final Color muted = AppTheme.toneColor(context, 'muted');
            expect(success, isNot(equals(danger)));
            expect(muted, isNot(equals(success)));
            return const SizedBox.shrink();
          },
        ),
      ));
    });

    test('EhSpacing & EhRadius & EhAnim & EhBreakpoints exported', () {
      expect(EhSpacing.l, 16);
      expect(EhRadius.card, 16);
      expect(EhAnim.medium.inMilliseconds, 250);
      expect(EhBreakpoints.expanded, 1200);
    });

    test('ehColumnsForWidth follows the three breakpoints', () {
      expect(ehColumnsForWidth(360), 1); // 手机竖屏
      expect(ehColumnsForWidth(599), 1);
      expect(ehColumnsForWidth(600), 2); // 大手机 / 平板
      expect(ehColumnsForWidth(839), 2);
      expect(ehColumnsForWidth(840), 3); // 平板横 / 桌面
      expect(ehColumnsForWidth(2000), 3);
    });
  });
}
