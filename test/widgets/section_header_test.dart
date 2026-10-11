import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ehbot_mobile/ui/widgets/section_header.dart';

void main() {
  testWidgets('SectionHeader shows count badge', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SectionHeader(title: '候选项', count: 12),
      ),
    ));
    expect(find.text('候选项'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('SectionHeader without count', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SectionHeader(title: '历史')),
    ));
    expect(find.text('历史'), findsOneWidget);
  });
}
