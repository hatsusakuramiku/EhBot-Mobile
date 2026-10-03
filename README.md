# ehbot-mobile

EhBot 的 Flutter 移动客户端。连接自建的 EhBot 服务，用**密码**或 **API Key** 登录，
浏览工作台、候选、活动队列与已下载内容，并对候选执行通过 / 驳回。

- 服务端是另一个仓库 `EhBot`，本客户端只通过其 `/api/v1` 通信。
- 依赖的后端契约见 [`AgentHelp/CONTRACT.md`](AgentHelp/CONTRACT.md)。
- MVP 验收线与分期见 [`AgentHelp/DEVELOPMENT_PLAN.md`](AgentHelp/DEVELOPMENT_PLAN.md)。
- 环境与开发约定见 [`AgentHelp/AGENTS.md`](AgentHelp/AGENTS.md)；开工先读
  [`AgentHelp/PHASES.md`](AgentHelp/PHASES.md)。

## 前置

- Flutter **3.47.6** stable / Dart 3.13.5（安装路径、基线见 `AgentHelp/AGENTS.md`）。
- Android SDK 或 Xcode 之一（`flutter analyze` / `flutter test` 不需要，`flutter run` 需要）。
- 一个已部署并**已启用移动端鉴权**的 EhBot 服务端（需要后端 B1/B2，见 `CONTRACT.md`）。
  R52（v0.3.0rc2）还不含该鉴权，`POST /api/v1/auth/login` 会是 404。

## 快速开始

    flutter pub get
    flutter run      # 需要 Android SDK 或 Xcode

质量门禁（本地与 CI 同一套，Flutter 锁定 3.47.6）：

    flutter analyze  # 要求零告警
    flutter test     # 当前基线 1 tests / 0 failed

## 登录

1. 服务器页填 `base_url`，例如 `https://ehbot.example.com`；反向代理有前缀时一并带上
   （对应后端 `APP_ROOT_PATH`）。「测试连接」会先探 `/healthz`，再用凭据探
   `GET /api/v1/auth/whoami`。
2. **密码登录**：用网页端管理员密码。全新部署必须先在网页端改掉初始密码，
   否则后端拒绝签发 token。
3. **API Key 登录**：在网页端「设置 › 密码库 › API 密钥（移动端）」生成，粘贴 `ehk_...`。
   全局同时只有一条有效 Key；网页端刷新后旧 Key 立即失效，各设备需重新粘贴。

## 文档

| 文档 | 内容 |
|------|------|
| `AgentHelp/PHASES.md` | **先读**：各期一行摘要 + `progress.md` 指针 |
| `AgentHelp/AGENTS.md` | 环境、架构规则、业务不变量、测试基线、工作约定 |
| `AgentHelp/progress.md` | 分期实施日志（逐条追加） |
| `AgentHelp/MOBILE.md` | 需求规格 |
| `AgentHelp/DEVELOPMENT_PLAN.md` | 分期计划与 MVP 验收线 |
| `AgentHelp/CONTRACT.md` | 依赖的后端 API 契约与最低后端版本 |
| `AgentHelp/MOBILE_CLIENT_PROPOSAL.md` | 已审阅的设计记录（含后端改动） |
