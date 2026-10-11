import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ehbot_mobile/ui/widgets/eh_card.dart';

void main() {
  group('EhCard', () {
    for (final EhCardTone tone in EhCardTone.values) {
      testWidgets('renders for tone=$tone', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: EhCard(tone: tone, child: const Text('hi')),
          ),
        ));
        expect(find.text('hi'), findsOneWidget);
      });
    }

    testWidgets('onTap invokes callback', (WidgetTester tester) async {
      int tapped = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EhCard(
            onTap: () => tapped++,
            child: const Text('tap'),
          ),
        ),
      ));
      await tester.tap(find.text('tap'));
      await tester.pump();
      expect(tapped, 1);
    });
  });
}
