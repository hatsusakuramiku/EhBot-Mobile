import 'package:ehbot_mobile/ui/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('启动后渲染 M0 骨架页', (WidgetTester tester) async {
    await tester.pumpWidget(const EhBotApp());

    expect(find.text('EhBot'), findsOneWidget);
    expect(find.text('工程骨架已就位，界面自 M1 起实现。'), findsOneWidget);
  });
}
