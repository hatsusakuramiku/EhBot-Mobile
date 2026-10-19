# M10 提案 — 对齐 EhBot R101：WSS 实时 + v2/CAS 重构

> 状态：**草稿，待运营者审阅**。
> 核对基线：移动端 `dd37ac9`（v0.3.0+1，204 tests / 0 failed）；
> 服务端 `/home/coder/workspace/EhBot` `750ed29`（R101，0.3.0rc14 / schema041）。
>
> 说明：R100/R101 已在服务端本地提交，但尚未由运营者验收；P12/R99
> （0.3.0rc14 / schema039）仍是最后完整验收基线。本方案按 R101 的源码和契约
> 编写，移动端验收目标也按 R101；最低硬门槛见 §2.1。

## 0. 审阅摘要

本方案建议把移动端从「旧 `/api/v1` + SSE + 定时轮询」整体迁到服务端当前的
「能力发现 + WSS 命令/失效通知 + HTTP 快照 + revision/幂等」架构。

需要运营者确认的决策：

1. **WSS 是唯一实时通道**：不保留 SSE、不保留 API 定时轮询、不做 HTTP 写回退。
2. **HTTP 只做非实时职责**：登录/刷新/登出/whoami、能力探测、JSON 快照读取、
   缩略图、文件、账号 reveal，以及协议明确只能走 HTTP 的响应。
3. **所有业务写操作走 WSS 命令**，并统一携带 `work_id` / `task_id`、
   `expected_revision`、`idempotency_key`；断线/超时后不自动重发。
4. **能力发现失败即停止**：服务端不提供 `ehbot-realtime.v1` 或 `/api/v2`
   时显示「服务端过旧」页，不降级到旧协议。最低 R97/P10；R101 是目标验收版本。
5. 删除「要求修订」与「停止做种」；设置九区全部改为版本化命令；账号生命周期
   迁到 `/api/v2/accounts`。若审阅认为范围过大，建议只把账号 UI 拆到 M11，
   但不保留旧单连接写入口。
6. **版本号**：运营者已明确批准本次重大重构升到 `v0.4.0`；该版本只在 M10 收尾
   落地。后续未经指定不得提升 major/minor，功能或修复只升 patch，纯文档变更不升版本。

## 1. 需求与验收目标

### 1.1 运营者要求

- 移动端改用 `wss` 协议。
- 抛弃旧的 API 轮询方式。
- 适配服务端最新架构，而不是只修几个 404。

### 1.2 本方案的完成定义

- 生产环境 HTTPS 服务器只连 `wss://`；仅当用户显式允许明文 `http` 时才允许
  `ws://`，且界面继续标注不安全。
- 代码中不再有 SSE 客户端、页面状态定时器、polling 回退或「断流后按间隔刷新」。
- 写操作在实时通道不可用时直接禁用，绝不偷偷改走 HTTP。
- revision/幂等键成为命令层的一等对象，不由网络层「顺手补当前版本」。
- 服务端返回的 `state` 只作为失效通知；客户端按 scope 重新读取 JSON 快照。
- 切换服务器、退出登录、应用回前台都有明确的连接生命周期与旧响应隔离。

## 2. 服务端事实（按 R101 源码核对）

### 2.1 最低版本与能力发现

- `GET /api/v2/capabilities` 需要认证，返回：
  - `api_versions`
  - `task_api`
  - `settings_api`
  - `accounts_api`
  - `deployment_prefix`
  - `administrator.password_login_requires_username`
  - `realtime.protocol/path/replay/resync/accepted_frame_is_durable`
  - `sources[]`
  - `tasks`（`task_id` 身份、revision 要求、幂等头、动作、切源目标）
- 移动端最低要求：
  - `api_versions` 含 `v2`
  - `realtime.protocol == "ehbot-realtime.v1"`
  - `realtime.path` 非空
  - `realtime.resync == "snapshot"`
- 由于 v2 能力、共享命令、持久回执与 CAS 在 P10/R97 才完整，最低服务端定为
  **R97 / schema039**；目标验证版本为 **R101 / schema041**。
- 不再用「登录是否 404」或 App 版本号判断服务端能力。

### 2.2 WSS 协议

