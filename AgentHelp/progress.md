# 实施日志

> 新条目附加在**文件末尾**（与 EhBot 相反，本仓库从零开始，顺序阅读即可）。
> 每条对照上一条保持相同格式；基线数字每期更新。

## 条目格式

```
## M<n> · <日期> · <一句话主题>

- 版本：
- 测试基线：<N tests / 0 failed>（`flutter analyze` 零告警）
- 后端依赖：B1 / B2 是否已部署
- 改动：
- 验证：
- 文档：
```

---

## M0 · 2026-10-03 · Flutter 工程脚手架 + CI（analyze / test 首基线）

- 版本：Flutter 3.47.6 stable、Dart 3.13.5、DevTools 2.60.0、framework revision `5fc346839b`
- 测试基线：`1 tests / 0 failed`（`flutter analyze` 零告警）
- 后端依赖：B1 / B2 均未部署；M0 不依赖后端（`/api/v1/auth/login` 仍是 404）
- 改动：`flutter create --empty`（包名 `ehbot_mobile`、org `com.ehbot`、平台 android/ios）；`lib/main.dart` 引入 + `lib/ui/app.dart` 脚手架页；`lib/api`、`lib/state`、`lib/media` 三层占位桩位（M1 / M2 填充）；`test/app_test.dart` 首条 widget 测试；`.github/workflows/ci.yml`（锁 Flutter 3.47.6、`flutter analyze` + `flutter test`）
- 验证：`flutter analyze` → No issues found!；`flutter test` → All tests passed!（1 条）；`dart format lib test` → 0 changed
- 文档：`README.md`（前置 / 快速开始改名为切实命令与基线）、`AgentHelp/AGENTS.md`（环境与测试基线）、`AgentHelp/PHASES.md`（M0 完成 + 基线链）、`AgentHelp/task_plan.md`

## M1 · 2026-10-03 · 服务器配置页 + 密码 / API Key 双登录 + 会话保持

- 版本：Flutter 3.47.6 stable、Dart 3.13.5
- 测试基线：`45 tests / 0 failed`（`flutter analyze` 零告警）
- 后端依赖：B1 / B2 仍未部署；`/api/v1/auth/login` 必 404，客户端应给出明确提示
- 改动：`lib/api`（`api_exception` / `json_io` / `uri_utils` / `models` / `token_store` / `auth_session` / `auth_api` / `auth_client` / `probe` / `transport_guard` / `http_factory`）；`lib/state`（`settings` 用 shared_preferences、`app_state` 管会话与 401 回调）；`lib/ui`（服务器配置页、双 tab 登录页、登录后外壳）；依赖 `http` / `flutter_secure_storage` / `shared_preferences`
- 验证：`flutter analyze` → No issues found!；`flutter test` → 45 tests 全过；`dart format` 无改动
- 文档：新增 `AgentHelp/M1_AUTH_PROPOSAL.md`；`progress.md` / `PHASES.md` / `AGENTS.md` / `README.md` 同步；`CONTRACT.md` 无变化

## M2 · 2026-10-03 · 缩略图带鉴权加载器 + 磁盘缓存（方案 A）

- 版本：Flutter 3.47.6 stable
- 测试基线：`56 tests / 0 failed`（`flutter analyze` 零告警）
- 后端依赖：同上（缩略图端点就绪，鉴权复用 Bearer 通道）
- 改动：`lib/media/thumbnail_cache.dart`（`<hash>.thumb` + `<hash>.etag`，`DefaultThumbnailCache` 延迟解析缓存目录）；`lib/media/thumbnail_loader.dart`（`If-None-Match`、`X-Thumbnail-State: failed` → 报错的本地占位组件，**不**解码 SVG）；`lib/ui/widgets/thumbnail_image.dart`（失败 / 加载中都能渲染本地占位）；依赖 `path_provider`
- 验证：`flutter analyze` 零告警；`flutter test` → 56 tests 全过；`progress.md` / `PHASES.md` / `AGENTS.md` / `README.md` 同步
- 文档：新增 `AgentHelp/M2_THUMBNAIL_PROPOSAL.md`

## M3 · 2026-10-03 · 工作台 / 候选列表与详情 / 通过驳回 / 活动队列 / 已下载列表

