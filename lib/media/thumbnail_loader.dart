import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../api/auth_client.dart';
import 'thumbnail_cache.dart';

/// 缩略图取不到的原因；界面只关心「不显示图、渲染本地占位」。
class ThumbnailException implements Exception {
  const ThumbnailException(this.reason);

  /// `failed` / `unauthorized` / `http-<code>` / `not-modified-without-cache`。
  final String reason;

  @override
  String toString() => 'ThumbnailException($reason)';
}

/// 带鉴权的缩略图加载器（方案 A）：复用 [AuthClient]（自动带 Bearer、401 走刷新），
/// 用 `If-None-Match` 做条件请求，成功后按 hash 落盘。
class ThumbnailLoader {
  ThumbnailLoader({required this.client, required this.cache});

  final AuthClient client;
  final ThumbnailCache cache;

  final Map<String, ThumbnailData> _memory = <String, ThumbnailData>{};
  final Map<String, Future<ThumbnailData>> _inFlight =
      <String, Future<ThumbnailData>>{};

  /// 取一张缩略图；同一 hash 只发一次请求，失败会清掉以便重试。
  Future<ThumbnailData> load(String hash) {
    final ThumbnailData? cached = _memory[hash];
    if (cached != null) {
      return Future<ThumbnailData>.value(cached);
    }
    final Future<ThumbnailData>? pending = _inFlight[hash];
    if (pending != null) {
      return pending;
    }
    final Future<ThumbnailData> future = _fetch(hash);
    _inFlight[hash] = future;
    future.then<void>(
      (ThumbnailData data) {
        _memory[hash] = data;
        _inFlight.remove(hash);
      },
      onError: (Object error, StackTrace stackTrace) {
        _inFlight.remove(hash);
      },
    );
    return future;
  }

  Future<ThumbnailData> _fetch(String hash) async {
    final ThumbnailData? cached = await cache.read(hash);
    final String? etag = cached?.etag;
    final http.Response response = await client.get(
      '/api/v1/thumbnails/$hash',
      headers: etag == null ? null : <String, String>{'If-None-Match': etag},
    );
    if (response.statusCode == 304) {
      if (cached != null) {
        return cached;
      }
      throw const ThumbnailException('not-modified-without-cache');
    }
    if (response.statusCode == 401) {
      throw const ThumbnailException('unauthorized');
    }
    if (response.statusCode != 200) {
      throw ThumbnailException('http-${response.statusCode}');
    }
    if (response.headers['x-thumbnail-state'] == 'failed') {
      // 后端返回的是 SVG 占位，位图解码器不认，交给界面渲染本地占位。
      throw const ThumbnailException('failed');
    }
    final ThumbnailData data = ThumbnailData(
      Uint8List.fromList(response.bodyBytes),
      etag: response.headers['etag'],
    );
    await cache.write(hash, data);
    return data;
  }
}
