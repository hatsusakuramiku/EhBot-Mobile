import 'package:ehbot_mobile/ui/logs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

Map<String, Object?> logJson({
  String level = 'INFO',
  String label = '信息',
  String event = '任务 #7 开始下载',
}) => <String, Object?>{
  'level': <String, Object?>{'code': level, 'label': label, 'tone': 'info'},
  'timestamp': '2026-10-03T10:00:00Z',
  'logger': 'app.downloads',
  'event': event,
  'raw': event,
};

void main() {
  Future<void> pump(WidgetTester tester, MockClient client) async {
    await tester.pumpWidget(MaterialApp(home: LogsPage(api: apiWith(client))));
    await tester.pumpAndSettle();
  }

  testWidgets('日志页渲染历史并带暂停按钮', (WidgetTester tester) async {
    await pump(
      tester,
      MockClient((http.Request request) async {
        if (request.url.path.endsWith('/logs')) {
          return jsonResponse(<String, Object?>{
            'entries': <Map<String, Object?>>[logJson()],
            'level': '',
            'limit': 200,
          });
        }
        return http.Response('', 404);
      }),
    );

    expect(find.text('任务 #7 开始下载'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('logs-pause')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('logs-level-ERROR')), findsOneWidget);
  });

  testWidgets('日志端点缺失时给出 404 说明', (WidgetTester tester) async {
    await pump(
      tester,
      MockClient((http.Request request) async =>
          errorResponse('NOT_FOUND', status: 404, message: 'no route')),
    );

    expect(find.textContaining('后端还没有'), findsWidgets);
  });
}
