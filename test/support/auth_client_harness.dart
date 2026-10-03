import 'package:ehbot_mobile/api/api_exception.dart';
import 'package:ehbot_mobile/api/auth_client.dart';
import 'package:ehbot_mobile/api/auth_session.dart';
import 'package:http/http.dart' as http;

/// 密码族会话的 `AuthClient`，refresh 走真实 HTTP（便于测「刷新后重试」）。
class AuthClientHarness {
  AuthClientHarness(http.Client inner)
    : session = AuthSession.password(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      ) {
    client = AuthClient(
      inner: inner,
      baseUri: Uri.parse('https://ehbot.example.com'),
      session: session,
      onSessionExpired: () => expired = true,
    )..refreshHook = _refresh;
  }

  final AuthSession session;
  late final AuthClient client;
  bool expired = false;

  Future<void> _refresh(AuthSession session) async {
    final http.Response response = await client.postJson(
      '/api/v1/auth/refresh',
      body: <String, Object?>{'refresh_token': session.refreshToken},
    );
    if (response.statusCode != 200) {
      throw const ApiException(code: 'AUTH_TOKEN_REVOKED', message: '刷新被拒');
    }
    session.updateTokens(access: 'access-2', refresh: 'refresh-2');
  }
}
