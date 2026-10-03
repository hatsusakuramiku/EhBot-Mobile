import 'package:ehbot_mobile/api/probe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final Uri base = Uri.parse('https://ehbot.example.com');

  test('healthz 200 + whoami 401 → 可达且鉴权已启用', () async {
    final MockClient client = MockClient((http.Request request) async {
      if (request.url.path == '/healthz') {
        return http.Response('ok', 200);
      }
      return http.Response('{"error":{"code":"NOT_AUTHENTICATED"}}', 401);
    });

    final ServerProbeResult result = await probeServer(
      client: client,
      baseUri: base,
    );

    expect(result.reachable, isTrue);
    expect(result.authSupported, isTrue);
  });

  test('healthz 200 + whoami 404 → 后端还没 B1/B2', () async {
    final MockClient client = MockClient((http.Request request) async {
      if (request.url.path == '/healthz') {
        return http.Response('ok', 200);
      }
      return http.Response('{"detail":"Not Found"}', 404);
    });

    final ServerProbeResult result = await probeServer(
      client: client,
      baseUri: base,
    );

    expect(result.reachable, isTrue);
    expect(result.authSupported, isFalse);
    expect(result.message, contains('B1/B2'));
  });

  test('healthz 非 2xx → 不可达', () async {
    final MockClient client = MockClient(
      (http.Request request) async => http.Response('bad', 500),
    );

    final ServerProbeResult result = await probeServer(
      client: client,
      baseUri: base,
    );

    expect(result.reachable, isFalse);
    expect(result.message, contains('500'));
  });

  test('连不上 → 不可达', () async {
    final MockClient client = MockClient(
      (http.Request request) async =>
          throw http.ClientException('connection refused'),
    );

    final ServerProbeResult result = await probeServer(
      client: client,
      baseUri: base,
    );

    expect(result.reachable, isFalse);
    expect(result.authSupported, isFalse);
  });
}
