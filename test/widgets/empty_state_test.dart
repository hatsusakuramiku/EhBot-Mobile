import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ehbot_mobile/ui/widgets/empty_state.dart';

void main() {
  group('EmptyState', () {
    testWidgets('renders primary text', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.search_off,
            primary: '没有匹配',
          ),
        ),
      ));
      expect(find.text('没有匹配'), findsOneWidget);
    });

    testWidgets('renders action button', (WidgetTester tester) async {
      int tapped = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EmptyState(
            primary: '空',
            actionLabel: '清除筛选',
            onAction: () => tapped++,
          ),
        ),
      ));
      await tester.tap(find.text('清除筛选'));
      await tester.pump();
      expect(tapped, 1);
    });
  });
}
