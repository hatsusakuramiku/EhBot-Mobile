import 'package:ehbot_mobile/ui/settings_sections_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/api_harness.dart';
import '../support/http_stubs.dart';

SettingsSection sectionByCode(String code) =>
    kSettingsSections.firstWhere((SettingsSection s) => s.code == code);

Map<String, Object?> connectionsJson() => <String, Object?>{
  'connections': <String, Object?>{
    'telegram': <String, Object?>{
      'state': <String, Object?>{'code': 'missing', 'label': '未配置'},
      'configured': false,
    },
    'exhentai': <String, Object?>{
      'state': <String, Object?>{'code': 'missing', 'label': '未配置'},
      'configured': false,
    },
    'telegram_user': <String, Object?>{
      'state': <String, Object?>{'code': 'missing', 'label': '未配置'},
      'configured': false,
      'awaiting_code': false,
      'awaiting_password': false,
    },
  },
};

Map<String, Object?> systemJson() => <String, Object?>{
  'system': <String, Object?>{
    'source_concurrency': 2,
    'poll_interval_ms': 10000,
    'timezone': 'Asia/Tokyo',
    'auto_approval_interval_minutes': 30,
    'mobile_access_ttl_seconds': 43200,
    'mobile_refresh_ttl_seconds': 2592000,
    'log_level': 'INFO',
  },
  'download_sources': <Map<String, Object?>>[
    <String, Object?>{'code': 'TELEGRAM', 'label': 'Telegram', 'rank': 1},
    <String, Object?>{'code': 'TELEGRAPH', 'label': '预览页', 'rank': 2},
  ],
  'logs': <String, Object?>{
    'levels': <Map<String, Object?>>[
      <String, Object?>{'code': 'INFO', 'label': '信息'},
      <String, Object?>{'code': 'DEBUG', 'label': '调试'},
    ],
  },
};

Map<String, Object?> passwordsJson({
  bool configured = false,
  List<Map<String, Object?>> entries = const <Map<String, Object?>>[],
}) => <String, Object?>{
  'passwords': entries,
  'api_key': configured
      ? <String, Object?>{'configured': true, 'label': '移动端'}
      : <String, Object?>{'configured': false},
  'must_change_password': false,
};

/// 一个假后端：GET 给快照，PUT 把请求 body 记下来并回同一份快照
/// （`api-key-generate` 多带一次明文，与后端一致）。
class SettingsBackend {
  SettingsBackend(this.snapshot);

  final Map<String, Object?> snapshot;
  final List<String> puts = <String>[];

  MockClient client() => MockClient((http.Request request) async {
    if (request.url.path.endsWith('/auth/whoami')) {
      return jsonResponse(whoAmIJson(kind: 'api_key'));
    }
    if (request.method == 'PUT') {
      puts.add('${request.method} ${request.url.path} ${request.body}');
      final Map<String, Object?> body = <String, Object?>{
        ...snapshot,
        if (request.body.contains('api-key-generate'))
          'api_key_plaintext': 'ehk_public.secret',
      };
      return jsonResponse(body);
    }
    return jsonResponse(snapshot);
  });
}

