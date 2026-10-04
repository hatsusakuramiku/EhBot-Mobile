# 需求规格：EhBot-Mobile

## 1. 这是什么

EhBot（Telegram 来源的漫画审核与 CBZ 归档服务）的 **Flutter 移动客户端**。
它不是一个新服务，而是运营者在自己手机上使用的控制台前端；所有数据与动作都由
EhBot 后端的 `/api/v1` 提供，客户端不持有数据库、不下载归档、不做业务判定。

## 2. 目标

### 2.1 MVP（本期目标：v0.1.0，基本可用）

装 App → 配服务器 → 密码或 API Key 登录 → 工作台 / 候选 / 活动 / 已下载四块数据 →
对候选通过 / 驳回 → 封面正常 → 进程被杀后重开仍登录 → 断流能自恢复。

### 2.2 明确不做（后续版本）

- 设置页的编辑：来源规则、解析规则、AI 供应商、归档 / 路径、系统设置。
- 批量操作（候选批量、已下载批量）、日志实时流查看。
- 推送通知、主题 / 无障碍精修、iOS 商店签名发布。

### 2.3 权限

**完整权限**：Bearer 凭据与网页管理员会话同权，不设只读 scope。移动端能做后端
`/api/v1` 允许的一切；「MVP 不做某页面」是界面范围，不是权限限制。

## 3. 服务器连接

- 用户可配 `base_url`：scheme + host + port + 可选 path 前缀（对应后端 `APP_ROOT_PATH`）。
- 「测试连接」：`GET /healthz` 判可达 → `GET /api/v1/auth/whoami` 判凭据是否有效。
- TLS：默认使用系统信任；提供「允许自签证书」开关（保存证书指纹做 pin，明确告警）。
- 明文 `http`：Android 需 `network_security_config`，iOS 需 ATS 例外；UI 上标红提示，
  默认引导 HTTPS。

## 4. 登录

两种方式，互不影响（凭据族隔离）：

1. **密码登录**：网页端管理员密码。后端签发 access（默认 12h）+ refresh（默认 30d）；
   access 存内存，refresh 存 `flutter_secure_storage`；401 时自动 refresh 一次。
   初始密码未改时后端拒绝签发，客户端提示先到网页端改密。
2. **API Key**：网页端「设置 › 密码库」生成 `ehk_...`，粘贴进 App，
   存 `flutter_secure_storage`；不过期、不刷新。全局同时只有一条有效 Key，
   网页端刷新后旧 Key 立即失效，各设备需重新粘贴。

## 5. 数据与实时

- 读取：`/api/v1/summary`、`/candidates`、`/candidates/facets`、`/works/{id}`、
  `/queue`、`/history`、`/downloaded`、`/meta`。
- 缩略图：`/api/v1/thumbnails/{hash}`，客户端带鉴权加载（方案 A，见 `CONTRACT.md` §3）。
- 实时：`/api/v1/events`（SSE，带 Authorization 头）；断流按 `meta.polling` 回退轮询。

## 6. 验收

以 `DEVELOPMENT_PLAN.md` §1 的 MVP 验收清单为准；每期在 `progress.md` 留可复现的验证记录。
