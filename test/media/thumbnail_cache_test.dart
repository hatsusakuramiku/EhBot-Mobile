import 'dart:io';
import 'dart:typed_data';

import 'package:ehbot_mobile/media/thumbnail_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('ehbot-thumbs'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('写读往返（含 etag）', () async {
    final FileThumbnailCache cache = FileThumbnailCache(dir);

    await cache.write(
      'abc',
      ThumbnailData(Uint8List.fromList(<int>[1, 2, 3]), etag: '"abc"'),
    );
    final ThumbnailData? read = await cache.read('abc');

    expect(read?.bytes, <int>[1, 2, 3]);
    expect(read?.etag, '"abc"');
  });

  test('未命中返回 null', () async {
    expect(await FileThumbnailCache(dir).read('missing'), isNull);
  });

  test('无 etag 覆盖写会清掉旧 etag', () async {
    final FileThumbnailCache cache = FileThumbnailCache(dir);
    await cache.write(
      'h',
      ThumbnailData(Uint8List.fromList(<int>[1]), etag: '"e"'),
    );
    expect((await cache.read('h'))?.etag, '"e"');

    await cache.write('h', ThumbnailData(Uint8List.fromList(<int>[2])));

    final ThumbnailData? read = await cache.read('h');
    expect(read?.bytes, <int>[2]);
    expect(read?.etag, isNull);
  });
}