- 版本：Flutter 3.47.6 stable
- 测试基线：`76 tests / 0 failed`（`flutter analyze` 零告警）
- 后端依赖：B1 / B2 仍未部署；响应字段按 EhBot 源码校对，未有空设置
- 改动：`lib/api/models.dart`（容错解析的 `StatusView` / `Candidate` / `Summary` / `JobSummary` / `QueueSnapshot` / `DownloadedWork` / `WorkDetail` 等）；`lib/api/ehbot_api.dart`（概要 / 候选 / 详情 / 队列 / 历史 / 已下载 + 批量端点）；`lib/ui/{dashboard,candidates,candidate_detail,activity,downloaded}_page.dart` + `home_shell.dart`；保持详情页"通过 / 驳回"两个动作
- 验证：`flutter analyze` 零告警；`flutter test` → 76 tests 全过（详情页按钮 widget test、`candidate_summary` 解析容错）
- 文档：新增 `AgentHelp/M3_PAGES_PROPOSAL.md`；`progress.md` / `PHASES.md` / `AGENTS.md` / `README.md` 同步；`CONTRACT.md` §5.1 增 `/candidates` / `/works/{id}` / `/queue` 等响应形状注释

## M4 · 2026-10-03 · SSE + 轮询回退 + 离线 / 错误态 + v0.1.0 打磨

- 版本：Flutter 3.47.6 stable
- 测试基线：`90 tests / 0 failed`（`flutter analyze` 零告警）
- 后端依赖：B1 / B2 仍未部署；`/events` 与 `/meta` 字段按 EhBot 源码校对
- 改动：`lib/api/events.dart`（`parseSse` 行缓冲解析、`SseEventSource`）；`AuthClient.stream()`（长连接鉴权 + 401 刷新一次）；`lib/state/live_monitor.dart`（`connecting / streaming / polling`、按 `/meta` 间隔轮询、定重连、`ticks` 广播）；四个页面都订阅 tick 自动刷新；`LiveStatusBanner` 端流横幅（可手动重试）；新增 `CHANGELOG.md`（v0.1.0）
- 验证：`flutter analyze` 零告警；`flutter test` → 90 tests 全过（SSE 解析、轮询回退、重连恢复、`AuthClient.stream` 401 刷新）；`progress.md` / `PHASES.md` / `AGENTS.md` 同步；`README.md`（使用 / 实时章节）
- 文档：新增 `AgentHelp/M4_REALTIME_PROPOSAL.md`
- 留白：活动页只读；无真机 / 真实后端端到端（端到端等运营者用自己的部署）

## M5 · 2026-10-04 · 仓库改名 `ehbot-mobile` → `EhBot-Mobile`

- 版本：仓库改名；App 版本仍 v0.1.0，发布标识不变
- 测试基线：`90 tests / 0 failed`（`flutter analyze` 零告警）
- 后端依赖：B1 / B2 仍未部署；本期不动后端协议
- 改动：本地仓库目录改为 `/home/coder/workspace/EhBot-Mobile`；文档统一使用 `EhBot-Mobile`；包名 `ehbot_mobile`、Android `applicationId` / iOS bundle ID 保持
- 验证：`flutter analyze` 零告警；`flutter test` → 90 tests 全过；`git grep` 确认旧仓库名仅保留在历史方案
- 文档：新增 `AgentHelp/REPOSITORY_RENAME_PROPOSAL.md`；`README.md`、根 `AGENTS.md`、`AgentHelp/AGENTS.md`、`AgentHelp/MOBILE.md`、`AgentHelp/PHASES.md` 同步
- 远端：仓库未配置 Git remote；远端仓库创建或配置后仍待推送

## M6 · 2026-10-08 · 全页行可点 + 设置页只读 + 作品详情按钮动态渲染

