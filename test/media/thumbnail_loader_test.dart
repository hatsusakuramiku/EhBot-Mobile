import 'dart:io';
import 'dart:typed_data';

import 'package:ehbot_mobile/api/auth_client.dart';
import 'package:ehbot_mobile/api/auth_session.dart';
import 'package:ehbot_mobile/media/thumbnail_cache.dart';
import 'package:ehbot_mobile/media/thumbnail_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final Uri base = Uri.parse('https://ehbot.example.com');
  late Directory dir;
  late FileThumbnailCache cache;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ehbot-thumbs');
    cache = FileThumbnailCache(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  ThumbnailLoader loaderWith(http.Client inner) => ThumbnailLoader(
    client: AuthClient(
      inner: inner,
      baseUri: base,
      session: AuthSession.apiKey('ehk_x'),
      onSessionExpired: () {},
    ),
    cache: cache,
  );

  test('200：带鉴权取图并写盘，第二次走内存不再请求', () async {
    int calls = 0;
    late http.Request captured;
    final ThumbnailLoader loader = loaderWith(
      MockClient((http.Request request) async {
        calls += 1;
        captured = request;
        return http.Response.bytes(
          <int>[7, 8, 9],
          200,
          headers: <String, String>{
            'etag': '"hash-1"',
            'content-type': 'image/png',
          },
        );
      }),
    );

    final ThumbnailData first = await loader.load('hash-1');

    expect(first.bytes, <int>[7, 8, 9]);
    expect(captured.url.path, '/api/v1/thumbnails/hash-1');
    expect(captured.headers['Authorization'], 'Bearer ehk_x');
    expect((await cache.read('hash-1'))?.bytes, <int>[7, 8, 9]);

    await loader.load('hash-1');
    expect(calls, 1);
  });

  test('有缓存时带 If-None-Match；304 直接用缓存', () async {
    await cache.write(
      'hash-2',
      ThumbnailData(Uint8List.fromList(<int>[1]), etag: '"hash-2"'),
    );
    late http.Request captured;
    final ThumbnailLoader loader = loaderWith(
      MockClient((http.Request request) async {
        captured = request;
        return http.Response('', 304);
      }),
    );

    final ThumbnailData data = await loader.load('hash-2');

    expect(captured.headers['If-None-Match'], '"hash-2"');
    expect(data.bytes, <int>[1]);
  });

  test('X-Thumbnail-State: failed → 抛错且不写盘', () async {
    final ThumbnailLoader loader = loaderWith(
      MockClient(
        (http.Request request) async => http.Response.bytes(
          '<svg/>'.codeUnits,
          200,
          headers: <String, String>{'x-thumbnail-state': 'failed'},
        ),
      ),
    );

    await expectLater(
      loader.load('hash-3'),
      throwsA(
        isA<ThumbnailException>().having(
          (ThumbnailException e) => e.reason,
          'reason',
          'failed',
        ),
      ),
    );
    expect(await cache.read('hash-3'), isNull);
  });

  test('401 → unauthorized', () async {
    final ThumbnailLoader loader = loaderWith(
      MockClient(
        (http.Request request) async =>
            http.Response('{"error":{"code":"NOT_AUTHENTICATED"}}', 401),
      ),
    );

    await expectLater(
      loader.load('hash-4'),
      throwsA(
        isA<ThumbnailException>().having(
          (ThumbnailException e) => e.reason,
          'reason',
          'unauthorized',
        ),
      ),
    );
  });

  test('失败后允许重试（清掉 in-flight 记录）', () async {
    int calls = 0;
    final ThumbnailLoader loader = loaderWith(
      MockClient((http.Request request) async {
        calls += 1;
        if (calls == 1) {
          return http.Response('boom', 500);
        }
        return http.Response.bytes(<int>[4, 2], 200);
      }),
    );

    await expectLater(
      loader.load('hash-5'),
      throwsA(isA<ThumbnailException>()),
    );
    final ThumbnailData data = await loader.load('hash-5');

    expect(data.bytes, <int>[4, 2]);
    expect(calls, 2);
  });

  test('没有缓存却返回 304 → 抛错', () async {
    final ThumbnailLoader loader = loaderWith(
      MockClient((http.Request request) async => http.Response('', 304)),
    );

    await expectLater(
      loader.load('hash-6'),
      throwsA(
        isA<ThumbnailException>().having(
          (ThumbnailException e) => e.reason,
          'reason',
          'not-modified-without-cache',
        ),
      ),
    );
  });
}