- 路径：`/ws/ui`；反代前缀下由能力返回，例如 `/ehbot/ws/ui`。
- 握手：`Authorization: Bearer <access token 或 API Key>`。
- 原生客户端不发送 Cookie、CSRF、Origin；凭据不放 URL、帧或日志。
- 首帧 10 秒内：

```json
{"type":"hello","protocol":"ehbot-realtime.v1","client":"mobile","logs":true}
```

- `ready` 返回 `epoch`、`sequence`、`heartbeat_seconds`、`replay:false`
  和移动端可用的 `api.*` / `v2.*` 命令目录。
- 服务端每 15 秒发 JSON `ping`，客户端回 `pong`；45 秒无客户端消息会断开，
  发送超时 10 秒也会断开。
- 无事件重放。重连后必须重新读取快照；`epoch` 变化、`sequence` 跳变、
  heartbeat 水位超前都应触发校正。
- 断线建议抖动指数退避：1 秒起，30 秒封顶。

### 2.3 命令与结果语义

- 命令名只能来自 `ready.commands`，不能把 Web 路径或任意 URL 当命令执行。
- `payload.params` 必须完整对应目录参数；`payload.query` 是字符串二元组数组。
- 结果帧：
  - `command.accepted`：只表示进入该连接的队列。
  - `command.result`：接口完成；`data` 复用原 HTTP 响应。
  - `command.error`：业务/协议错误。
- `command.accepted` 不代表持久受理；`command.result` 的 202 也通常只表示
  已有 `operation_id`，不代表后台执行完成。
- 同一连接内命令串行执行，队列上限 8；`COMMAND_BUSY` 不是成功。
- `request_id` 标识一次传输；`idempotency_key` 标识一次用户意图。重发同一意图
  可以换 `request_id`，但不能自动换幂等键。
- 断线或超时后，写操作结果可能是「未知」；禁止自动重发。先读业务快照、
  `operation_id` 或回执，再由用户决定是否以原键显式重试。

### 2.4 状态与日志

- `state` 事件示例：

```json
{
  "type": "state",
  "epoch": "...",
  "sequence": 13,
  "scope": "candidate|download|conversion|connection|refresh",
  "data": {"job_id": 9, "candidate_id": 42},
  "refresh_required": true
}
```

- 事件是失效通知，不是实体状态；客户端必须重新读取对应 JSON 快照。
- 日志通过同一连接 `logs:true` 订阅，先回放最近 50 条，再发 `type:log`。
- 日志 sequence 独立于状态 sequence，按 `(epoch, sequence)` 去重。

### 2.5 破坏性变化

| 变化 | 服务端事实 | 移动端现状 |
|------|------------|------------|
| 密码登录 | `POST /api/v1/auth/login` 必须带 `username` + `password` | 只发 `password`，登录页没有用户名 |
| 要求修订 | R84 已彻底移除端点、动作和状态；迁移 025 改为 `NEEDS_INFO` | 仍调用 `/works/{id}/needs-revision` 并渲染按钮 |
| 停止做种 | R100 从 v1/v2/WS/页面全部移除；qB 自己管理种子 | 仍有 `kJobStopSeeding`、`canStopSeeding`、按钮 |
| 作品写操作 | 必须带 `work_id` + `expected_revision` + `idempotency_key` | 均未携带 |
| 批量操作 | 逐项 `versions` + 批次 `idempotency_key` | 只发 id 列表 |
| 去重执行 | 必须带 `plan_id` + `idempotency_key` | 空 body 执行 |
| 手动添加 | 必须带 `idempotency_key`，返回 `manual_add_operation_id` | 只发 `url` |
| 任务身份 | v2 使用 UUID `task_id`；旧整数只是 `legacy_job_id` | `JobSummary.id` 仍只解析整数 `job_id` |
| 任务操作 | v2 路径 task UUID 必须与 body 一致，并带 revision/key | 仍走 `/api/v1/jobs/{job_id}/...` |
| 设置写入 | 九区均版本化；回执与当前快照分离 | 仅三区可写，且把写响应当快照 |
| 账号模型 | `/api/v2/accounts` 命令 + `account_id/revision` | 只认单套 legacy connections |
| 分页 | `page_size` 任意正整数，非法才回落默认 50 | 固定 30，未跟随服务端默认 |

