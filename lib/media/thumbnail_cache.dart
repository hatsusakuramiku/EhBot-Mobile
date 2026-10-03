import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 缩略图字节 + 校验信息。
class ThumbnailData {
  const ThumbnailData(this.bytes, {this.etag});

  final Uint8List bytes;
  final String? etag;
}

/// 按 hash 落盘缓存；缩略图 URL 不可变，命中即终态（`CONTRACT.md` §3）。
abstract interface class ThumbnailCache {
  Future<ThumbnailData?> read(String hash);
  Future<void> write(String hash, ThumbnailData data);
}

/// 默认实现：构造是同步的，应用缓存目录在首次读写时才解析。
///
/// 这样上层（`AppState`）不必为了拿一个缓存实例去 await 插件。
class DefaultThumbnailCache implements ThumbnailCache {
  DefaultThumbnailCache();

  Future<FileThumbnailCache>? _delegate;

  Future<FileThumbnailCache> _resolve() =>
      _delegate ??= FileThumbnailCache.openDefault();

  @override
  Future<ThumbnailData?> read(String hash) async =>
      (await _resolve()).read(hash);

  @override
  Future<void> write(String hash, ThumbnailData data) async =>
      (await _resolve()).write(hash, data);
}

/// 文件缓存：`<cacheDir>/thumbnails/<hash>.thumb` 与 `<hash>.etag`。
class FileThumbnailCache implements ThumbnailCache {
  FileThumbnailCache(this.directory);

  /// 应用缓存目录（系统可随时清理，不视为持久数据）。
  static Future<FileThumbnailCache> openDefault() async {
    final Directory base = await getApplicationCacheDirectory();
    return FileThumbnailCache(Directory('${base.path}/thumbnails'));
  }

  final Directory directory;

  File _bytesFile(String hash) => File('${directory.path}/$hash.thumb');

  File _etagFile(String hash) => File('${directory.path}/$hash.etag');

  @override
  Future<ThumbnailData?> read(String hash) async {
    final File file = _bytesFile(hash);
    if (!await file.exists()) {
      return null;
    }
    final Uint8List bytes = await file.readAsBytes();
    final File etagFile = _etagFile(hash);
    final String etag = await etagFile.exists()
        ? (await etagFile.readAsString()).trim()
        : '';
    return ThumbnailData(bytes, etag: etag.isEmpty ? null : etag);
  }

  @override
  Future<void> write(String hash, ThumbnailData data) async {
    await directory.create(recursive: true);
    await _bytesFile(hash).writeAsBytes(data.bytes, flush: true);
    final String? etag = data.etag;
    final File etagFile = _etagFile(hash);
    if (etag == null || etag.isEmpty) {
      if (await etagFile.exists()) {
        await etagFile.delete();
      }
      return;
    }
    await etagFile.writeAsString(etag, flush: true);
  }
}
