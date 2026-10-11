# M8 提案 — WEBUI 功能全复刻（业务深度对齐）

> 状态：**草稿，待运营者审阅**。
> 这是 M7 之后的工作。M7 把 UI 框架搭好之后，本期按 WEBUI 一一对应齐所有功能面，
> 包括后端**目前还没有的端点**（需先在 EhBot 仓库里跟着出 M8-B 后端 PR），
> 再加上"多服务器管理"在 M7 的模型上的 UI 补完。
> 验收基线要更新；M8 落地后基线 `flutter test` 用例数会增加。

## 1. 需求

WEBUI 是 M0→M6 期间运营者日常使用的工具。WEBUI 的功能矩阵 vs 当前 mobile App：

| WEBUI 页面            | WEBUI 端点（粗）                                              | 当前 mobile 状态    |
|-----------------------|----------------------------------------------------------------|---------------------|
| Dashboard             | `/api/v1/summary`                                             | ✅ 已实现           |
| Candidates（list）    | `/api/v1/candidates?tab=&filters=`                            | ✅ 已实现（无 filter） |
| Candidates（批处理）  | `POST /api/v1/candidates/batch`                               | ⚠️ 单个版本，没有批量 |
| Works（详情）         | `/api/v1/works/{id}` + 各种 action                            | ✅ 已实现（M3+M6）   |
| Activity              | `/api/v1/queue` + `/api/v1/history`                           | ✅ 已实现（M4）     |
| Downloaded            | `/api/v1/downloaded`                                          | ⚠️ 单 tab，无批量/改名 |
| Manual Add            | `POST /candidates/manual`                                     | ❌ 完全没有         |
| Dedup                 | `/api/v1/dedup` + `GET /dedup/plan`                           | ❌ 完全没有         |
| Logs                  | `/api/v1/logs/stream` (SSE) + `/api/v1/logs?level=`           | ❌ 完全没有         |
| Settings / Connections | `/api/v1/settings/connections`                                | ❌ 无编辑（5 区只读） |
| Settings / Sources    | `/api/v1/settings/sources` + `/dialogs`                       | ❌ 无               |
| Settings / Parse      | `/api/v1/settings/parse`                                      | ❌ 无               |
| Settings / Auto-approve | `/api/v1/settings/auto-approval/rules` + `/dry-run`         | ❌ 无               |
| Settings / Archive    | `/api/v1/settings/archive/{torrent,limits,profiles}`         | ❌ 无               |
| Settings / Paths      | `/api/v1/settings/paths/{template,rules,ai}`                  | ❌ 无               |
| Settings / AI         | `/api/v1/settings/ai/{providers,models,chain}`                | ❌ 无               |
| Settings / Passwords  | `/api/v1/settings/passwords` + `/api/v1/auth/api-key`         | ❌ 无               |
| Settings / System     | `/api/v1/settings/system`                                     | ❌ 无               |
| 多服务器切换          | —                                                              | ❌ 无（M7 计划）     |

## 2. 现状

- 数据：`lib/api/ehbot_api.dart` + `models.dart` 现只覆盖上表"✅ / ⚠️"部分。
- 状态机（`AppStage`：`loading / serverSetup / login / ready`）目前接单服务器；
  M7 后接 `ServerProfile` 列表 + active server。
- 401 处理已就绪；批量并发（bulk）走现有 `EhBotApi.candidates(...)` 路径，
  详情页 action 也用 `jobAction(...)`；批量 UI 还没有。
- 后端契约：`AgentHelp/CONTRACT.md` §1–§5 已列；M8 后需要**追加 §7** 把 manual_add / dedup /
  logs / settings 端点都写清楚。

## 3. 目标

按 WEBUI 一比一复刻，并把"为什么是 App 上能做的事"做扩展：

1. **服务端有的就暴露**——不写假数据，所有编辑走对应端点。
2. **多服务器就近是基本盘**——AppBar 的服务器切换 chip（M7 §4.4）走通整页。
3. **批量操作永远是 App 比 WEBUI 更顺**——长按多选 + sticky action bar + 滑动手势。
4. **凭证永不回显**——和 WEBUI 一样，回显均为 `"已配置"`，从不在 UI 显示明文。

## 4. 后端依赖（M8-B）

服务端本仓库不写，但**要把缺的接口列清楚**，运营者按表推动 EhBot 仓库补：

### 4.1 现有即用，不动

| 端点                          | 备注 |
|-------------------------------|------|
| `/api/v1/summary`             | M3 ✅ |
| `/api/v1/candidates` + facets | M3 ✅；客户端未消费 `facets`，M8 需消费 |
| `/api/v1/works/{id}`          | M6 ✅ |
| `/api/v1/candidates/batch`    | 当前仅 approve/reject；**需补** `delete` / `delete-files` / `requeue` |
| `/api/v1/queue` + history     | M4 ✅ |
| `/api/v1/jobs/{id}/{action}`  | M6 ✅ |
| `/api/v1/downloaded`          | M3 ✅；**需补** `repack / remove / remove-files / rename` |
| `/api/v1/auth/*`              | M1 ✅ |

