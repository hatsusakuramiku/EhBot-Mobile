import 'package:ehbot_mobile/ui/dedup_page.dart';
import 'package:ehbot_mobile/ui/widgets/tone_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

Map<String, Object?> entryJson(String id, String title, {String reason = ''}) =>
    <String, Object?>{
      'candidate_id': id,
      'title': title,
      'status': <String, Object?>{
        'code': 'DOWNLOADED',
        'label': '已下载',
        'tone': 'success',
      },
      'pack_label': '已打包',
      'page_count': 120,
      'reason': reason,
    };

Map<String, Object?> planJson({bool empty = false}) => <String, Object?>{
  'removable': empty ? 0 : 1,
  'groups': empty
      ? <Object>[]
      : <Map<String, Object?>>[
          <String, Object?>{
            'ex_gid': '999',
            'keep': entryJson('11', '保留本', reason: '该组最优'),
            'remove': <Map<String, Object?>>[
              entryJson('12', '重复本', reason: '页数较少'),
            ],
          },
        ],
};

void main() {
  Future<void> pump(WidgetTester tester, MockClient client) async {
    await tester.pumpWidget(MaterialApp(home: DedupPage(api: apiWith(client))));
    await tester.pumpAndSettle();
  }

  testWidgets('去重计划展示保留与移除并带确认按钮', (WidgetTester tester) async {
    await pump(
      tester,
      MockClient((http.Request request) async =>
          jsonResponse(planJson())),
    );

    expect(find.text('保留本'), findsOneWidget);
    expect(find.text('重复本'), findsOneWidget);
    expect(find.widgetWithText(ToneChip, '保留'), findsOneWidget);
    expect(find.widgetWithText(ToneChip, '移除'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('dedup-apply')), findsOneWidget);
    expect(find.textContaining('将移除 1 件重复作品'), findsOneWidget);
  });

  testWidgets('没有重复时显示空状态', (WidgetTester tester) async {
    await pump(
      tester,
      MockClient((http.Request request) async =>
          jsonResponse(planJson(empty: true))),
    );
    expect(find.text('没有发现重复作品'), findsOneWidget);
  });

  testWidgets('后端未实现时给出 404 说明', (WidgetTester tester) async {
    await pump(
      tester,
      MockClient((http.Request request) async =>
          errorResponse('NOT_FOUND', status: 404, message: 'no route')),
    );
    expect(find.textContaining('B-M8'), findsOneWidget);
  });
}
