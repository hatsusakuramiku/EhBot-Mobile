import 'package:http/http.dart' as http;

import 'transport_guard.dart';
import 'uri_utils.dart';

/// 「测试连接」结果：先判可达，再判后端是否已支持移动端鉴权。
class ServerProbeResult {
  const ServerProbeResult({
    required this.reachable,
    required this.authSupported,
    required this.message,
  });

  final bool reachable;
  final bool authSupported;
  final String message;
}

/// `GET /healthz` 判连通；`GET /api/v1/auth/whoami` 无凭据返回 401 说明
/// 后端已支持 Bearer（404 说明还缺 B1/B2）。
Future<ServerProbeResult> probeServer({
  required http.Client client,
  required Uri baseUri,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final http.Response health;
  try {
    health = await guardTransport(
      () => client.get(resolveUri(baseUri, '/healthz')),
      timeout: timeout,
    );
  } on Object catch (error) {
    return ServerProbeResult(
      reachable: false,
      authSupported: false,
      message: '无法连接服务器：$error',
    );
  }
  if (health.statusCode < 200 || health.statusCode >= 300) {
    return ServerProbeResult(
      reachable: false,
      authSupported: false,
      message: '服务器有响应，但 /healthz 返回 HTTP ${health.statusCode}。',
    );
  }

  final http.Response whoami;
  try {
    whoami = await guardTransport(
      () => client.get(resolveUri(baseUri, '/api/v1/auth/whoami')),
      timeout: timeout,
    );
  } on Object catch (error) {
    return ServerProbeResult(
      reachable: true,
      authSupported: false,
      message: '服务器可达，但探测鉴权失败：$error',
    );
  }
  if (whoami.statusCode == 404) {
    return const ServerProbeResult(
      reachable: true,
      authSupported: false,
      message: '服务器可达，但它还没有移动端鉴权（需要后端 B1/B2）。',
    );
  }
  return const ServerProbeResult(
    reachable: true,
    authSupported: true,
    message: '服务器可达，移动端鉴权已启用。',
  );
}
