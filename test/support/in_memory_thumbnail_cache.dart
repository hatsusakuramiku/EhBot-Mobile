import 'package:ehbot_mobile/media/thumbnail_cache.dart';

/// 测试用内存缩略图缓存：widget 测试的 fake-async 跑不动真实文件 I/O。
class InMemoryThumbnailCache implements ThumbnailCache {
  final Map<String, ThumbnailData> entries = <String, ThumbnailData>{};

  @override
  Future<ThumbnailData?> read(String hash) async => entries[hash];

  @override
  Future<void> write(String hash, ThumbnailData data) async =>
      entries[hash] = data;
}