## 3. 移动端现状与影响面

### 3.1 实时层

- `lib/api/events.dart`：SSE 解析器与 `SseEventSource`，本次应删除。
- `lib/state/live_monitor.dart`：SSE 优先、`polling` 回退、定时器重连与 tick
  广播，本次应整体替换。
- `lib/ui/home_shell.dart` 自己创建/销毁 monitor，生命周期绑定页面而不是服务器
  会话；切换服务器时容易保留旧连接。
- 工作台、候选、活动、已下载页都订阅通用 `ticks`，无法按 scope 精确刷新。
- 日志页另开 `/api/v1/logs/stream` SSE，与状态事件是两条独立连接。

### 3.2 鉴权与会话

- `lib/api/auth_api.dart` 的密码登录缺少 `username`。
- `lib/ui/login_page.dart` 只有密码输入框。
- 当前 refresh 没有 single-flight；HTTP 快照与 WSS 同时收到 401 时可能并发轮换
  refresh token。
- `whoami` 已返回 `username` / `revision`，移动端模型只用了其中一部分。

### 3.3 数据模型

- `Candidate` 没有 `work_id` / `revision`。
- `JobSummary` 没有 `task_id` / `revision` / `generation` / `attempt_id` /
  `pending_operation` / `display_title`，无法安全执行 v2 命令。
- `DownloadedWork` 没有 `work_id` / `revision`。
- `WorkDetail` 没有 `work_id` / `revision` / `archive_metadata` /
  `metadata_editor` / `archive` / `ingest_operations`。
- `WorkActions` 仍在文档中声明 `needs_revision`，且把已可调用的
  `edit_archive_path` 误记为不可用。
- `TaskView`、`Operation`、`Removal`、`Artifact`、`Capabilities`、
  settings version、account 等模型缺失。
- `ClientMeta.pollingInterval` 仍在驱动旧实时层，应从实时路径移除。

### 3.4 写操作面

`lib/api/ehbot_api.dart` 中的以下方法都需要重写或删除：

- 审核、删除：缺逐项 `versions` 与批次幂等键。
- `requeueWork`、`updateMetadata`、`convertWork`、`fetchMetadata`、
  `pullSource`、`renameDownloaded`：缺作品身份与版本。
- `requestRevision`：端点不存在，删除。
- `jobAction`、`jobPriority`、`jobBatch`、`switchSource`：旧整数任务面，
  改走 task UUID + revision。
- `downloadedBatch`：缺逐项版本与幂等键。
- `manualAdd`：缺幂等键，未消费 `manual_add_operation_id`。
- `dedupApply`：缺 `plan_id` 与幂等键。
- 设置写入：缺 `settings_versions`、`expected_revision`、幂等键。

### 3.5 设置与账号

- `SettingsWriteMixin` 把 `PUT` 返回值直接当新快照；服务端现在返回固定回执，
  当前值必须重新 `GET`。
- 九区中仅三区有编辑器，其余六区只是按键摊平只读。
- `connections` 仍按单套 Telegram Bot / Telegram 用户 / ExHentai 凭据建模，
  没有 `/api/v2/accounts` 的稳定 `account_id`、`revision`、运行状态和生命周期命令。
- 账号 reveal 只能走 HTTP，且必须显式确认、禁止缓存和日志。

## 4. 目标架构

### 4.1 分层

```text
UI 页面
  ├─ SnapshotController（可见性 / dirty / 去抖 / 请求代次）
  ├─ CommandApi（业务意图 / revision / idempotency）
  └─ AppState（服务器、会话、连接生命周期）
        │
        ├─ HTTP Transport：AuthClient + 能力 + 快照 + 缩略图 + 文件
        └─ RealtimeClient：WSS hello/ready/ping/state/log/command
              └─ IoRealtimeTransport：dart:io WebSocket + TLS 策略
```

职责边界：

- **HTTP 只读快照**：页面数据和筛选、分页状态由 HTTP 返回，避免把客户端变成
  第二套业务状态机。
