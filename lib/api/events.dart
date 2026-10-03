import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'auth_client.dart';

/// 一条 SSE 事件。
class LiveEvent {
  const LiveEvent({this.event = 'message', this.data = ''});

  /// `event:` 名（缺省 `message`）。
  final String event;

  /// 拼接后的 `data:` 内容（多行用 `\n` 连接）。
  final String data;

  /// `data` 能解析成 JSON 对象时返回它，否则 `null`。
  Map<String, dynamic>? get json {
    try {
      final Object? decoded = jsonDecode(data);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }
}

/// 把 SSE 文本流切成事件流（`CONTRACT.md` §5 的 `/api/v1/events`）。
///
/// 规范要点：空行分隔事件、`:` 开头是注释（心跳）、多行 `data:` 用 `\n` 连接。
/// 内部有行缓冲，所以一次 chunk 从中间断开也能正确拼回来。
Stream<LiveEvent> parseSse(Stream<String> source) async* {
  String pending = '';
  String eventName = 'message';
  final StringBuffer data = StringBuffer();

  String stripCr(String line) =>
      line.endsWith('\r') ? line.substring(0, line.length - 1) : line;

  /// 处理一整行；返回需要发出的事件（没有则 `null`）。
  LiveEvent? consume(String line) {
    if (line.isEmpty) {
      if (data.isEmpty) {
        return null;
      }
      final LiveEvent ready = LiveEvent(
        event: eventName,
        data: data.toString().trimRight(),
      );
      data.clear();
      eventName = 'message';
      return ready;
    }
    if (line.startsWith(':')) {
      return null;
    }
    if (line.startsWith('event:')) {
      eventName = line.substring(6).trim();
      return null;
    }
    if (line.startsWith('data:')) {
      final String value = line.substring(5);
      data.writeln(value.startsWith(' ') ? value.substring(1) : value);
    }
    return null;
  }

  final StreamIterator<String> iterator = StreamIterator<String>(source);
  try {
    while (await iterator.moveNext()) {
      pending += iterator.current;
      while (pending.contains('\n')) {
        final int index = pending.indexOf('\n');
        final String line = stripCr(pending.substring(0, index));
        pending = pending.substring(index + 1);
        final LiveEvent? ready = consume(line);
        if (ready != null) {
          yield ready;
        }
      }
    }
    if (pending.isNotEmpty) {
      final LiveEvent? ready = consume(stripCr(pending));
      if (ready != null) {
        yield ready;
      }
    }
  } finally {
    await iterator.cancel();
  }
  if (data.isNotEmpty) {
    yield LiveEvent(event: eventName, data: data.toString().trimRight());
  }
}

/// SSE 事件源：带鉴权连 `/api/v1/events`（Dart 客户端能带 `Authorization` 头）。
class SseEventSource {
  SseEventSource({required this.client, this.path = '/api/v1/events'});

  final AuthClient client;
  final String path;

  Stream<LiveEvent> connect() async* {
    final http.StreamedResponse response = await client.stream(path);
    if (response.statusCode != 200) {
      throw ApiException(
        code: 'SSE_HTTP_${response.statusCode}',
        message: '实时流连接失败（HTTP ${response.statusCode}）。',
        statusCode: response.statusCode,
      );
    }
    yield* parseSse(response.stream.transform(utf8.decoder));
  }
}
