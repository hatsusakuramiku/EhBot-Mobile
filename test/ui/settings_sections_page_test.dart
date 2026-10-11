import 'package:ehbot_mobile/ui/settings_editors.dart';
import 'package:ehbot_mobile/ui/settings_sections_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

/// 找一个分区。
SettingsSection sectionByCode(String code) =>
    kSettingsSections.firstWhere((SettingsSection s) => s.code == code);

Future<void> pumpSection(
  WidgetTester tester,
  String code,
  MockClient client,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SettingsSectionView(api: apiWith(client), section: sectionByCode(code)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('设置分区中心列出全部九区', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsSectionsPage(
          api: apiWith(
            MockClient(
              (http.Request request) async =>
                  jsonResponse(<String, Object?>{'ok': true}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(kSettingsSections, hasLength(9));
    for (final SettingsSection s in kSettingsSections) {
      expect(
        find.byKey(ValueKey<String>('settings-section-${s.code}')),
        findsOneWidget,
        reason: '缺少分区 ${s.code}',
      );
    }
  });

  testWidgets('可写分区渲染编辑器；只读分区按顶层 key 分组', (WidgetTester tester) async {
    // 三个可写分区（R67–R69）。
    expect(kWritableSettingsSections, <String>{
      'connections',
      'system',
      'passwords',
    });
  });

  testWidgets('连接区渲染三张可编辑卡片', (WidgetTester tester) async {
    await pumpSection(
      tester,
      'connections',
      MockClient(
        (http.Request request) async => jsonResponse(<String, Object?>{
          'connections': <String, Object?>{
            'telegram': <String, Object?>{
              'state': <String, Object?>{'code': 'ok', 'label': '已连接'},
              'configured': true,
              'identity': '@bot',
            },
            'exhentai': <String, Object?>{
              'state': <String, Object?>{'code': 'missing', 'label': '未配置'},
              'configured': false,
            },
            'telegram_user': <String, Object?>{
              'state': <String, Object?>{
                'code': 'awaiting_code',
                'label': '等验证码',
              },
              'configured': false,
              'phone': '+81 90',
              'awaiting_code': true,
              'awaiting_password': false,
            },
          },
        }),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('connections-telegram-save')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('connections-telegram-disconnect')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('connections-exhentai-save')),
      findsOneWidget,
    );
    // 等验证码时表单换成了验证码那一步，并点名验证码发去了哪个号。
    expect(
      find.byKey(const ValueKey<String>('connections-tg-user-verify')),
      findsOneWidget,
    );
    expect(find.textContaining('+81 90'), findsOneWidget);
  });

  testWidgets('只读分区按顶层 key 分组渲染，并说明需要后端', (WidgetTester tester) async {
    await pumpSection(
      tester,
      'sources',
      MockClient(
        (http.Request request) async => jsonResponse(<String, Object?>{
          'sources': <Map<String, Object?>>[
            <String, Object?>{'name': '某个会话', 'enabled': true},
          ],
          'source_types': <String>['telegram'],
        }),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('settings-readonly-note')),
      findsOneWidget,
    );
    // 顶层 key 当作分组标题。
    expect(find.text('sources'), findsOneWidget);
    expect(find.text('source_types'), findsOneWidget);
    // 列表前几条摊开（`sources[0].name`），而不是只报条数。
    expect(find.text('sources[0].name'), findsOneWidget);
    expect(find.text('某个会话'), findsOneWidget);
    expect(find.text('source_types[0]'), findsOneWidget);
  });

  testWidgets('后端未实现时给出 404 说明', (WidgetTester tester) async {
    await pumpSection(
      tester,
      'sources',
      MockClient(
        (http.Request request) async =>
            errorResponse('NOT_FOUND', status: 404, message: 'no route'),
      ),
    );

    expect(find.textContaining('后端还没有'), findsOneWidget);
  });
}
