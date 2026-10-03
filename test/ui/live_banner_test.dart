import 'package:ehbot_mobile/api/events.dart';
import 'package:ehbot_mobile/state/live_monitor.dart';
import 'package:ehbot_mobile/ui/widgets/live_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

void main() {
  testWidgets('轮询态显示横幅，重试后消失（streaming）', (WidgetTester tester) async {
    final LiveMonitor monitor = LiveMonitor(
      api: apiWith(fakeBackend()),
      openStream: () => Stream<LiveEvent>.error(Exception('down')),
      reconnectDelay: const Duration(seconds: 30),
    );
    await monitor.start();
    await tester.pumpWidget(
      MaterialApp(home: LiveStatusBanner(monitor: monitor)),
    );
    await tester.pump();

    expect(monitor.status, LiveStatus.polling);
    expect(
      find.byKey(const ValueKey<String>('live-banner-text')),
      findsOneWidget,
    );
    expect(find.text('重试'), findsOneWidget);

    monitor.tick();
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('live-banner-text')),
      findsOneWidget,
    );

    monitor.dispose();
  });
}
