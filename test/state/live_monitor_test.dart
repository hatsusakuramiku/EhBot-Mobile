import 'dart:async';

import 'package:ehbot_mobile/api/events.dart';
import 'package:ehbot_mobile/state/live_monitor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

void main() {
  final MockClient metaClient = MockClient((http.Request request) async {
    if (request.url.path.endsWith('/meta')) {
      return jsonResponse(<String, Object?>{
        'polling': <String, Object?>{'interval_ms': 20, 'idle_interval_ms': 40},
        'timezone': 'UTC',
      });
    }
    return jsonResponse(<String, Object?>{});
  });

  test('SSE 事件 → streaming 并发出 tick', () async {
    final StreamController<LiveEvent> controller =
        StreamController<LiveEvent>();
    final LiveMonitor monitor = LiveMonitor(
      api: apiWith(metaClient),
      openStream: () => controller.stream,
    );
    final List<int> seen = <int>[];
    monitor.ticks.listen(seen.add);

    await monitor.start();
    controller.add(const LiveEvent(event: 'candidate', data: '{"id":1}'));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(monitor.status, LiveStatus.streaming);
    expect(monitor.tickCount, 1);
    expect(seen, <int>[1]);
    expect(monitor.pollInterval, const Duration(milliseconds: 20));

    await controller.close();
    monitor.dispose();
  });

  test('SSE 出错 → 回退轮询，并按间隔继续 tick', () async {
    final LiveMonitor monitor = LiveMonitor(
      api: apiWith(metaClient),
      openStream: () => Stream<LiveEvent>.error(Exception('boom')),
      reconnectDelay: const Duration(seconds: 30),
    );

    await monitor.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(monitor.status, LiveStatus.polling);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(monitor.tickCount, greaterThanOrEqualTo(2));

    monitor.dispose();
  });

  test('到点重试 SSE 并恢复 streaming', () async {
    final StreamController<LiveEvent> good = StreamController<LiveEvent>();
    int attempts = 0;
    final LiveMonitor monitor = LiveMonitor(
      api: apiWith(metaClient),
      openStream: () {
        attempts += 1;
        if (attempts == 1) {
          return Stream<LiveEvent>.error(Exception('first fails'));
        }
        return good.stream;
      },
      reconnectDelay: const Duration(milliseconds: 30),
    );

    await monitor.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(attempts, greaterThanOrEqualTo(2));

    good.add(const LiveEvent(data: '{}'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(monitor.status, LiveStatus.streaming);

    await good.close();
    monitor.dispose();
  });

  test('dispose 后停止 tick 与轮询', () async {
    final LiveMonitor monitor = LiveMonitor(
      api: apiWith(metaClient),
      openStream: () => Stream<LiveEvent>.error(Exception('boom')),
      reconnectDelay: const Duration(seconds: 30),
    );

    await monitor.start();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final int before = monitor.tickCount;
    monitor.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(monitor.tickCount, before);
  });

  test('meta 拿不到时用默认轮询间隔', () async {
    final MockClient failing = MockClient(
      (http.Request request) async => http.Response('boom', 500),
    );
    final LiveMonitor monitor = LiveMonitor(
      api: apiWith(failing),
      openStream: () => const Stream<LiveEvent>.empty(),
    );

    await monitor.start();

    expect(monitor.pollInterval, const Duration(seconds: 10));
    monitor.dispose();
  });
}