- 版本：Flutter 3.47.6 stable
- 测试基线：`105 tests / 0 failed`（`flutter analyze` 无告警）
- 后端依赖：B1 / B2 仍未部署；`actions` / `prev_id` / `next_id` / `cover` / `artist` / `category` / `language` / `tags` 字段需后端同步补齐
- 改动：
  - `lib/api/models.dart`：`WorkDetail` 新增 `cover` / `tags` / `artist` / `category` / `language` / `actions` / `prevId` / `nextId`；`Summary.connections` + `ConnectionInfo` + `asStringOrNull`
  - `lib/api/ehbot_api.dart`：新增 `EhBotApi.jobAction({id, action})`（`POST /api/v1/jobs/{id}/{action}`）
  - `lib/ui/dashboard_page.dart`：候选计数 chip 改为 `ActionChip`，点击切到候选页 + tab；需查核 `onTap` 推进 `CandidateDetailPage`
  - `lib/ui/candidates_page.dart`：行 `onTap` 推进详情；读取外部 `ValueNotifier<String>? candidatesTab`，与工作台 chip 同步
  - `lib/ui/activity_page.dart` / `lib/ui/downloaded_page.dart`：行 `onTap` 推进 `CandidateDetailPage`（用 stub `Candidate`）
  - `lib/ui/candidate_detail_page.dart`：重写（按 M6 §3.3）：封面 + artist/category/language/tags chip + prev/next 导航 + 按 `actions` 动态渲染重打/重转/切源/重排/删除/底度删除/切换/需修订按钮；删除双确认；缺字段不显示而不是不显示
  - `lib/ui/settings_page.dart`：新增账户 / 服务器 / 外部服务 / 启动告警 / 会话五个分区；退出登录从 AppBar 移到页面底部
  - `lib/ui/home_shell.dart`：AppBar 新增设置图标；与候选页共享 `ValueNotifier<String> _candidatesTab`；向子页传 `thumbnails`
- 验证：`flutter analyze` 无告警；`flutter test` → 105 条全过（新增 15 条）
- 文档：新增 `AgentHelp/M6_UX_FIXES_PROPOSAL.md`；`AgentHelp/PHASES.md` / `AgentHelp/AGENTS.md` / `AgentHelp/CONTRACT.md` / `README.md` 同步

## M7-proposal · 2026-10-11 · UI 重构提案落稿（v1）

- 文档：`AgentHelp/M7_UI_REDESIGN_PROPOSAL.md` 新增；**未改代码、未改 API、未改基线**。
- 目标：脱离 WEBUI 表单布局思路，按 Material 3 大标题 + 底部 sheet + `IndexedStack` 四 tab
  的"内容流 App"原形重建组件库 + 7 页骨架，并预埋多服务器数据层。
- 范围：仅 UI + 状态机；**业务功能复刻走 M8**，本提案不替。
- 状态：**草稿，待运营者按 `AGENTS.md` "先写方案，运营者审阅，再动手" 约定放行**。
- 验证：本期末跑 `flutter analyze` / `flutter test`（只动文档）。

## M7-proposal · 2026-10-11 · 按 `flutter-ui-ux` skill 重写（v2，最终稿）

- 文档：`AgentHelp/M7_UI_REDESIGN_PROPOSAL.md` **就地重写**；M8 提案未动。
- 触发：运营者在 `.agents/skills` 安装了 Flutter UI/UX skill 并要求按 skill 重写 M7，本 agent
  把 skill 同步到全局 `C:\Users\79240\.codex\skills\flutter-ui-ux`（含 `assets/app-template.md`、
  `references/{widget-patterns,theme-templates,animation-patterns,performance-optimization}.md`），
  再按 skill 的 **5-Phase 流程**（Analyze → Architecture → Implement → Animations → Optimize）
  重写整份提案。
- 变化：M7 文件 13.8 KB → 24.2 KB；新增 §1.1 现有结构盘点、§3.3 widget 签名约定、
  §4.2 `EhSpacing`/`EhRadius`/`EhAnim` token 字面量、§4.4 "反硬编码 vs 正路"代码对照、
  §5.7 登录页 `LoadingButton`、§6 Phase 4 动效时长表（按钮 100ms / sheet 250ms / Hero 300ms
  / 数字滚动 350ms 等）、§7.2 可达性 *Required* 段（Semantics / 4.5:1 对比度 / 48dp 触达
  / `materialTapTargetSize.padded`）、§7.3 三断点 `LayoutBuilder` 示例、`§8 M7-A..D 四个 sub-PR`
  切分、§11 测试用例具体到 `+44 cases`。
- 状态：**草稿 v2，待运营者按 `AGENTS.md` 约定放行**。
- 验证：本期末跑 `flutter analyze` / `flutter test`（仍只动文档；M7-A..D 落地后才走基线）。

## M8-proposal · 2026-10-11 · WEBUI 功能全复刻提案落稿

- 文档：`AgentHelp/M8_FEATURE_REPLICATION_PROPOSAL.md` 新增；**未改代码、未改 API、未改基线**。
- 目标：把 WEBUI 19 块页面（含 settings 8 区）一一对应到 App，按 M8-A..F 六个子阶段分批。
- 后端依赖：依赖 `EhBot` 仓库的 `B-M8` PR 提交 `dedup` / `logs` / `settings` 等约 30 个新端点；
  本仓库**不**等这些端点到位，按"端点 404 时降级显示"分两态走防御。
