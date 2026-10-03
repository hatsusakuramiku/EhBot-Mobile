import 'dart:convert';

import 'package:ehbot_mobile/api/api_exception.dart';
import 'package:ehbot_mobile/api/events.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/api_harness.dart';
import '../support/auth_client_harness.dart';

void main() {
  group('parseSse', () {
    test('单事件：data 与默认事件名', () async {
      final List<LiveEvent> events = await parseSse(
        Stream<String>.fromIterable(<String>['data: {"type":"candidate"}\n\n']),
      ).toList();

      expect(events, hasLength(1));
      expect(events.single.event, 'message');
      expect(events.single.data, '{"type":"candidate"}');
      expect(events.single.json?['type'], 'candidate');
    });

    test('事件名与多行 data', () async {
      final List<LiveEvent> events = await parseSse(
        Stream<String>.fromIterable(<String>[
          'event: candidate\ndata: line1\ndata: line2\n\n',
        ]),
      ).toList();

      expect(events.single.event, 'candidate');
      expect(events.single.data, 'line1\nline2');
    });

    test('心跳注释与没有 data 的空行被忽略', () async {
      final List<LiveEvent> events = await parseSse(
        Stream<String>.fromIterable(<String>[
          ': keep-alive\n\n',
          'data: x\n\n',
        ]),
      ).toList();

      expect(events, hasLength(1));
      expect(events.single.data, 'x');
    });

    test('跨 chunk 拆包也能拼回一行', () async {
      final List<LiveEvent> events = await parseSse(
        Stream<String>.fromIterable(<String>['da', 'ta: hello\n', '\n']),
      ).toList();

      expect(events.single.data, 'hello');
    });

    test('流结束前未闭合的数据也会发出', () async {
      final List<LiveEvent> events = await parseSse(
        Stream<String>.fromIterable(<String>['data: tail']),
      ).toList();

      expect(events.single.data, 'tail');
    });
  });

  group('SseEventSource', () {
    test('200 时把事件流转出来', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response(
          'data: {"n":1}\n\n',
          200,
          headers: <String, String>{'content-type': 'text/event-stream'},
        ),
      );
      final SseEventSource source = SseEventSource(
        client: authClientWith(client),
      );

      final List<LiveEvent> events = await source.connect().toList();

      expect(events.single.json?['n'], 1);
    });

    test('非 200 抛 ApiException（带状态码）', () async {
      final MockClient client = MockClient(
        (http.Request request) async =>
            http.Response('{"error":{"code":"NOT_AUTHENTICATED"}}', 401),
      );

      await expectLater(
        SseEventSource(client: authClientWith(client)).connect().toList(),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });

    test('密码会话 401：先刷新一次再重连', () async {
      int refreshes = 0;
      int streams = 0;
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.path == '/api/v1/auth/refresh') {
          refreshes += 1;
          return http.Response(
            jsonEncode(<String, Object?>{
              'access_token': 'access-2',
              'refresh_token': 'refresh-2',
            }),
            200,
          );
        }
        streams += 1;
        if (request.headers['Authorization'] == 'Bearer access-2') {
          return http.Response('data: ok\n\n', 200);
        }
        return http.Response('{"error":{"code":"NOT_AUTHENTICATED"}}', 401);
      });

      final AuthClientHarness harness = AuthClientHarness(client);
      final List<LiveEvent> events = await SseEventSource(
        client: harness.client,
      ).connect().toList();

      expect(refreshes, 1);
      expect(streams, 2);
      expect(events.single.data, 'ok');
      expect(harness.session.accessToken, 'access-2');
    });
  });
}
