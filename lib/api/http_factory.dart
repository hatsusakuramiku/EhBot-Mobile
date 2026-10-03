import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// 按设置构造 HTTP 客户端。
///
/// 默认走系统信任链；只有开启「允许自签证书」时才接管证书校验：填了指纹就
/// 按指纹 pin（SHA-1，忽略大小写与分隔符），没填指纹则接受任意自签证书
/// ——界面已明确告警，这是运营者显式选择。
http.Client createHttpClient({
  required bool allowSelfSigned,
  String? certFingerprint,
}) {
  if (!allowSelfSigned) {
    return http.Client();
  }
  final HttpClient io = HttpClient();
  io.badCertificateCallback = (X509Certificate cert, String host, int port) {
    final String pin = _normalizeFingerprint(certFingerprint);
    if (pin.isEmpty) {
      return true;
    }
    return _normalizeFingerprint(
          cert.sha1.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        ) ==
        pin;
  };
  return IOClient(io);
}

String _normalizeFingerprint(String? value) =>
    (value ?? '').replaceAll(':', '').replaceAll(' ', '').trim().toLowerCase();