- 范围：本提案覆盖 M8-A（多服务器）→ M8-F（多选 + 滑动手势），每期单独 sub-proposal。
- 状态：**草稿，待运营者按 `AGENTS.md` 约定放行**。
- 验证：本期末跑 `flutter analyze` / `flutter test`（只动文档）。

## 同步项

- `AgentHelp/PHASES.md`：M7 / M8 两行新增（待审阅态）；新增 `B-M8` 一行（后端依赖）。
- `AgentHelp/progress.md`：本条目（追加 M7 v2 重写记录，M8 不变；M0–M6 历史已回补）。
- `AgentHelp/AGENTS.md`：本期无变更（基线仍是 `M6 = 105 tests / 0 failed`；M7 / M8 落地后才动）。
- `README.md`：本期无变更。
- `CHANGELOG.md`：本期无变更（要等 M7 实现合入再升 v0.2.0）。
- 全局 skill 同步：`C:\Users\79240\.codex\skills\flutter-ui-ux\` 5 个文件齐了。

## M7-A · 2026-10-11 · 主题 + 设计 token + 13 个新组件（基线 105 → 132）

- 版本：Flutter 3.47.6 stable；App 版本仍 v0.1.0（M7 全部完成后升 v0.2.0）。
- 测试基线：`132 tests / 0 failed`（`flutter analyze` 零告警）。
- 后端依赖：不变（本子期不动 API）。
- 改动：
  - `lib/ui/theme.dart`（新增）：`EhSpacing` / `EhRadius` / `EhAnim` / `EhBreakpoints`
    四组设计 token；`AppTheme.light()`/`dark()`（M3 + seed `0xFFE91E63`，
    cache `cardTheme` / `filledButtonTheme` / `outlinedButtonTheme` / `chipTheme` /
    `appBarTheme` / `bottomSheetTheme` / `dividerTheme`）；`AppTheme.toneColor` /
    `onToneColor` 把后端 `StatusView.tone` 投影到 M3 语义色。
  - `lib/ui/widgets/` 新增 13 件：`eh_card` / `tone_chip` / `cover_thumb` / `tag_chip` /
    `empty_state` / `section_header` / `menu_fab` / `bottom_sheet` / `search_bar` /
    `large_title_app_bar` / `metric_strip` / `nav_bar` / `gap`。
  - `lib/ui/app.dart`：`MaterialApp` 接 `AppTheme.light()`/`dark()` + `ThemeMode.system`。
  - `test/widgets/` 新增 11 个测试文件（组件渲染 + 交互 + tone 5 色 + 主题/ token 断言）。
- 验证：`flutter analyze` 零告警；`flutter test` → 132 / 0 failed（M6 基线 105 + 新增 27）。
- 依赖变更：**移除 `dynamic_color`**。它的 2.1.0 依赖独立 `material_ui` 包，
  其 `ColorScheme`/`Widget` 与 `package:flutter/material.dart` 不是同一套类型，
  跨包类型冲突无法在同一 `MaterialApp` 里共存。动态取色本是可选润色，主题已有
  seed 兜底，故直接去掉该依赖，保持全仓统一走 `flutter/material`。
- 文档：`AgentHelp/PHASES.md` 升基线链 + M7 拆成 A–D、M8 拆成 A–F 状态表。
- 状态：**已落地并提交**；下一步 M7-B（七页重写）。

## M7-B · 2026-10-11 · 七页重写（基线仍 132，契约零破坏）

- 版本：Flutter 3.47.6 stable。
- 测试基线：`132 tests / 0 failed`（`flutter analyze` 零告警）。
- 后端依赖：不变。
- 改动（全部用 M7-A 的组件库重排）：
  - `lib/ui/home_shell.dart`：去掉全局 AppBar，改为每页自带 `SliverAppBar.large`；
    设置入口以共用 action（`shell-open-settings`）注入四页；底部换 `EhNavBar`。
  - `lib/ui/dashboard_page.dart`：`CustomScrollView` + 大标题 + 2/4 列 `EhCard`
    计数格 + `MetricStrip` 活动条 + `ToneChip` 需干预行；启动告警走 `EhCard.warning`。
  - `lib/ui/candidates_page.dart`：大标题 + `ChoiceChip` tab + `EhSearchBar`；
    行改 `EhCard`（`CoverThumb` 60×84 + 标题 + 作者/分类 + `ToneChip`）；空态 `EmptyState`。
  - `lib/ui/activity_page.dart`：大标题 + 两张 `EhCard` 计数 + `SectionHeader` 分组。
  - `lib/ui/downloaded_page.dart`：大标题 + `EhSearchBar`；行 `EhCard`（状态/打包/来源 chip）。
  - `lib/ui/candidate_detail_page.dart`：`SliverAppBar.large` + 概览 `EhCard`
    （封面 + `ToneChip` + `TagChip`）+ 元数据/时间线 + 主/次/危险三层操作（危险操作独立 `EhCard.warning`）。
  - `lib/ui/settings_page.dart`：分区改为 `SectionHeader` + `EhCard`；连接状态用 `ToneChip`；
    `settings-logout` 键保留。
  - `lib/ui/login_page.dart`：`SliverAppBar.large` + `TabBar`（密码 / API Key 两 tab 保留）+
    服务器行 `EhCard` + 圆角提示条。
  - `lib/ui/widgets/status_chip.dart` **删除**，全部迁移到 `ToneChip`
    （`ToneChip` 扩展为覆盖后端完整 tone 词表：success/danger/warning/info/active/waiting/muted，
    并新增 `ToneChip.status(StatusView)` 工厂）。
  - `lib/ui/widgets/large_title_app_bar.dart`：改为 `SliverAppBar.large` + 可选 `bottom`；
    副标并入标题列（该版本 `SliverAppBar.large` 无 `subtitle` 形参）。
- 验证：`flutter analyze` 零告警；`flutter test` → 132 / 0 failed
  （M6/M7-A 的 key 与文案契约全部守住：`summary-total` / `dashboard-chip-*` / `dashboard-attn-*` /
  `activity-downloads` / `activity-job-*` / `candidate-tab-*` / `candidate-load-more` /
  `downloaded-*` / `detail-title` / `detail-approve` / `detail-reject` / `detail-action-*` /
  `detail-prev` / `detail-next` / `settings-logout` / `login-*` / `NavigationBar` 四标签）。
- 文档：`AgentHelp/PHASES.md`（M7-B 状态）。
- 偏差记录：活动页未改成 `SegmentedButton` 分段——现有测试要求「进行中（1）」与「历史（1）」
  同时可见，分段会隐藏其一；详情页操作区保留在滚动内容内（测试用 `scrollUntilVisible` 定位按钮，
  若放进 sticky 底栏会失去可滚动性）。两点都写进本条目备查。
- 状态：**已落地并提交**；下一步 M7-C（多服务器数据层 + 启动迁移）。

## M7-C · 2026-10-11 · 多服务器数据层 + 启动迁移（基线 132 → 138）

- 版本：Flutter 3.47.6 stable。
- 测试基线：`138 tests / 0 failed`（`flutter analyze` 零告警）。
- 后端依赖：不变。
- 改动：
  - `lib/state/server_store.dart`（新增）：`ServerProfile { id, label, settings }`
    + `ServerStore`（`ehbot.servers` JSON 数组 + `ehbot.active_server_id`）
    + `newServerId()`。**不做账号体系**——多份档案只是「多台服务器」。
  - `lib/state/app_state.dart`：新增 `serverStore`（构造参数可选，旧调用零改动）、
    `servers` / `activeServerId` / `activeServer` getter；`bootstrap()` 读多档案，
    **旧 `ehbot.settings` 自动迁移**成一条档案（老用户无感升级）；
    `saveSettings()` 改为 upsert 当前档案；新增 `switchServer()`（登出 + 切档 + 落登录页）、
    `renameServer()`、`removeServer()`（删当前档时回落到下一条）。
  - `test/state/server_store_test.dart`（新增 6 条）：迁移 / 多档选中 / active 失效回落 /
    切换登出 / 删除回落 / 重命名。
- 验证：`flutter analyze` 零告警；`flutter test` → 138 / 0 failed（M7-B 的 132 + 新增 6）。
- 文档：`AgentHelp/PHASES.md`（M7-C 状态）。
- 状态：**已落地并提交**；下一步 M7-D（动效 + 响应式打磨）。

## M7-D · 2026-10-11 · 响应式断点 + RepaintBoundary（M7 收尾，基线 138 → 140）

- 版本：Flutter 3.47.6 stable。
- 测试基线：`140 tests / 0 failed`（`flutter analyze` 零告警）。
- 后端依赖：不变。
- 改动：
  - `lib/ui/theme.dart`：新增 `ehColumnsForWidth(width)`——< 600 → 1 列、≥ 600 → 2 列、
    ≥ 840 → 3 列。
  - `lib/ui/candidates_page.dart` / `lib/ui/downloaded_page.dart`：窄屏 `SliverList`、
    宽屏 `SliverGrid`；每张卡套 `RepaintBoundary`（隔离封面重绘）。
  - `lib/ui/widgets/metric_strip.dart`：条目套 `RepaintBoundary`。
  - `test/widgets/theme_test.dart`：补 `ehColumnsForWidth` 三断点断言。
  - `test/ui/responsive_layout_test.dart`（新增）：窄屏用列表、宽屏用网格。
- 验证：`flutter analyze` 零告警；`flutter test` → 140 / 0 failed（138 + 2）。
  - 修复途中发现的真 bug：宽屏网格单元高度不足触发 `RenderFlex overflowed`
    （候选 116 → 160、已下载 132 → 180，并给内层 `Column` 加 `mainAxisSize.min`）。
- 偏差记录：提案 §7.4 提到的**黄金截图未落地**。黄金 PNG 对渲染后端 / 平台字体敏感，
  在本机通过不代表运营者机器与 CI 通过，会引入假红；改用「组件渲染 + 交互 + 断点列数」
  的可移植断言代替。若运营者要黄金基线，可另开一期，并配 `--update-goldens` 指引。
- 文档：`AgentHelp/PHASES.md`（M7-D 完成，M7 整体收尾）。
- 状态：**M7 全部四个子阶段完成**（基线 105 → 140，契约零破坏）。

## M8-A · 2026-10-11 · 多服务器 UI（基线 140 → 144）

- 版本：Flutter 3.47.6 stable。
- 测试基线：`144 tests / 0 failed`（`flutter analyze` 零告警）。
- 后端依赖：无（纯本地档案管理）。
- 改动：
  - `lib/ui/servers_page.dart`（新增）：列出全部服务器档案，当前那台打勾；
    点另一台即切换（`switchServer` + 自动返回）；右上角 `+` 进添加表单；
    每行 `PopupMenuButton` 提供 编辑 / 重命名 / 删除。
  - `lib/ui/server_setup_page.dart`：新增 `isNew`（追加档案）与 `editingId`（编辑指定档案）
    两个入参，三种进入方式共用一个表单；保存分别走 `addServerWith` / `saveProfileSettings` /
    旧的 `saveSettings`（首启路径不变，既有测试零改动）。
  - `lib/state/app_state.dart`：新增 `addServerWith()` 与 `saveProfileSettings()`。
  - `lib/ui/home_shell.dart`：顶栏新增服务器切换入口（`shell-open-servers`，显示当前档案名），
    设置图标保留。
  - `lib/ui/login_page.dart`：多档案时「更换服务器」进服务器列表页；单档案时仍回到表单。
  - `test/ui/servers_page_test.dart`（新增 4 条）：列出并标当前 / 切换并返回 / `+` 进添加表单 /
    删除当前后回落。
- 验证：`flutter analyze` 零告警；`flutter test` → 144 / 0 failed（140 + 4）。
- 文档：`AgentHelp/PHASES.md`（M8-A 状态）。
- 状态：**已落地并提交**；下一步 M8-B（后端契约文档）。

## M8-B · 2026-10-11 · 后端契约快照（文档）

- 文档：`AgentHelp/CONTRACT.md` 新增 §7「M8 端点快照」——列出 manual_add / dedup / logs /
  connections / sources / parse / auto-approval / archive / paths / ai / passwords / api-key /
  system 共 20 行端点，标注「后端尚未实现，客户端按 404 降级消费」。
- 明确：改管理员密码移动端不实现；passwords / api-key / connections 永不回显明文；
  404 时页面给「后端未就绪」说明而不崩。
- 验证：纯文档；`flutter analyze` / `flutter test` 不受影响。

## M8-C · 2026-10-11 · Manual Add + Dedup（基线 144 → 150）

- 版本：Flutter 3.47.6 stable。
- 测试基线：`150 tests / 0 failed`（`flutter analyze` 零告警）。
- 后端依赖：`B-M8`（未实现）；客户端在 404 时显示「后端未就绪」提示。
- 改动：
  - `lib/api/models.dart`：新增 `ManualAddResult` / `DedupEntry` / `DedupGroup` /
    `DedupPlan` / `DedupResult`。
  - `lib/api/ehbot_api.dart`：新增 `manualAdd()` / `dedupPlan()` / `dedupApply()`。
  - `lib/ui/error_text.dart`：新增 `isEndpointMissing()` 与 `kEndpointMissingHint`。
  - `lib/ui/widgets/error_view.dart`：404 时显示「后端未就绪」而不是裸错误码。
  - `lib/ui/manual_add_page.dart`（新增）：粘贴链接 → 解析入队；重复链接给「查看已有候选」；
    表格输入键 `manual-url` / `manual-submit` / `manual-open-existing`。
  - `lib/ui/dedup_page.dart`（新增）：先看计划（保留/移除 + 原因）再确认执行；键 `dedup-apply`。
  - `lib/ui/dashboard_page.dart`：新增「快捷操作」区（手动添加 / 一键去重），放在页面末尾
    （**放前面会把 M6 的需干预行挤出测试视口**，见下）。
  - `test/ui/manual_add_page_test.dart`（3 条）、`test/ui/dedup_page_test.dart`（3 条）。
- 验证：`flutter analyze` 零告警；`flutter test` → 150 / 0 failed（144 + 6）。
  - 途中修复：工作台改用 `SliverToBoxAdapter + Column`（`SliverList` 懒构建会让下方
    `需干预（1）` 不被构建，M6 断言失败）；「快捷操作」置于页尾以保持需干预行位置。
- 文档：`AgentHelp/PHASES.md`（M8-B / M8-C 状态）。
- 状态：**已落地并提交**；下一步 M8-D（日志实时流）。

## M8-D · 2026-10-11 · 日志实时流（基线 150 → 152）

- 版本：Flutter 3.47.6 stable。
- 测试基线：`152 tests / 0 failed`（`flutter analyze` 零告警）。
- 后端依赖：`B-M8`（未实现）；404 时页面给「后端未就绪」。
- 改动：
  - `lib/api/models.dart`：新增 `LogEntry` / `LogLevelOption` / `LogsPageData`。
  - `lib/api/ehbot_api.dart`：新增 `logs({level, limit})` 与 `logsStream()`
    （复用 `SseEventSource`，路径 `/api/v1/logs/stream`）。
  - `lib/ui/logs_page.dart`（新增）：大标题 + 级别筛选 + 暂停/继续；
    历史一次拉取、实时经 SSE 前插；`logs-pause` / `logs-level-<code>` 为测试键。
  - `lib/ui/home_shell.dart`：底部导航新增第 5 项「日志」，指向 `LogsPage`。
  - `test/ui/logs_page_test.dart`（2 条）：历史渲染 + 控件存在 / 404 说明。
- 验证：`flutter analyze` 零告警；`flutter test` → 152 / 0 failed（150 + 2）。
- 文档：`AgentHelp/PHASES.md`（M8-D 状态）。
- 状态：**已落地并提交**；下一步 M8-E（设置八区）。

## M8-E · 2026-10-11 · 设置分区（九区，两态渲染，基线 152 → 155）

- 版本：Flutter 3.47.6 stable。
- 测试基线：`155 tests / 0 failed`（`flutter analyze` 零告警）。
- 后端依赖：`B-M8`（未实现）；`GET /api/v1/settings/<section>` 404 时给出「后端未就绪」。
- 改动：
  - `lib/api/ehbot_api.dart`：新增 `settingsSection(section)`（`/api/v1/settings/<code>`）。
  - `lib/ui/settings_sections_page.dart`（新增）：
    - `SettingsSection` + `kSettingsSections` 九区（connections / sources / parse /
      auto-approval / archive / paths / ai / passwords / system），每区带图标与本区说明；
    - `SettingsSectionsPage`：宽屏（≥ 840）走 `NavigationRail`，窄屏走横向 `ChoiceChip`
      选择条（测试键 `settings-section-<code>`）；
    - `SettingsSectionView`：拉取该区快照 → `AsyncView`。**200 时把 JSON 摊平成
      key/value 只读列表**（后端字段一变这里自动跟上，不用再发一次客户端版本）；
      404 时显示「后端未就绪」提示。
  - `lib/ui/settings_page.dart`：新增「分区设置」入口卡片（键 `settings-open-sections`）。
  - `test/ui/settings_sections_page_test.dart`（3 条）：九区齐全 / 200 渲染 key-value / 404 提示。
- 设计取舍：本区各表单（连接凭据、来源白名单、规则编辑器、AI 供应商…）都需要真实后端
  才能验证；后端未实现前写成不可验证的复杂表单属于投机。因此本期交付**可用的两态渲染骨架**
  + 完整分区导航，后端 B-M8 落地后每区再补专用表单（各开一期）。
- 验证：`flutter analyze` 零告警；`flutter test` → 155 / 0 failed（152 + 3）。
- 文档：`AgentHelp/PHASES.md`（M8-E 状态）。
- 状态：**已落地并提交**；下一步 M8-F（多选 + 滑动手势）。

## M8-F · 2026-10-11 · 多选 + 滑动手势（M8 收尾，基线 155 → 158）

- 版本：Flutter 3.47.6 stable；App 版本升 **v0.2.0**。
- 测试基线：`158 tests / 0 failed`（`flutter analyze` 零告警）。
- 后端依赖：候选批量审核端点已存在（`POST /api/v1/candidates/batch`）。
- 改动：
  - `lib/ui/widgets/eh_card.dart`：新增 `onLongPress`；有任一回调即走 `InkWell`。
  - `lib/ui/candidates_page.dart`：
    - **长按进入多选**（`_selected`），进入后行首显示勾选图标、点行即切换选中；
    - 底部批量条（`candidate-batch-approve` / `candidate-batch-reject` /
      `candidate-batch-cancel`），走现有批量端点并刷新；
    - **滑动手势**（`Dismissible`）：右滑通过、左滑驳回，`confirmDismiss` 里执行动作并
      返回 `false`，条目由后端刷新决定去留（不先斩后奏）。
  - `test/ui/candidates_batch_test.dart`（3 条）：长按多选 + 批量通过 / 取消退出 / 右滑通过。
- 验证：`flutter analyze` 零告警；`flutter test` → 158 / 0 failed（155 + 3）。
- 文档：`AgentHelp/PHASES.md`、`README.md`（五页 + 多服务器 + 设置分区说明、基线 158）、
  `CHANGELOG.md`（v0.2.0 段落）。
- 状态：**M8 全部六个子阶段完成**。本轮 M7 + M8 合计基线 105 → 158。

## M9-A · 2026-10-11 · 外观：主题模式 + 配色方案（基线 158 → 161）

- 版本：Flutter 3.47.6 stable；App 版本升 **v0.3.0**。
- 测试基线：`161 tests / 0 failed`（`flutter analyze` 零告警）。
- 后端依赖：无（纯本地 `SharedPreferences`）。
- 背景：运营者实测 v0.2.0 第 3 项「需要能自定义主题模式、配色方案自由选择」。
  M9 总方案见 `AgentHelp/M9_OPERATOR_FIXES_PROPOSAL.md`（v2，已按 EhBot `7ebab47` 重写）。
- 改动：
  - `lib/state/theme_store.dart`（新增）：`ThemeSettings{mode, seed}`（8 个预设色 +
    `kDefaultSeed`）与 `ThemeStore`（`ehbot.theme_mode` / `ehbot.seed_color`）。
  - `lib/ui/theme.dart`：`AppTheme.light([seed])` / `dark([seed])` 接受运行时 seed。
  - `lib/state/app_state.dart`：`themeSettings` + `setThemeMode()` / `setSeedColor()`；
    `bootstrap()` 先加载外观再决定首屏。
  - `lib/ui/app.dart`：`theme` / `darkTheme` 用当前 seed，`themeMode` 用当前模式。
  - `lib/ui/widgets/appearance_section.dart`（新增）：模式 `SegmentedButton`
    （跟随系统 / 浅色 / 深色）+ 预设色圆点 + 色相滑块（不引第三方取色器）。
  - `lib/ui/settings_page.dart`：顶部新增「外观」区。
  - `test/ui/appearance_settings_test.dart`（新增 3 条）：默认值 / 持久化与重载 /
    设置页外观区控件可点并改色。
  - `test/ui/settings_page_test.dart`：分区整体下移，改为 `scrollUntilVisible` 定位。
- 设计取舍：不引入 `dynamic_color`（M7 已因跨包类型冲突移除）；色相滑块替代取色器，
  少一个依赖、多一条可测路径。
- 验证：`flutter analyze` 零告警；`flutter test` → 161 / 0 failed（158 + 3）。
- 文档：`AgentHelp/PHASES.md`（M9-A 状态）、`README.md`（外观 + 基线 161）、
  `CHANGELOG.md`（v0.3.0 段落）。
- 状态：**已落地**；下一步 M9-B（数据层重写）。