- **WSS 写命令**：所有用户可见的业务写操作都从 `CommandApi` 进入实时连接。
- **WSS 失效通知**：页面只消费与自身 scope 相关的事件，然后刷新快照。
- **WSS 日志**：运行日志复用同一连接，不再单独建立 SSE。

### 4.2 启动与会话流程

1. 读取服务器配置和本地凭据。
2. HTTP 登录或刷新，随后 `whoami`。
3. HTTP `GET /api/v2/capabilities`，校验协议、路径、v2 与任务能力。
4. 建立 WSS，发送 `hello`，等待 `ready` 并保存命令目录、`epoch`、`sequence`。
5. `ready` 后读取当前可见页面快照；未显示页面标记为 stale。
6. 进入 `online`。状态事件只把相关页面标记为 dirty，并做短时间合并刷新。
7. 断线进入 `reconnecting`，保留页面内容，按 1–30 秒抖动退避重连。
8. 重连成功后清空旧水位、重新读快照；旧连接和旧响应一律丢弃。

建议的实时状态：

```dart
enum RealtimeStatus { connecting, online, reconnecting, offline }
```

不再存在 `polling` 状态。

### 4.3 能力不兼容

登录成功后若能力探测失败，显示专用「服务器版本不兼容」页：

- 说明最低要求是 EhBot R97/P10，推荐 R101。
- 提供「重试能力探测」「更换服务器」「退出登录」。
- 不进入主页面，不建立 SSE，不启动任何轮询。

### 4.4 网络与 TLS

- 从 `baseUri` 派生：
  - `https` → `wss`
  - `http`（必须已显式允许明文）→ `ws`
- 使用 `dart:io WebSocket.connect`，通过 `customClient: HttpClient` 复用现有
  自签证书与 SHA-1 指纹 pin 策略。
- 反代前缀只拼接一次：
  - 优先使用能力返回的 `deployment_prefix` + `/ws/ui`；
  - 若 `realtime.path` 已包含前缀，不再重复拼接 base path。
- 握手只加 `Authorization`；不设置 Cookie、CSRF、Origin。
- 不在日志、异常上报、错误对话框或持久化队列中记录 access token、API Key、
  Cookie、命令 body 中的秘密字段。

### 4.5 连接与服务器生命周期

`AppState` 持有 `RealtimeClient`，不再由 `HomeShell` 创建：

- 登录成功/恢复会话后启动。
- 切换服务器、保存服务器参数、退出登录、清空会话时先关闭旧连接，再清理
  pending commands 和快照请求。
- 每次 `_activate` 递增 `connectionGeneration`；旧代的命令结果、快照响应和
  事件一律丢弃。
- App 回前台：确认连接，必要时重连并校正当前页面快照。
- App 退后台：不启动定时轮询；由系统挂起或连接自然断开，回前台再恢复。

### 4.6 命令层不变量

新增统一身份对象：

```text
WorkVersion(work_id, revision)
TaskVersion(task_id, revision, generation, attempt_id)
SettingsVersion(scope, revision)
IdempotencyKey(user intent id)
```

规则：

- 每次用户动作只生成一次 `idempotency_key`，绑定完整规范化 payload。
- 冲突、超时、结果未知时保留原 payload、原草稿、原 key；
  只有用户明确选择「使用最新状态重新提交」才换 revision + 新 key。
- 批量操作生成逐项 `versions`，例如：

```json
{
  "action": "approve",
  "candidate_ids": [42, 43],
  "idempotency_key": "review-intent-1",
  "versions": {
    "42": {"work_id": "...", "expected_revision": 4},
    "43": {"work_id": "...", "expected_revision": 2}
  }
}
```

- 服务端返回 409 `REVISION_CONFLICT` 时，客户端只提示并重新读取；不自动改版本。
- 服务端返回 428 `PRECONDITION_REQUIRED` / `IDEMPOTENCY_KEY_REQUIRED` 视为客户端
  契约错误，必须修代码，不应通过猜测补字段。
- `command.result` 带 `operation_id` / `removal_id` 时，界面展示「已受理」并查询
  操作状态；不把 202 渲染成「已完成」。

### 4.7 写操作结果未知

若发送命令后连接断开、命令帧未收到 `accepted`、或等待超时：

