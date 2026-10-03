/// 把服务器地址与 `/api/v1` 路径拼起来，保留用户配置的反代前缀（`APP_ROOT_PATH`）。
Uri resolveUri(Uri base, String path, [Map<String, String>? query]) {
  final String prefix = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(
    path: '$prefix$path',
    queryParameters: query == null || query.isEmpty ? null : query,
  );
}
