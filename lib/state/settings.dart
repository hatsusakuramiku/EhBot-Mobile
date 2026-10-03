import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 服务器连接设置（非机密，存 shared_preferences）。
class AppSettings {
  const AppSettings({
    this.baseUrl = '',
    this.allowSelfSigned = false,
    this.allowCleartext = false,
    this.certFingerprint,
    this.timeout = const Duration(seconds: 15),
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    baseUrl: json['base_url'] as String? ?? '',
    allowSelfSigned: json['allow_self_signed'] as bool? ?? false,
    allowCleartext: json['allow_cleartext'] as bool? ?? false,
    certFingerprint: json['cert_fingerprint'] as String?,
    timeout: Duration(
      seconds: (json['timeout_seconds'] as num?)?.toInt() ?? 15,
    ),
  );

  final String baseUrl;
  final bool allowSelfSigned;
  final bool allowCleartext;
  final String? certFingerprint;
  final Duration timeout;

  Uri? get baseUri => parseBaseUrl(baseUrl);
  bool get isConfigured => baseUri != null;
  bool get isCleartext => baseUri?.scheme == 'http';

  AppSettings copyWith({
    String? baseUrl,
    bool? allowSelfSigned,
    bool? allowCleartext,
    String? certFingerprint,
    Duration? timeout,
  }) => AppSettings(
    baseUrl: baseUrl ?? this.baseUrl,
    allowSelfSigned: allowSelfSigned ?? this.allowSelfSigned,
    allowCleartext: allowCleartext ?? this.allowCleartext,
    certFingerprint: certFingerprint ?? this.certFingerprint,
    timeout: timeout ?? this.timeout,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'base_url': baseUrl,
    'allow_self_signed': allowSelfSigned,
    'allow_cleartext': allowCleartext,
    if (certFingerprint != null && certFingerprint!.isNotEmpty)
      'cert_fingerprint': certFingerprint,
    'timeout_seconds': timeout.inSeconds,
  };
}

/// 校验用户输入的 base URL；合法返回 `null`，否则返回给用户看的提示。
String? validateBaseUrl(String raw) {
  final String text = raw.trim();
  if (text.isEmpty) {
    return '请填写服务器地址。';
  }
  final Uri? uri = Uri.tryParse(text);
  if (uri == null) {
    return '地址格式不正确。';
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return '地址要以 http:// 或 https:// 开头。';
  }
  if (uri.host.isEmpty) {
    return '地址缺少主机名。';
  }
  if (uri.hasQuery || uri.hasFragment) {
    return '地址不要带查询串或片段。';
  }
  return null;
}

/// 合法时返回规范化后的 URI（去掉裸的 `/` 路径），否则返回 `null`。
Uri? parseBaseUrl(String raw) {
  if (validateBaseUrl(raw) != null) {
    return null;
  }
  final Uri uri = Uri.parse(raw.trim());
  return uri.path == '/' ? uri.replace(path: '') : uri;
}

/// 设置的持久化：`shared_preferences` 里存一段 JSON。
class SettingsStore {
  static const String storageKey = 'ehbot.settings';

  Future<AppSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return const AppSettings();
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AppSettings.fromJson(Map<String, dynamic>.from(decoded));
      }
    } on FormatException {
      // 存储损坏时回落到默认值，下次保存会覆盖。
    }
    return const AppSettings();
  }

  Future<void> save(AppSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(settings.toJson()));
  }
}
