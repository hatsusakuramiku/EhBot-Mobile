import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 机密凭据存储。**refresh token 与 API Key 只能落在这里**；
/// access token 不入库、只放内存（见 `AgentHelp/AGENTS.md` 架构规则）。
abstract interface class TokenStore {
  Future<String?> readRefreshToken();
  Future<void> writeRefreshToken(String token);
  Future<String?> readApiKey();
  Future<void> writeApiKey(String key);
  Future<void> clear();
}

/// 生产实现：iOS Keychain / Android Keystore。
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _refreshTokenKey = 'ehbot.refresh_token';
  static const String _apiKeyKey = 'ehbot.api_key';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  @override
  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  @override
  Future<String?> readApiKey() => _storage.read(key: _apiKeyKey);

  @override
  Future<void> writeApiKey(String key) =>
      _storage.write(key: _apiKeyKey, value: key);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _apiKeyKey);
  }
}