- 标记该次意图为 `unknown`，不是失败，也不是成功。
- 不自动用新 `request_id` 或新幂等键重发。
- 立即尝试读取相关快照；若响应带操作 ID，则按需查询该**操作查询接口**
  （用户触发或页面打开时查询；不建立全局业务列表轮询）。
- 用户在确认提示后可「以同一意图重试」；重试沿用原幂等键。

## 5. HTTP 与 WSS 边界

| 用途 | 通道 | 说明 |
|------|------|------|
| login / refresh / logout / whoami | HTTP | 保留现有鉴权端点 |
| capabilities | HTTP | 登录后能力探测 |
| summary / candidates / work / queue / history / downloaded / logs / settings 快照 | HTTP GET | 事件后的权威读取 |
| 缩略图、文件、导出 | HTTP | 协议明确不进入命令目录 |
| 账号 reveal | HTTP | 服务端明确 HTTP-only；显式确认、禁止缓存 |
| 审核、删除、作品动作、任务动作、设置、账号命令 | WSS | 带 revision + 幂等键 |

明确不做：

- 不保留 `/api/v1/events` SSE。
- 不保留 `/api/v1/logs/stream` SSE。
- 不保留 `LiveStatus.polling`。
- 不在 WSS 不可用时把写命令改走 HTTP。
- 不使用「App 版本号」判断后端能力。

## 6. 数据模型改造

### 6.1 新增

- `Capabilities`
  - `apiVersions`
  - `taskApi` / `settingsApi` / `accountsApi`
  - `deploymentPrefix`
  - `realtimePath` / `realtimeProtocol` / `replay` / `resync`
  - `sources[]`
  - `taskCapabilities`
  - `secretResponses`
- `RealtimeReady`
- `RealtimeStateEvent`
- `RealtimeLogEvent`
- `CommandAccepted` / `CommandResult` / `CommandError`
- `OperationView`
- `RemovalView`
- `TaskView`
- `ArtifactView`
- `AttemptView`
- `SettingsSnapshot`
- `AccountView`
- `CommandReceipt`

### 6.2 扩展

- `Candidate`：`workId`、`revision`、服务端 `displayTitle`、`filterNote`。
- `JobSummary`：`taskId`、`revision`、`generation`、`attemptId`、
  `pendingOperation`、`displayTitle`。
- `DownloadedWork`：`workId`、`revision`、`jobId`、`packJobId`。
- `WorkDetail`：`workId`、`revision`、`archiveMetadata`、`metadataEditor`、
  `archive`、`ingestOperations`。
- `MetadataEntry`：补齐 `editable`、`source`、`lockField`、`lockAvailable`。
- `StatusView`、`SourceAction`、`TorrentState` 按最新快照补字段。

### 6.3 删除/更正

- 删除 `requestRevision` 与所有 `needs_revision` UI。
- 删除 `kJobStopSeeding`、`canStopSeeding`、停止做种按钮和测试。
- `WorkActions` 注释删除 `needs_revision`；`edit_archive_path` 改为真实可用动作。
- `ClientMeta` 删除 polling 字段，或至少禁止实时层读取。
- 旧整数 `job_id` 只作为 `legacyJobId` 兼容字段；业务动作使用 `taskId`。

### 6.4 `TaskView`

至少解析并保留：

- `task_id` / `legacy_job_id` / `candidate_id`
- `kind` / `stage` / `provider`
- `status` / `revision` / `generation`
- `priority` / `current_attempt_id`
- `progress` 与 `error_code`
- `actions`（`pause` / `resume` / `retry` / `cancel` / `switch_source` / `priority`）
- `attempts[]`
- `operations[]`
- `removals[]`
- `artifacts[]`
- `pack_intent`
- `blocking_operations[]`
- `created_at` / `updated_at`

活动列表可继续读取 `/api/v1/queue` 以获得服务端分组和 attention 汇总，但：

- 每行的身份、动作和版本来自 `job_summary.task_id/revision/actions`。
- 任务详情、操作追踪和 v2 深链读 `/api/v2/downloads/{task_id}`。
- 不再根据 `torrent.waiting_for_peers` 自造切源入口。

## 7. 页面与交互影响

### 7.1 登录

