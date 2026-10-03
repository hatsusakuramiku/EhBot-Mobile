import '../api/api_exception.dart';
import '../api/auth_session.dart';

const String _invalidApiKey = 'API Key 无效或已在网页端刷新，请重新粘贴。';

/// 把异常翻成给运营者看的中文提示（不包含 token / 密钥）。
String describeError(Object error, {CredentialKind? kind}) {
  if (error is! ApiException) {
    return '出错了：$error';
  }
  switch (error.code) {
    case 'AUTH_INVALID_CREDENTIALS':
      return '密码不正确，请重试。';
    case 'PASSWORD_CHANGE_REQUIRED':
      return '初始密码未修改：请先在网页端改掉初始密码，再回来登录。';
    case 'AUTH_TOKEN_EXPIRED':
    case 'AUTH_TOKEN_REVOKED':
      return '会话已过期，请重新登录。';
    case 'NOT_AUTHENTICATED':
      return kind == CredentialKind.apiKey ? _invalidApiKey : '凭据无效，请重新登录。';
    case ApiException.networkFailure:
      return error.message;
    case ApiException.invalidResponse:
      return '服务器返回了无法解析的响应，请确认地址指向 EhBot 后端。';
    case ApiException.sessionExpired:
      return '会话已过期，请重新登录。';
  }
  if (error.statusCode == 404) {
    return '接口不存在（HTTP 404）：服务器可能还没部署移动端鉴权（B1/B2）。';
  }
  if (error.statusCode == 429) {
    return '尝试次数过多，请稍后再试。';
  }
  if (error.statusCode == 401) {
    return kind == CredentialKind.apiKey ? _invalidApiKey : '凭据无效，请重新登录。';
  }
  return error.message;
}
