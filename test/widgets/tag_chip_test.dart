import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ehbot_mobile/ui/widgets/tag_chip.dart';

void main() {
  testWidgets('TagChip renders label', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: TagChip(label: 'chinese'))),
    ));
    expect(find.text('chinese'), findsOneWidget);
  });

  testWidgets('TagChip selected has different look',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: TagChip(label: 'chinese', selected: true),
        ),
      ),
    ));
    expect(find.text('chinese'), findsOneWidget);
  });
}
