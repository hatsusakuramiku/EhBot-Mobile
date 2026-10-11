# EhBot-Mobile

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
    flutter test     # 当前基线 105 tests / 0 failed

发布（Android）：一次出 4 份 APK，目标平台在文件名里。需要在 `android/app/build.gradle.kts` 里开 `splits.abi` + `universalApk = true`（M6 follow-up）：

```
flutter build apk --release
# 输出：
#   app-arm64-v8a-release.apk     (~18 MB)
#   app-armeabi-v7a-release.apk   (~16 MB)
#   app-x86_64-release.apk        (~20 MB)
#   app-release.apk               (~53 MB, universal)
```

Google Play 分发用 `.aab`：

```
flutter build appbundle --release
# 输出 app-release.aab，Play 商店会按设备 ABI 自动分发拆分包
```

## 使用

登录后是四个页面（底部导航）：

- **工作台**：候选计数、活动概况（下载中 / 打包中）、需干预清单。
- **候选**：tab（全部 / 待审核 / 待补充 / 已通过 / 已驳回 / 失败）+ 搜索 + 加载更多；
  点开是详情（封图、状态、元数据、时间线），底部可**通过 / 驳回**，成功后列表自动刷新。
- **活动**：下载 / 打包队列按后端分组展示 + 已完成历史（本期只读）。
- **已下载**：搜索 + 加载更多；显示状态与打包状态。

- **设置**（AppBar 右上角图标）：只读列出账号、服务器 URL、外部服务连接状态、启动警告与退出登录；详细信息改动在 `MOBILE.md` §2.2 以后的版本提供。
**实时**：客户端优先消费 `/api/v1/events`（SSE，带 `Authorization` 头）；
断流会按 `/api/v1/meta` 的 `polling.interval_ms` 自动回退轮询，并周期性重试恢复。
回退期间顶部会出现「实时连接已断开，已回退轮询」横幅，可手动重试；各页面在每次
实时 tick 到来时自动刷新。

## 作品详情与动作

点开任何页面中的候选/作品行都会打开详情页。详情页含：

- 左侧封面缩略图（如果候选传了 cover hash） + 右侧标题 + 状态/阶段 chip + 作者/分类/语言/标签
- 元数据列表与时间线（M3 原有）
- **上一作品 / 下一作品**按钮：后端返回 `prev_id` / `next_id` 时出现，点击刈换同一页面的作品
- **动作按钮**：通过/驳回总是出现；重获元数据/重新打包/重新转换/切至 EH/切至 Telegram/重排队/需修订/转换/轻度删除/底度删除 只在后端返回 `actions` 中对应名称为 true 时才渲染；删除类需双确认。该列表会随后端升级自动扩展。
- 所有动作调用 `/api/v1/jobs/{id}/{action}`；错误走 `describeError`、成功走 `SnackBar` + 列表自动刷新

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
| `AgentHelp/MOBILE_CLIENT_PROPOSAL.md` | 已审阅的整体设计记录（含后端改动） |
| `AgentHelp/M1_AUTH_PROPOSAL.md` 等 | M1–M4 各期的实现设计记录（先方案后开工） |
| `CHANGELOG.md` | 版本变更与已知限制 |
