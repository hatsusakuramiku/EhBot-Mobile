/// `/api/v1` 调用失败的统一异常。
///
/// [code] 优先取后端错误信封的 `error.code`（见 `CONTRACT.md` §1）；
/// 传输层失败用本类自己的常量（[networkFailure] 等）。
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  final String code;
  final String message;
  final int? statusCode;
  final Object? details;

  /// 网络不可达、超时、证书被拒等传输层失败。
  static const String networkFailure = 'NETWORK_FAILURE';

  /// 响应不是预期的 JSON 信封。
  static const String invalidResponse = 'INVALID_RESPONSE';

  /// 后端还没有 B1/B2 的移动端鉴权（探测到 404）。
  static const String backendNotReady = 'BACKEND_NOT_READY';

  /// 本地判定：会话已失效，需要重新登录。
  static const String sessionExpired = 'SESSION_EXPIRED';

  bool get isUnauthorized => statusCode == 401 || code == 'NOT_AUTHENTICATED';

  @override
  String toString() =>
      'ApiException($code${statusCode == null ? '' : ', HTTP $statusCode'}): $message';
}
