# 方案：M1 —— 服务器配置 + 密码 / API Key 双登录 + 会话保持

> 状态：运营者已批准「一直做到 M4」（2026-10-03），M1–M4 的**范围**见
> `MOBILE_CLIENT_PROPOSAL.md` §7.2 / `DEVELOPMENT_PLAN.md` §2，本文件是该期的实现设计记录。
> 完成后按 `AGENTS.md` 更新 `README.md` / `progress.md` / `PHASES.md` / `AGENTS.md`。

## 1. 需求

装 App 能填服务器地址并探测连通；用**密码**或 **API Key** 登录；会话在杀进程后仍在；
access 过期能自动刷新一次；API Key 失效给出明确提示而不是乱刷新。

## 2. 现状

M0 只有骨架（`lib/api|state|ui|media` 空占位）。后端 B1/B2 未部署，
`POST /api/v1/auth/login` 现在会 404，所以客户端必须能优雅降级提示。

## 3. 方案

- **分层**：`lib/api`（HTTP、鉴权、模型、异常）、`lib/state`（设置与会话状态）、
  `lib/ui`（页面）。HTTP 用 `package:http`（可注入 `MockClient` 测试）。
- **设置**：`AppSettings`（baseUrl / 允许自签 / 允许明文 / 证书指纹 / 超时）存
  `shared_preferences`（非机密）；`baseUrl` 必须带 `http(s)://` 且有 host，
  反代前缀（`APP_ROOT_PATH`）原样保留。
- **凭据存储**：`TokenStore` 抽象；生产实现用 `flutter_secure_storage`
  （refresh token / API Key）；**access 只放内存**；测试用内存实现。
- **401 分流**（照 `CONTRACT.md` §4）：密码族 → 用 refresh 换一次并重放原请求，
  刷新失败 → 清凭据回登录页；API Key 族 → 不刷新，提示「密钥无效或已在网页端刷新」。
- **就绪探测**：`GET /healthz` 判连通；`GET /api/v1/auth/whoami` 无凭据返回 401
  说明后端已支持移动端鉴权，404 说明还缺 B1/B2，界面直接给升级提示。
- **TLS / 明文**：默认系统信任；「允许自签」开启后自签放行，填了指纹就按指纹 pin；
  明文 `http` 标红告警，需显式勾选「允许明文」。Dart 走自身 socket，
  通常不受 Android cleartext / iOS ATS 限制——**真机若被拦再补 manifest/Info.plist 例外**。

## 4. 备选（否决）

- 用 `dio` + 拦截器：功能等价但多一层封装，MVP 用 `http` 足够。
- 凭据放 `shared_preferences`：明文落盘，违反架构不变量，否决。
- 自签证书「全部信任」不给指纹 pin：勾选自签即提示风险，另给可选指纹 pin。

## 5. 界面影响

新增三页：**服务器配置**（地址、TLS/明文开关、测试连接、保存）、
**登录**（密码 / API Key 两个 tab，含错误提示）、**登录后占位首页**（显示 whoami +
退出登录；四块数据页在 M3 落地）。首次启动进服务器配置，配好后进登录。

## 6. 契约影响

不新增/不改后端契约；完全按 `CONTRACT.md` §2 的四个鉴权端点实现。
若后端 B1/B2 尚未部署，客户端给「后端未就绪」提示（`POST /api/v1/auth/login` 404）。

## 7. 测试计划

- 单元：错误信封解析、`AuthApi`（登录 / 刷新 / whoami / 路径前缀）、
  `AuthClient`（带 Bearer、401→refresh 一次→重放、刷新失败回调、API Key 不刷新、网络错误归一）。
- 状态：设置存取往返、`AppState` 的 bootstrap / 双登录 / 退出 / 存储边界（只存 refresh / Key）。
- 探测：healthz 失败、whoami 401（就绪）、whoami 404（后端未就绪）。
- Widget：登录页两个 tab 与错误提示、服务器页明文告警与非法地址提示。
- 基线：`flutter test` 用例数只增不减；`flutter analyze` 零告警。

## 8. 文档同步

`README.md`（登录 / 服务器章节改为实际行为）、`progress.md`（M1 条目）、
`PHASES.md`（M1 状态与基线）、`AgentHelp/AGENTS.md`（测试基线数字）；
无契约变化，`CONTRACT.md` 不动。
