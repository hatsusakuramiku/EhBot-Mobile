import 'package:ehbot_mobile/api/token_store.dart';

/// 测试用内存 TokenStore：不触碰 platform channel。
class InMemoryTokenStore implements TokenStore {
  String? refreshToken;
  String? apiKey;
  int clearCount = 0;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeRefreshToken(String token) async => refreshToken = token;

  @override
  Future<String?> readApiKey() async => apiKey;

  @override
  Future<void> writeApiKey(String key) async => apiKey = key;

  @override
  Future<void> clear() async {
    refreshToken = null;
    apiKey = null;
    clearCount += 1;
  }
}