### 4.2 需要新加的端点（M8-B 提案，作为 EhBot 仓库的 R-N 期）

| 模块 | 端点 | 方法 | 说明 |
|------|------|------|------|
| dedup | `/api/v1/dedup/plan` | GET | 给出每个重复组的"保留 / 移除"判定（不写） |
| dedup | `/api/v1/dedup` | POST | `{apply: true, group_decisions?}` 真正执行（带 dry-run） |
| logs | `/api/v1/logs` | GET | `?level=&limit=` 历史日志 |
| logs | `/api/v1/logs/stream` | GET (SSE) | 实时推送（与 `/events` 平行，但流专用） |
| manual_add | `/api/v1/candidates/manual` | POST | `{url}`；返回新 candidate 或 `existing_candidate_id` |
| connections | `/api/v1/settings/connections` | GET/PUT | Telegram bot / TG user / ExHentai 连接信息 |
| sources | `/api/v1/settings/sources` + `/{id}` | GET/POST/PATCH/DELETE | 白名单 + 解析规则 |
| sources | `/api/v1/settings/sources/dialogs` | POST | 用 TG user account 列出会话 |
| parse | `/api/v1/settings/parse` | GET/PUT | 消息解析规则 + AI 候选判定 |
| auto-approval | `/api/v1/settings/auto-approval/rules` + `/{id}` | full | 规则 CRUD |
| auto-approval | `/api/v1/settings/auto-approval/rules/{id}/dry-run` | POST | 试跑；返回匹配数 + 样例 IDs |
| archive | `/api/v1/settings/archive/{torrent,limits,profiles}` | GET/PUT | qBittorrent / 自动打包 / 安全限制 / 工具 profile |
| paths | `/api/v1/settings/paths/{template,rules,ai,previews,rearchive}` | GET/PUT/POST | 路径模板 / 路径规则 / AI 模式 / 预览 / 一键重新归档 |
| ai | `/api/v1/settings/ai/{providers,models,chain,verify}` | full | 供应商 / 模型 CRUD / 主力备用链 / 测试 |
| passwords | `/api/v1/settings/passwords` + `/{id}` | full | 归档密码条目 |
| passwords | `/api/v1/settings/me/password` | POST | 改管理员密码（prompts 移动端无用，**不实现**） |
| api-key | `/api/v1/settings/api-key` | GET/POST/DELETE | 生成 / 撤销 / 查看标识 |
| system | `/api/v1/settings/system` | GET/PUT | 运行参数 / 日志级别 / 时区 |

> 全部走 Bearer；`POST /api/v1/.../verify` 这类运行时检查不写 CSRF；列表与 JSON 信封沿用现有契约。

## 5. App 端架构

### 5.1 多服务器（沿用 M7 §4.4）

- `SettingsStore` → `ServerStore` 单独类，存在 `lib/state/server_store.dart`。
- `AppState`：
  - `servers: List<ServerProfile>`、`activeServerId: String?`；
  - `bootstrap()`：读 `ehbot.servers` + `ehbot.active_server_id`；
  - `switchServer(ServerProfile)`：先 `logout(revoke: false)`，再 `setActive(id)`，跳登录页。
- 自动迁移：M6 之前装的 `ehbot.settings` 在 v0.2.0 启动时一次性迁移到 `ehbot.servers[0]`。

### 5.2 路由

切到 `go_router`（方案遵循 `flutter-setup-declarative-routing` skill）：
- `/servers`（选择 / 编辑列表）
- `/servers/new`、`/servers/:id/edit`
- `/login`、`/home`（IndexedStack 含 dashboard/candidates/activity/downloaded/logs）
- `/works/:id`
- `/manual`
- `/dedup`
- `/settings` → `/settings/connections`、`/sources`、`/parse`、`/auto-approval`、
   `/archive`、`/paths`、`/ai`、`/passwords`、`/system`、`/about`
- 深度链接：候选行的 `?tab=&filter=` 直接落到 `candidates` tab + 筛选。

### 5.3 网络层

- 新加 `EhBotApiSettings`：`EhBotApi` 引入二级 `paths/settings/*`，返回对应的 settings 模型。
- `models.dart` 大扩容：每个 settings 子模块一个文件（`models/settings_connections.dart`、
  `models/settings_sources.dart` ...），M8 一次性合入 `models.dart` 或 `lib/api/settings/` 目录。
- 凭证 **永远不** 出现在 `toJson` / `fromJson`：所有 password / token 字段在模型里是 `String?`，
  服务端响应丢弃。

### 5.4 UI 与交互