- 密码页新增用户名输入框，提交 `{username, password, label?}`。
- 可按服务器记住上次用户名，但密码永不持久化。
- API Key 页不变。

### 7.2 实时状态

- 顶部横幅展示 `connecting / online / reconnecting / offline`。
- `reconnecting` 显示当前退避状态与「立即重试」。
- `offline` 时保留已加载内容，禁用所有业务写按钮并说明原因。
- 手动下拉刷新仍允许；它不是轮询。

### 7.3 冲突与未知

- 409 冲突：显示「作品/任务/设置已变化」，提供「重新读取」；
  表单草稿和原幂等键保留。
- 结果未知：显示「操作可能已受理」，提供「查看当前状态」；
  用户明确确认后才可沿用原键重试。
- 禁止静默重载表单后自动再提交。

### 7.4 页面刷新

- 工作台：`candidate`、`download`、`conversion`、`connection`。
- 候选列表：`candidate`；详情另按 `candidate_id`。
- 活动：`download`、`conversion`。
- 已下载：`download`、`conversion`、`candidate`。
- 设置连接区：`connection`。
- `refresh` 事件按 `data.path` 前缀映射到具体页面或作品。
- 同一页面 150–300ms 内合并多次失效；隐藏页只标 dirty，激活时刷新。

### 7.5 日志

- 日志页历史仍读 `GET /api/v1/logs`。
- 实时条目来自 `RealtimeClient.logs`。
- 首次连接回放最近 50 条；按 `(epoch, sequence)` 去重。
- 暂停只暂停渲染，后台保留有界缓冲。
- 重连发现日志 sequence 缺口或 epoch 变化时，重新读取日志快照。

### 7.6 作品与任务

- 详情动作全部用 `WorkDetail.workId + revision`。
- 批量审核/删除使用列表项的逐项版本。
- 打包要带精确 `input_artifact_id`。
- 任务动作使用 `TaskView.taskId + revision`，切源目标只取服务端 `actions` /
  capabilities 允许的值。
- 移除「要求修订」「停止做种」。
- 任务已受理后显示 operation/removal 状态，不在本地推断文件已删除或远端已停止。

### 7.7 设置与账号

- 九区全部改为「读取快照 → 编辑草稿 → 发版本化命令 → 读取回执 → 重新 GET」。
- 写回执只用于展示状态和版本，不直接替换快照。
- 账号区列出多个账号及运行状态；创建/改名/编辑/启停/删除/测试/登录流程
  全部走 `/api/v2/accounts/commands`。
- 账号 reveal 显式二次确认，明文不缓存、不进日志。
- API Key 生成明文只在一次性对话框中展示。

## 8. 分期方案

一期一个 commit；每期同步代码、测试、`CONTRACT.md`、`README.md`、
`progress.md`、`PHASES.md`。

### M10-A：契约与身份基础

- 重写 `AgentHelp/CONTRACT.md` 到 R101：
  - capabilities / v2 task
  - WSS
  - revision / 幂等 / 操作回执
  - 删除 `needs_revision`、`stop-seeding`
  - 九区设置与账号命令
- 新增 `Capabilities`、`WorkVersion`、`TaskVersion`、`SettingsVersion`、
  command envelope、operation/removal 模型。
- `Candidate` / `JobSummary` / `DownloadedWork` / `WorkDetail` 补身份与版本字段。
- 登录支持用户名，`whoami` 补 `revision`。
- 删除 `requestRevision`、停止做种常量与模型。
- 暂不改实时实现，保证该期可独立测试。

### M10-B：WSS 实时层（主改造）

- 新增 `RealtimeClient` + 可注入的 `RealtimeTransport`；生产实现用
  `dart:io WebSocket.connect`。
- 实现 hello、ready、命令目录、ping/pong、15/45 秒水位、1–30 秒抖动重连。
- 实现 `CommandBus`：request_id、accepted/result/error、超时、串行队列、
  结果未知语义。
- 实现 `SnapshotCoordinator`：ready/重连校正、scope 失效、去抖、请求代次。
- `AppState` 持有连接；切服务器/退出/回前台生命周期接上。
- 日志合并到同一 WSS，删除 `events.dart`、`live_monitor.dart`、
  `LiveStatus.polling` 和所有页面 tick 定时器。
