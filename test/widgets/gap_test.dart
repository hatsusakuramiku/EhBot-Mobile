import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ehbot_mobile/ui/widgets/gap.dart';

void main() {
  testWidgets('Gap builds with size', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Row(
          children: <Widget>[
            Text('a'),
            Gap.m(),
            Text('b'),
          ],
        ),
      ),
    ));
    expect(find.byType(Gap), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('HGap and VGap both render', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(
          children: <Widget>[
            Text('a'),
            VGap(8),
            Text('b'),
          ],
        ),
      ),
    ));
    expect(find.byType(VGap), findsOneWidget);
  });
}