| 模块 | 设计要点 |
|------|---------|
| Manual Add | 单页：圆角 textarea + `ExHentai/qB/qPrep` 三个依赖 `ToneChip` + 「解析并加入队列」按钮；重复链接命中给"查看已有候选"按钮 |
| Dedup | 第一步 GET 计划 → `EhCard` 列每个重复组（保留 vs 移除表）；底部"立即去重"大按钮 |
| Logs Live | M4 SSE 已就绪，M8 接 `EhBotApi.logsStream()`；UI：固定顶栏 = 级别选择 + 暂停按钮，列表 = 倒序追加 |
| Settings | 左 drawer 列分区；每个分区按 WEBUI 的 section 顺序写出对应的表单页（`SettingsConnectionsPage` 等） |
| 多服务器 | 首页启动若多 profile → `/servers` 选择页，单 profile → 直登录；编辑页可改 baseUrl/允许自签/允许明文/超时 |

## 6. 测试计划

- API：
  - 每个 settings 子端点的 GET/PUT round-trip（mock client）。
  - `dedup` GET 计划 → POST 执行的形参与 `applied` / `skipped` 解析。
  - `logs?level=` / SSE `parseSse` 容错（漏一字段/关连接）。
- Widget：
  - 多服务器：单 profile → 直登录；多 profile → 选择页；切换触发 `logout(notice=...)`。
  - 详情页批量操作的多选状态机（基于 M6 的 `JobSelectionState`）。
  - Logs 实时加入后顶部不动，列表顺滑滚动。
- 集成：
  - 现有 `app_test.dart` 不破；`phase_test.dart` 加 M8 的 smoke。
- 基线：M7 后基线（如 `~135 tests / 0 failed`）升到 M8 后基线（估 `200+ tests / 0 failed`）。

## 7. 阶段切分

按"小步快跑"原则拆 6 个子阶段，每期对应一份子提案：

- **M8-A: 多服务器管理**（依赖 M7，1 PR，最少）
  - `ServerProfile` 数据层 + 选择页 + AppBar chip
  - 自动迁移 `ehbot.settings` → `ehbot.servers[0]`
  - 验收点：装上之后可加 2 台服务器并切换

- **M8-B: 端点契约（落到 EhBot 仓库 PR）**
  - 后端 4.2 表中所列端点；本仓库**不**实现，只在新后端部署后由客户端拉。
  - 在 `AgentHelp/CONTRACT.md` 加 §7 端点快照。

- **M8-C: Manual Add + Dedup**
  - 新页 + `EhBotApi.manualAdd()` / `dedupPlan()` / `dedupApply()`
  - 验收：WEBUI 里能粘贴的链接，这里也能；WEBUI 的一键去重能跑出来

- **M8-D: Logs Live**
  - `LogsPage` + `EhBotApi.logs()` 与 `logsStream()`
  - 验收：日志按级别倒序追加，支持暂停 + 重连

- **M8-E: Settings（按 §4.2 中 8 个）**
  - 每区一子页，按 WEBUI 文档同步写
  - 验收：8 区每区至少 1 条 widget test + 1 条 round-trip 测试

- **M8-F: 多选 + 滑动手势**
  - 候选 / 已下载的批量 + `Dismissible` 滑出操作
  - 验收：从选到批改到撤销回流，全 widget test 覆盖

每个子阶段都有自己的子提案 `M8-{A..F}_PROPOSAL.md`，运营者按节奏批 / 不批。

## 8. 备选（否决）

- **一次性把 8 区设置全搬**：写一提案压过去，对运营者审阅负担太大——拆 M8-E。
- **直接复刻 WEBUI 表单布局**：与 M7 冲突；走 M3 表单 + `EhCard`。
- **撤销 / 审计日志移动端**：WEBUI 也没有，没必要做。

## 9. 后端 / 客户端状态影响

- API：M8-B 增表 §4.2。
- 数据：扩 `models.dart` 至少 30 个新 model 类。
- 存储：M8-A 增 `ehbot.servers`、`ehbot.active_server_id`。
- Token：单服务器 token 仍在 `flutter_secure_storage`，按 active server 隔离 ——
  M8-A 引入 `tokenStore.readForServer(id) / writeForServer(id, ...)`。
- Web 鉴权：客户端 Bearer 不变。

## 10. 文档同步

- `AgentHelp/CONTRACT.md` 加 §7 端点快照，每区一条；逐 commit 与后端对齐。
- `AgentHelp/MOBILE.md` §2.2 取消"明确不做"段落，把 M8 已实现的勾上。
- `progress.md` 每子阶段一条目；`PHASES.md` 加 6 行；`AGENTS.md` 升基线；`README.md` 列新增页面。
- `CHANGELOG.md` 加 v0.2.0 / v0.3.0 两个大版本。

## 11. 风险 / 已知限制

- WEBUI 的"实时 in-place update"用 HTMX，App 上没有等价物；M8 的 in-place 仅是顶部 banner。
- WEBUI 的 `ui_kit.html` + `app.css` 不可移植；M7 自建组件与之同名但 API 不同。
- 后端 M8-B 是新工作；本仓库**不**等待其发布，会单独把客户端代码按"端点存在 / 端点 404"分两态走防御。
- 移动端没有"管理员改密"流程（WEBUI 浏览器才有），`change_password` 端点**不消费**。
