import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ehbot_mobile/ui/theme.dart';
import 'package:ehbot_mobile/ui/widgets/metric_strip.dart';

void main() {
  testWidgets('MetricStrip renders all items', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MetricStrip(items: <MetricStripItem>[
          MetricStripItem(
            key: const ValueKey<String>('m1'),
            label: '下载',
            value: 3,
          ),
          MetricStripItem(
            key: const ValueKey<String>('m2'),
            label: '打包',
            value: 7,
          ),
        ]),
      ),
    ));
    await tester.pump(EhAnim.slow);
    expect(find.byKey(const ValueKey<String>('m1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('m2')), findsOneWidget);
  });

  testWidgets('MetricStrip onTap fires', (WidgetTester tester) async {
    int tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MetricStrip(items: <MetricStripItem>[
          MetricStripItem(
            label: 'tab',
            value: 1,
            onTap: () => tapped++,
          ),
        ]),
      ),
    ));
    await tester.tap(find.text('tab'));
    await tester.pump();
    expect(tapped, 1);
  });
}