Future<SettingsBackend> pumpSection(
  WidgetTester tester,
  String code,
  Map<String, Object?> snapshot,
) async {
  final SettingsBackend backend = SettingsBackend(snapshot);
  await tester.pumpWidget(
    MaterialApp(
      home: SettingsSectionView(
        api: apiWith(backend.client()),
        section: sectionByCode(code),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return backend;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final Finder finder = find.byKey(ValueKey<String>(key));
  await scrollTo(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 列表是惰性构建的：目标还在屏幕外时先往下拖，直到它被建出来。
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  for (int i = 0; i < 15 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
}

/// 先滚到 key 所在的位置再输入。
Future<void> tapEnter(WidgetTester tester, String key, String text) async {
  final Finder field = find.byKey(ValueKey<String>(key));
  await scrollTo(tester, field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('连接区：保存 Bot Token 用 PUT + action=telegram', (
    WidgetTester tester,
  ) async {
    final SettingsBackend backend = await pumpSection(
      tester,
      'connections',
      connectionsJson(),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Bot Token'),
      '123:ABC',
    );
    await tapKey(tester, 'connections-telegram-save');

    expect(backend.puts.single, startsWith('PUT /api/v1/settings/connections'));
    expect(backend.puts.single, contains('"action":"telegram"'));
    expect(backend.puts.single, contains('"bot_token":"123:ABC"'));
  });

  testWidgets('连接区：ExHentai 三项一起提交', (WidgetTester tester) async {
    final SettingsBackend backend = await pumpSection(
      tester,
      'connections',
      connectionsJson(),
    );

    await tapEnter(tester, 'connections-member-id', '12345');
    await tapEnter(tester, 'connections-pass-hash', 'abcdef');
    await tapEnter(tester, 'connections-igneous', 'xyz');
    await tapKey(tester, 'connections-exhentai-save');

    expect(backend.puts.single, contains('"action":"exhentai"'));
    expect(backend.puts.single, contains('"ipb_member_id":"12345"'));
    expect(backend.puts.single, contains('"ipb_pass_hash":"abcdef"'));
    expect(backend.puts.single, contains('"igneous":"xyz"'));
  });

  testWidgets('系统区：只提交改动过的字段', (WidgetTester tester) async {
    final SettingsBackend backend = await pumpSection(
      tester,
      'system',
      systemJson(),
    );

    await tapEnter(tester, 'system-timezone', 'Asia/Shanghai');
    await tapKey(tester, 'system-save');

    expect(backend.puts.single, startsWith('PUT /api/v1/settings/system'));
    expect(backend.puts.single, contains('"timezone":"Asia/Shanghai"'));
    // 没动过的字段不该被一起写回去（后端「只写出现过的字段」）。
    expect(backend.puts.single, isNot(contains('poll_interval_ms')));
    expect(backend.puts.single, isNot(contains('source_concurrency')));
  });

  testWidgets('系统区：来源优先级用上移改写顺序', (WidgetTester tester) async {
    final SettingsBackend backend = await pumpSection(
      tester,
      'system',
      systemJson(),
    );

    // TELEGRAPH 原在第 2 位，往上挪一格 → 顺序变成 TELEGRAPH,TELEGRAM。
    await scrollTo(
      tester,
      find.byKey(const ValueKey<String>('system-priority-TELEGRAPH')),
    );
    final Finder up = find.descendant(
      of: find.byKey(const ValueKey<String>('system-priority-TELEGRAPH')),
      matching: find.byTooltip('上移'),
    );
    await tester.ensureVisible(up);
    await tester.pumpAndSettle();
    await tester.tap(up);
    await tester.pumpAndSettle();
    await tapKey(tester, 'system-save');

    expect(
      backend.puts.single,
      contains('"download_source_priority":"TELEGRAPH,TELEGRAM"'),
    );
  });

  testWidgets('密码库：生成 API Key 只在响应里给一次明文', (WidgetTester tester) async {
    final SettingsBackend backend = await pumpSection(
      tester,
      'passwords',
      passwordsJson(),
    );

    await tapKey(tester, 'passwords-api-key-generate');

    expect(backend.puts.single, contains('"action":"api-key-generate"'));
    expect(find.text('ehk_public.secret'), findsOneWidget);
  });

  testWidgets('密码库：新增归档密码带名称 / 密码 / 优先级 / 启用', (
    WidgetTester tester,
  ) async {
    final SettingsBackend backend = await pumpSection(
      tester,
      'passwords',
      passwordsJson(),
    );

    await tapEnter(tester, 'passwords-name', '常用');
    await tapEnter(tester, 'passwords-secret', 'hunter2');
    await tapEnter(tester, 'passwords-priority', '7');
    await tapKey(tester, 'passwords-add');

    expect(backend.puts.single, contains('"action":"add"'));
    expect(backend.puts.single, contains('"name":"常用"'));
    expect(backend.puts.single, contains('"password":"hunter2"'));
    expect(backend.puts.single, contains('"priority":7'));
    expect(backend.puts.single, contains('"enabled":true'));
  });

  testWidgets('密码库：删除要确认，且带 password_id', (WidgetTester tester) async {
    final SettingsBackend backend = await pumpSection(
      tester,
      'passwords',
      passwordsJson(
        entries: <Map<String, Object?>>[
          <String, Object?>{
            'password_id': 9,
            'name': '旧密码',
            'priority': 100,
            'enabled': true,
          },
        ],
      ),
    );

    await scrollTo(
      tester,
      find.byKey(const ValueKey<String>('passwords-entry-9')),
    );
    final Finder remove = find.descendant(
      of: find.byKey(const ValueKey<String>('passwords-entry-9')),
      matching: find.byTooltip('删除'),
    );
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(backend.puts, isEmpty);
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(backend.puts.single, contains('"action":"delete"'));
    expect(backend.puts.single, contains('"password_id":9'));
  });
}
