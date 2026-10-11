import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ehbot_mobile/ui/widgets/menu_fab.dart';

void main() {
  testWidgets('MenuFab primary fires', (WidgetTester tester) async {
    int tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MenuFab(
          primaryLabel: '通过',
          onPrimary: () => tapped++,
        ),
      ),
    ));
    await tester.tap(find.text('通过'));
    await tester.pump();
    expect(tapped, 1);
  });
}
