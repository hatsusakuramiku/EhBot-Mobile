import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ehbot_mobile/ui/widgets/large_title_app_bar.dart';

void main() {
  testWidgets('EhLargeTitleAppBar renders title', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: <Widget>[
            EhLargeTitleAppBar(title: '工作台', subtitle: 'Hello'),
          ],
        ),
      ),
    ));
    expect(find.text('工作台'), findsWidgets);
    expect(find.text('Hello'), findsOneWidget);
  });
}