- 加入能力不兼容页；SSE/轮询彻底移除。
- 修复 refresh single-flight；WSS 认证失败（可识别的 4401/4403 或握手被拒）时
  用 HTTP 核验一次，确属 access 过期才刷新并重连；API Key 不刷新。

### M10-C：作品动作面

- 审核 / 驳回 / 删除 / 重新排队全部带逐项版本与幂等键。
- 元数据保存、锁定、抓取元数据、抓取操作查询。
- 打包 / 重新打包带 `work_id + revision + input_artifact_id`。
- 按来源拉取、归档路径、已下载改名带作品身份与版本。
- 删除要求修订。
- 详情页冲突、未知结果、草稿保留和重新读取交互。

### M10-D：活动、已下载与摄取操作

- 任务身份全面切到 UUID `task_id`，补 `TaskView`。
- 任务动作、批量、优先级、切源改走 `v2.*` 命令。
- operation / removal 查询与展示。
- 已下载批量操作补逐项版本与幂等键。
- 手动添加补幂等键和 `manual_add_operation_id` 查询。
- 去重执行补 `plan_id` 和幂等键。
- 删除停止做种。
- 活动标题使用 `display_title`；分页参数按服务端规则。

### M10-E：设置与账号

建议拆成四个可独立验收的子阶段：

- **E1 写入框架**：`SettingsSnapshot + settings_versions`，固定回执后重新 GET；
  系统、解析规则。
- **E2 来源与连接**：来源单条/批量版本与回执；连接区迁到账号注册表。
- **E3 自动审批、归档、路径**：规则 AST、逐条版本、profile/toolchain、
  路径模板与规则。
- **E4 AI 与密码库**：供应商/Key/模型/链的多版本 CAS、网络操作查询、
  密码库与一次性明文。

若审阅认为 E2 的账号 UI 过大，可把账号管理单独拆成 M11；但不得继续使用旧的
单连接写语义，最多暂时只读展示。

### M10-F：收尾与发布

- 删除所有过期文档和测试引用。
- 全量补齐实时、CAS、设置、账号测试。
- 真实 HTTPS + 反代前缀 + WSS 的端到端验收清单。
- `README.md`、`PHASES.md`、`progress.md`、`CHANGELOG.md`、`AGENTS.md` 同步。
- 按运营者指定把 App 版本升到 **v0.4.0+1**；M10-A..E 不单独改版本。

## 9. 测试计划

### 9.1 实时传输

- `ws` / `wss` URI 派生，反代前缀只拼一次。
- Bearer 握手头存在；没有 Cookie、CSRF、Origin；凭据不进入 URL。
- hello 超时、协议不符、错误 `error` 帧。
- ready 保存 epoch/sequence/commands/心跳。
- ping → pong；45 秒无消息判定断线；发送超时。
- 退避基数、抖动和 30 秒上限。
- epoch 变化、sequence 跳变、heartbeat 水位超前触发校正。
- 切服务器/退出关闭旧连接，旧代响应不落入新状态。
- access 过期刷新一次后重连；refresh 失败回登录；API Key 401 不 refresh。

### 9.2 命令

- `command.accepted` 不结束 Future。
- `command.result` 200/202 解析；202 保留 `operation_id`。
- `command.error` 映射 `ApiException`。
- 重复 request_id、`COMMAND_BUSY`、256 KiB 限制、非法帧。
- 断线时 pending 命令变为 unknown，不自动重发。
- 同一用户意图重试沿用原幂等键，但换新 request_id。
- 所有作品/任务/批量/设置/账号 payload 的 revision、versions、key 断言。

### 9.3 快照与页面

- ready/重连后只刷新当前可见页，隐藏页标 dirty。
- scope → 页面映射与 150–300ms 去抖。
- 快照读取期间到达新事件时再读一次。
- 旧请求代次、旧筛选、旧服务器响应被丢弃。
- 页面不再创建周期 Timer；用 fake async 证明无轮询。
- 日志 50 条回放、`(epoch,sequence)` 去重、缺口校正。

### 9.4 业务 UI

