# 实施日志

> 新条目追加在**文件末尾**（与 EhBot 相反，本仓库从零开始，顺序阅读即可）。
> 每条对照上一条保持相同格式；基线数字每期更新。

## 条目格式

```
## M<n> · <日期> · <一句话主题>

- 版本：
- 测试基线：<N tests / 0 failed>（`flutter analyze` 零告警）
- 后端依赖：B1 / B2 是否已部署
- 改动：<主要文件与行为>
- 验证：<跑了什么命令，结果如何>
- 文档：<README/AgentHelp 改了哪些；无变更则写明>
```

---

## M0 · 2026-10-03 · Flutter 工程骨架 + CI（analyze / test 首基线）

- 版本：Flutter 3.47.6 stable（Dart 3.13.5、DevTools 2.60.0，framework revision `5fc346839b`）
- 测试基线：`1 tests / 0 failed`（`flutter analyze` 零告警）
- 后端依赖：B1 / B2 均未部署；M0 不依赖后端（`/api/v1/auth/login` 仍会是 404）
- 改动：`flutter create --empty`（包名 `ehbot_mobile`、org `com.ehbot`、平台 android/ios）；
  `lib/main.dart` 引导 + `lib/ui/app.dart` 骨架页；`lib/api`、`lib/state`、`lib/media`
  三层占位落位（M1 / M2 填充）；`test/app_test.dart` 首条 widget 测试；
  `.github/workflows/ci.yml`（Flutter 3.47.6，`flutter analyze` + `flutter test`）。
- 验证：`flutter analyze` → No issues found!；`flutter test` → All tests passed!（1 条）；
  `dart format lib test` → 0 changed。
- 文档：`README.md`（前置 / 快速开始改为真实命令与基线）、`AgentHelp/AGENTS.md`
  （环境与测试基线）、`AgentHelp/PHASES.md`（M0 完成 + 基线链）、`AgentHelp/task_plan.md`。

## M1 · 2026-10-03 · 服务器配置 + 密码 / API Key 双登录 + 会话保持

- 版本：Flutter 3.47.6 stable（Dart 3.13.5）
- 测试基线：`45 tests / 0 failed`（`flutter analyze` 零告警）
- 后端依赖：B1 / B2 未部署；探测到 404 时提示「后端还没有移动端鉴权」
- 改动：`lib/api`（`api_exception` / `json_io` / `uri_utils` / `models` / `token_store` /
  `auth_session` / `auth_api` / `auth_client` / `probe` / `transport_guard` / `http_factory`）；
  `lib/state`（`settings` 存 shared_preferences、`app_state` 管会话与 401 回调）；
  `lib/ui`（服务器配置页、双 tab 登录页、登录后外壳）；依赖 `http` /
  `flutter_secure_storage` / `shared_preferences`。
- 验证：`flutter analyze` → No issues found!；`flutter test` → 45 tests 全过；
  `dart format` 无改动。
- 文档：新增 `AgentHelp/M1_AUTH_PROPOSAL.md`；`progress.md` / `PHASES.md` / `AGENTS.md` /
  `README.md` 同步。`CONTRACT.md` 无变化。

## M2 · 2026-10-03 · 缩略图带鉴权加载器 + 磁盘缓存（方案 A）

- 版本：Flutter 3.47.6 stable
- 测试基线：`56 tests / 0 failed`（`flutter analyze` 零告警）
- 后端依赖：同上（缩略图端点本就存在，鉴权复用 Bearer 通道）
- 改动：`lib/media/thumbnail_cache.dart`（`<hash>.thumb` + `<hash>.etag`，
  `DefaultThumbnailCache` 延迟解析缓存目录）、`lib/media/thumbnail_loader.dart`
  （`If-None-Match`、`X-Thumbnail-State: failed` → 抛错、内存 + 磁盘两级缓存）、
  `lib/ui/widgets/thumbnail_image.dart`（失败 / 加载中都渲染本地占位，不解码 SVG）；
  依赖 `path_provider`。
