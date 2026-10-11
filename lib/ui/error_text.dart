import '../api/api_exception.dart';
import '../api/auth_session.dart';

const String _invalidApiKey = 'API Key 无效或已在网页端刷新，请重新粘贴。';

/// 该模块的后端端点还没上线（404）。M8 期间用来把页面切成「后端未就绪」态。
bool isEndpointMissing(Object error) =>
    error is ApiException && error.statusCode == 404;

/// 「后端未就绪」的说明文案。
const String kEndpointMissingHint =
    '后端还没有这个端点（EhBot 侧尚未实现）。当前调用会返回 404。';

/// 「后端 `/api/v1` 还没有这个动作」的说明。
///
/// EhBot R70–R73 把作品动作面补齐（要求修订 / 打包 / 重获元数据 / 按来源拉取 /
/// 已下载改名），所以详情页与已下载页已经没有这种按钮；这条留给后续新增的、
/// 后端尚未实现的动作，以及设置六区（只读）的说明。
const String kActionEndpointMissingHint =
    '后端 /api/v1 还没有这个动作（目前只有网页层有）。需要 EhBot 再补一期端点。';

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
    return '接口不存在（HTTP 404）：这台服务器上还没有这个端点，'
        '可能需要升级 EhBot 后端。';
  }
  if (error.statusCode == 429) {
    return '尝试次数过多，请稍后再试。';
  }
  if (error.statusCode == 401) {
    return kind == CredentialKind.apiKey ? _invalidApiKey : '凭据无效，请重新登录。';
  }
  return error.message;
}
