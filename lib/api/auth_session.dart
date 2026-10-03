/// 凭据族：密码登录（access + refresh）与 API Key 互不影响（`CONTRACT.md` §2.1）。
enum CredentialKind { password, apiKey }

/// 内存中的会话状态；access token 只在这里，不落盘。
class AuthSession {
  AuthSession.password({this.accessToken, this.refreshToken})
    : kind = CredentialKind.password,
      apiKey = null;

  AuthSession.apiKey(String key)
    : kind = CredentialKind.apiKey,
      accessToken = null,
      refreshToken = null,
      apiKey = key;

  final CredentialKind kind;
  String? accessToken;
  String? refreshToken;
  String? apiKey;

  /// 放进 `Authorization` 头的凭据值（不含 `Bearer ` 前缀）。
  String? get bearer => switch (kind) {
    CredentialKind.password => accessToken,
    CredentialKind.apiKey => apiKey,
  };

  void updateTokens({required String access, required String refresh}) {
    accessToken = access;
    refreshToken = refresh;
  }
}