- 验证：`flutter analyze` 零告警；`flutter test` → 56 tests 全过。
- 文档：新增 `AgentHelp/M2_THUMBNAIL_PROPOSAL.md`（含「不实现自定义 ImageProvider」的取舍）；
  `progress.md` / `PHASES.md` / `AGENTS.md` / `README.md` 同步。

## M3 · 2026-10-03 · 工作台 / 候选 / 审核 / 活动 / 已下载

- 版本：Flutter 3.47.6 stable
- 测试基线：`76 tests / 0 failed`（`flutter analyze` 零告警）
- 后端依赖：B1 / B2 仍未部署；响应字段**对照 EhBot 源码**核对，未凭空假设
- 改动：`lib/api/models.dart`（容错解析的 `StatusView` / `Candidate` / `Summary` /
  `JobSummary` / `QueueSnapshot` / `DownloadedWork` / `WorkDetail` 等）、
  `lib/api/ehbot_api.dart`（`/summary` `/candidates` `/works/{id}` `/candidates/batch`
  `/queue` `/history` `/downloaded` `/meta`）、`lib/state/app_state.dart` 暴露 `api` 与
  `thumbnails`；`lib/ui` 五个页面 + `ErrorView` / `AsyncView` / `StatusChip` 与四 tab 外壳。
- 验证：`flutter analyze` 零告警；`flutter test` → 76 tests 全过。
- 文档：新增 `AgentHelp/M3_PAGES_PROPOSAL.md`；`CONTRACT.md` 补 §5.1「已核对的响应形状」；
  `progress.md` / `PHASES.md` / `AGENTS.md` / `README.md` 同步。

## M4 · 2026-10-03 · SSE + 轮询回退 + 离线态 + v0.1.0 打磨

- 版本：Flutter 3.47.6 stable
- 测试基线：`90 tests / 0 failed`（`flutter analyze` 零告警）
- 后端依赖：B1 / B2 仍未部署；`/events` 与 `/meta` 的字段按 EhBot 源码核对
- 改动：`lib/api/events.dart`（`parseSse` 行缓冲解析、`SseEventSource`）、
  `AuthClient.stream()`（长连接鉴权 + 401 刷新一次）、`lib/state/live_monitor.dart`
  （`connecting/streaming/polling`、按 `/meta` 间隔轮询、定期重连、`ticks` 广播）、
  四个页面订阅 tick 自动刷新、`LiveStatusBanner` 断流横幅（可手动重试）；
  新增 `CHANGELOG.md`（v0.1.0）。
- 验证：`flutter analyze` 零告警；`flutter test` → 90 tests 全过（含 SSE 解析、
  轮询回退、重连恢复、`AuthClient.stream` 401 刷新）。
- 文档：新增 `AgentHelp/M4_REALTIME_PROPOSAL.md`；`README.md`（使用 / 实时章节）、
  `CHANGELOG.md`、`progress.md` / `PHASES.md` / `AGENTS.md` 同步。
- 遗留：活动页只读；无真机 / 真实后端端到端验证（待运营者用自己的部署试跑）。

## M5 · 2026-10-04 · 仓库改名 `ehbot-mobile` → `EhBot-Mobile`

- 版本：仓库改名；App 版本仍为 v0.1.0，发布标识不变
- 测试基线：`90 tests / 0 failed`（`flutter analyze` 零告警）
- 后端依赖：B1 / B2 未部署；本次不改后端契约
- 改动：本地仓库目录改为 `/home/coder/workspace/EhBot-Mobile`；当前文档统一使用
  `EhBot-Mobile`；历史方案保留原文并增加重命名说明。Dart 包名 `ehbot_mobile`、
  Android applicationId 与 iOS bundle ID 均不变。
- 验证：`flutter analyze` 零告警；`flutter test` → 90 tests 全过；
  `git grep` 确认旧仓库名只保留在历史方案说明中。
- 文档：新增 `AgentHelp/REPOSITORY_RENAME_PROPOSAL.md`；`README.md`、根 `AGENTS.md`、
  `AgentHelp/AGENTS.md`、`AgentHelp/MOBILE.md`、`AgentHelp/PHASES.md` 同步。
- 远端：仓库未配置 Git remote，暂无可用推送凭据；远端创建 / 配置后待推送。
