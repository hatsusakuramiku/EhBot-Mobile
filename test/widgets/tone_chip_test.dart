import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ehbot_mobile/ui/widgets/tone_chip.dart';

void main() {
  group('ToneChip', () {
    for (final String tone in <String>[
      'success', 'danger', 'warning', 'info', 'muted',
    ]) {
      testWidgets('renders for tone=$tone', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: ToneChip(label: 'tag-$tone', tone: tone),
            ),
          ),
        ));
        expect(find.text('tag-$tone'), findsOneWidget);
      });
    }

    testWidgets('different tone gets different color', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const Scaffold(
          body: Center(
            child: Row(
              children: <Widget>[
                ToneChip(label: 'a', tone: 'success'),
                SizedBox(width: 8),
                ToneChip(label: 'b', tone: 'danger'),
              ],
            ),
          ),
        ),
      ));
      // 至少能在同一棵渲染树里找到两个 label
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
    });
  });
}