- 登录用户名必填与错误提示。
- 409 保留草稿和原 key；不自动换版本。
- 202 显示「已受理」并查询操作。
- 写按钮在 `offline/reconnecting` 时禁用。
- 要求修订、停止做种入口不存在。
- 设置保存后重新 GET，不把回执当快照。
- 账号 reveal 只走 HTTP 且一次性展示。

### 9.5 回归与基线

- `flutter analyze` 零告警。
- `flutter test` 从 204 tests / 0 failed 只增不减。
- `rg` 检查不再出现 `SseEventSource`、`LiveStatus.polling`、`events` 实时路径、
  `needs-revision`、`stop-seeding` 等业务引用。
- 运营者用真实反向代理验证：
  - HTTPS/WSS；
  - 自签证书与指纹 pin；
  - 密码登录与 API Key；
  - 30 秒断网重连；
  - app 前后台切换；
  - 409/428/202/unknown；
  - 切换服务器。

## 10. 文档同步

- `AgentHelp/CONTRACT.md`：整体重写，不再只写 `/api/v1`。
  建议章节：通用、鉴权、能力、WSS、命令与回执、快照、CAS/幂等、
  v2 任务、设置、账号、已删除能力。
- `AgentHelp/AGENTS.md`：实时不变量改为 WSS、无 SSE、无轮询；
  更新最低服务端版本与测试基线。
- `AgentHelp/M4_REALTIME_PROPOSAL.md`：标注已被 M10 取代，保留历史记录。
- `README.md`：功能、最低服务端、WSS、无轮询、设置/账号能力。
- `AgentHelp/PHASES.md` / `progress.md`：新增 M10-A..F 与基线。
- `CHANGELOG.md`：v0.4.0。
- `pubspec.yaml`：v0.4.0+1。
- 版本规则以 `AgentHelp/AGENTS.md` 的「版本号策略」为准：本次由运营者指定
  `v0.4.0`；之后未经指定只升 patch，纯文档变更不升版本。

## 11. 风险与备选

### 11.1 主要风险

- 服务端 R100/R101 尚未验收；移动端必须等运营者真实环境验收后再发布。
- WSS 在移动网络、锁屏、反代超时下会出现半开连接，需要客户端 watchdog。
- 设置/账号 CAS 面很大，一次做完容易产生难审的大提交，因此拆 E1–E4。
- 断线时命令结果天然存在「未知」；UI 必须诚实表达，不能假装成功或失败。
- `dart:io` WebSocket 不适用于 Flutter Web；本项目当前不做 Web，需保持该边界。

### 11.2 否决的备选

- **SSE 与 WSS 并存**：两套一致性语义，违背运营者要求，否决。
- **WSS 不可用时 HTTP 轮询/写回退**：会重新引入旧并发问题，否决。
- **只补 revision 字段、不改实时层**：无法解决事件一致性和连接生命周期，否决。
- **冲突后自动获取最新版本并重试**：可能覆盖他人操作，否决。
- **所有事件到达就全页刷新**：请求风暴且丢筛选状态，否决。
- **第三方 Socket.IO 协议**：服务端是原生 JSON WebSocket，协议不匹配，否决。

## 12. 验收标准

- 服务端能力不兼容时明确停下，不进入旧协议。
- 生产 HTTPS 只连 `wss`，只有显式允许明文时才连 `ws`。
- 全仓库无 SSE 客户端、无状态轮询 Timer、无 `polling` 降级。
- 所有业务写命令带正确身份、revision 和幂等键。
- 断线、重连、epoch 变化、sequence 跳变、前后台切换都能校正快照。
- 409/428/202/结果未知有明确且不丢草稿的交互。
- 设置九区与账号生命周期按服务端回执模型工作。
- `flutter analyze` 零告警，`flutter test` 基线只增不减。

## 13. 请运营者确认

1. 是否接受「WSS 唯一实时通道，无 SSE/轮询/HTTP 写回退」？
2. 是否接受最低服务端 **R97/P10**、目标验收 **R101**？
3. 是否按 M10-A..F 顺序推进，并把设置/账号拆成 E1–E4？

版本号已由运营者指定：M10-F 升 `v0.4.0+1`；后续未经指定只升 patch，
纯文档变更不升版本。

审阅通过前不修改业务代码。
