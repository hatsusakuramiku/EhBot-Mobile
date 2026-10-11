# M9 提案 — 运营者实测反馈五项修订（v2，按 EhBot `7ebab47` 核对）

> 状态：**v2 重写**。v1 把「删除 / 重打包 / 重新下载 / 重新排队 / 手动添加 / 设置写入」
> 判成「后端只在网页层」——**那是错的**：当时读的是过时且不完整的源码。EhBot 随后
> 补齐了 R64–R69 六期（见 EhBot 仓库 `AgentHelp/MOBILE_API_COMPLETION_PROPOSAL.md`），
> 上述动作现在全部有 `/api/v1` 端点。本文件已按 **EhBot `7ebab47` 的实际源码**重写。
>
> 依赖事实以本仓库 `AgentHelp/CONTRACT.md`（同批更正，commit `d50d398`）为准：
> §5 端点表、§5.2 `/works/{id}` 的 `actions` 真实形状、§7「已就绪 / 仍需后端」两张表。

## 1. 需求（运营者原话，2026-10-11 实测 v0.2.0 APK）

1. 「作品详情页操作按钮不要放在最下面，应该做成底栏固定，不要划到最下面才能进行操作」
2. 「设置页面完全不可用，根本没有做好适配，无法编辑设置」
3. 「需要能自定义主题模式、配色方案自由选择」
4. 「功能实现不完善，没有删除相关功能，需要加上」
5. 「下载方式切换，重新下载等功能也没有实现」

补充约束（运营者后续两条指示）：

- **行为与 WebUI 一致**；**EhBot 后端已经实现的，要与 EhBot 一致**（不自造语义）。
- **设置不按账号管理**：EhBot 是单用户系统（现在与将来都不考虑多用户），
  所以设置页是「服务器配置 + 本机偏好 + 后端分区设置」，不是账号管理台。

## 2. 现状（按当前源码核对的四条真 bug）

### 2.1 动作调用整体打错端点（最严重）

`lib/ui/candidate_detail_page.dart::_jobAction()` 打的是：

    POST /api/v1/jobs/{widget.candidate.id}/{action}

- **路径参数错**：`/jobs/{job_id}/…` 要 **job id**，传的是 **candidate id**。
- **动作名错**：客户端传 `delete` / `delete_files` / `repack` / `reconvert` /
  `switch_source_ehentai` / `switch_source_telegram` / `requeue` /
  `fetch_metadata` / `convert` / `needs_revision`；而
  `POST /api/v1/jobs/{job_id}/{action}` 只认
  `{retry, pause, resume, cancel, stop-seeding}`，其余 400 `ACTION_UNKNOWN`。
  这些名字属于**完全不同的端点**（`candidates/batch`、`downloaded/batch`、
  `works/{id}/requeue`、`jobs/{id}/switch-source`）。
- **`WorkDetail` 把 `jobs` 丢了**：只解析 `jobCount`，不保留 job id / 状态 / 每个任务
  自己的 `actions`。切源与任务操作都拿不到 job id。

### 2.2 按钮可见性判定读的是后端不返回的键

`/works/{id}` 的 `actions` 真实形状（EhBot `app/api/works.py::work_actions`，已写入
`CONTRACT.md` §5.2）：

    approve / reject / needs_revision / requeue / edit_metadata /
    fetch_metadata / convert / reconvert / edit_archive_path / sources[]

`delete` / `delete_files` / `repack` / `switch_source_*` **这些键根本不存在**。
客户端 `detail.can('delete')` 取不到 → 删除、切源按钮**一个都不会渲染**。

### 2.3 M8 期引入的端点错误（三处）

| 位置 | 我写的 | 实际 |
|------|--------|------|
| `dedupPlan` / `dedupApply` | `/api/v1/dedup/plan`、`/api/v1/dedup` | `/api/v1/downloaded/dedup`（GET / POST） |
| `manualAdd` 重复处理 | 按 200 + `existing_candidate_id` 解析 | 重复是 **409** `CANDIDATE_DUPLICATE`，id 在 `error.details.existing_candidate_id` |
| `AuthClient` | 只有 get / post / patch | R67–R69 的设置写入是 **PUT**，缺 `putJson` |

`logs` / `logs/stream` / `settings/{section}` 路径是对的（`CONTRACT.md` §7 已更正）。

### 2.4 设置页是「死的 dump」

M8-E 交付的是「分区导航 + 把后端 JSON 摊平成只读 key-value 列表」，且
`/api/v1` 当时只有读。现在 `connections` / `system` / `passwords` 三区**已有 PUT**，
其余六区仍然只有读——所以「完全不可用、无法编辑」是这一期的主修目标之一。

## 3. 后端事实（EhBot `7ebab47`，全部接受 Bearer；Bearer 免 CSRF）

`deps.require_session` 接受 `Authorization: Bearer`，`deps.require_csrf` 对 Bearer 豁免。

**已就绪（本期要用）**

| 能力 | 端点 | 形状 |
|------|------|------|
| 通过 / 驳回 | `POST /api/v1/candidates/batch` | `{action:"approve"\|"reject", candidate_ids}` |
| **彻底删除 / 删文件** | `POST /api/v1/candidates/batch` | `{action:"delete"\|"delete-files", candidate_ids}`（R64） |
| **重新排队** | `POST /api/v1/works/{candidate_id}/requeue` | `{note?}`（R65） |
| **手动添加** | `POST /api/v1/candidates/manual` | `{url}`；重复 → **409** + `details.existing_candidate_id`（R66） |
| 任务操作 | `POST /api/v1/jobs/{job_id}/{retry\|pause\|resume\|cancel\|stop-seeding}` | 空 body |
| 任务批量 | `POST /api/v1/jobs/batch` | `{action, job_ids, provider?, priority?}` |
| 优先级 | `POST /api/v1/jobs/{job_id}/priority` | `{priority:int}` |
| **切换下载来源** | `POST /api/v1/jobs/{job_id}/switch-source` | `{provider}` → `{job_id(new), provider}` |
| **重新下载 / 重新打包 / 移除** | `POST /api/v1/downloaded/batch` | `{action:"redownload"\|"repack"\|"remove", candidate_ids, delete_files?, repack?}` |
| 去重计划 / 执行 | `GET` / `POST /api/v1/downloaded/dedup` | 计划只读，POST 执行 |
| 连接区写入 | `PUT /api/v1/settings/connections` | 7 个 action（R67） |
| 系统区写入 | `PUT /api/v1/settings/system` | 只写 body 里出现过的字段；空 body → 400（R68） |
| 密码库写入 | `PUT /api/v1/settings/passwords` | `{action:"add"\|"delete"\|"api-key-generate"\|"api-key-revoke"}`（R69） |
| 设置读取 | `GET /api/v1/settings/{section}` | 九区快照 |

常量（客户端照抄后端，不再猜）：

- `REVIEW_BATCH_ACTIONS = {approve, reject}`
- `CANDIDATE_DELETE_ACTIONS = {delete, delete-files}`
- `DOWNLOADED_BATCH_ACTIONS = {repack, remove, redownload}`
- `JOB_ACTIONS = {retry, pause, resume, cancel, stop-seeding}`（+ 带参的 `switch-source` / `priority`）
- provider：`TELEGRAM` / `TELEGRAM_USER` / `EXHENTAI` / `TELEGRAPH` / `EH_TORRENT` / `CONVERSION`
- `actions.sources[].action` 是**网页路径**（`/candidates/{id}/…`），**不能直接调**；
  客户端要用 `provider.code` 走 `/jobs/{job_id}/switch-source`。

**仍需后端（客户端渲染为禁用态 + 一行说明，不撞 404）**

重获元数据、四个来源拉取、打包 / 重新打包、需修订、已下载改名、设置六区写入
（`sources` / `parse` / `auto-approval` / `archive` / `paths` / `ai`）。
清单与申请路径在 `CONTRACT.md` §7 与 EhBot `MOBILE_API_COMPLETION_PROPOSAL.md` §6。

## 4. 方案（分期）

原则：**后端已有的接对；后端没有的明确禁用并说明；不自造语义、不撞 404。**

### M9-A · 主题模式 + 配色方案（第 3 项，纯本地）

- 新增 `lib/state/theme_store.dart`：`ThemeSettings{mode, seed}` +
  `ThemeStore`（`SharedPreferences`，键 `ehbot.theme_mode` / `ehbot.seed_color`）。
- `AppTheme.light(seed)` / `dark(seed)` 接受运行时 seed；`AppState` 增
  `themeSettings` + `setThemeMode()` / `setSeedColor()`，`bootstrap()` 里加载。
- 设置页新增「外观」区：`SegmentedButton`（跟随系统 / 浅色 / 深色）+
  8 个预设色圆点 + 色相滑块（不引第三方取色器）。
- **不引入 `dynamic_color`**（M7 已因跨包类型冲突移除）。

### M9-B · 数据层重写（无可见变化，但它是 C/D/E/F 的地基）

- `models.dart`：
  - 新增 `WorkJob`（`jobId` / `state` / `providerCode` / `providerLabel` /
    `actions` / `errorMessage` / `priority` / `artifactPath` …），`WorkDetail.jobs`
    真正解析（保留 `jobCount`）。
  - `WorkActions`：平铺布尔 + `sources: List<SourceAction>`（`providerCode` /
    `providerLabel` / `available` / `hint`），`can(name)` 保留。
  - `WorkDetail` 补 `warningHint` / `warnings` / `filterOrigin` / `exGid` /
    `previewUrl` / `torrentCount` / `torrentHash` / `magnetUrl` / `messages` /
    `rawMetadata` / `archiveJobId` / `archivePath`（后端返回的下一份归档路径）。
- `ehbot_api.dart`：
  - 修 `dedupPlan` / `dedupApply` 路径；`manualAdd` 认 409 为「已存在」。
  - 新增 `switchSource`、`jobAction`（job id）、`jobPriority`、`requeueWork`、
    `deleteCandidates`、`downloadedBatch`、`putSettingsSection`。
- `AuthClient` 增 `putJson`（R67–R69 要 PUT）。
- 测试基线只增不减；新增 `test/api/*` 用例覆盖每条新方法。

### M9-C · 详情页：固定底栏 + 真实动作 + 内容补全（第 1、4、5 项）

- `Scaffold.bottomNavigationBar` 做成固定操作底栏（对齐 WebUI 的 `position: sticky`
  动作条）：横向可滚动，主操作（通过 / 驳回）在最左，危险操作（彻底删除 /
  彻底删除并删文件）在最右。
- 按钮集合按 §3 的真实键渲染：`approve` / `reject` / `needs_revision`(禁用) /
  `requeue` / `fetch_metadata`(禁用) / `convert`·`reconvert`(禁用) /
  `sources[]`（可用的调 `switch-source`，不可用显示 `hint`）/ 彻底删除 ×2。
- `EXHENTAI` 那条可用时**先确认「会消耗 GP」**（与 WebUI 文案同义）。
- 每个任务一张卡：状态 + provider + 进度 + 备注 + **该任务自己的动作**
  （`retry` / `pause` / `resume` / `cancel` / `stop-seeding`，来自 `job_summary.actions`）。
- 正文补全（回应「内容太少」）：告警 chips + `warning_hint`、`filter_origin` /
  `filter_reason`、`ex_gid` / 预览页 / 种子数 / magnet、归档路径、消息与附件、
  原始元数据、时间线。
- 删除：两个入口对应 `delete` / `delete-files`，两次不同的确认文案
  （「记录、消息、元数据与审核历史都会删除，文件保留」vs「并删除已下载的压缩包与 CBZ」）；
  取消状态由服务端判定，被拒时按 `skipped` 逐条提示。
- **删掉 `prev_id` / `next_id` 死代码**：JSON 详情快照不返回这两个键（只有 HTML 页面有），
  当前按钮永远不会出现。本期移除，并在 §7 记为待办（后续用列表上下文推导）。

### M9-D · 已下载 / 活动 / 去重（第 4、5 项）

- 已下载列表接多选（沿用候选页的模式）：**重新下载** / **重新打包** /
  **移除记录** / **移除并删文件**（两套确认文案，走
  `POST /api/v1/downloaded/batch`）。
- 行内快捷动作：`打包` / `重新打包`（`repack`）、`重新下载`（`redownload`）。
- 活动页每个任务行加任务操作（与 C 同一套控件，抽成共享 widget）。
- 去重页改走 `/api/v1/downloaded/dedup`（GET 计划 / POST 执行）。

### M9-E · 设置页（第 2 项）

- 顶部「外观」（M9-A，立即可用）+「服务器」→ 跳 `ServersPage`（M8-A 已可编辑）。
  设置页**不做账号管理**：单用户系统，只有「当前凭据类型 / 到期时间」一行只读信息。
- **可写表单**（三个已有 PUT 的分区）：
  - 连接：Telegram Bot Token 配置 / 断开；Telegram 用户登录（api_id + api_hash + phone）
    → 验证码 / 两步验证 → 断开；ExHentai Cookie 三项配置 / 断开。
  - 系统：并发、轮询间隔、时区、自动审批间隔、移动端 token 时长、日志等级、
    下载来源优先级（按后端 `bounds` 校验）。
  - 密码库：归档密码增删（含 priority / enabled）、API Key 生成（**明文只显示一次**）/
    撤销。明文只用一次性对话框展示，不进日志。
- 其余六区：**结构化只读**（按真实字段分组，不再摊平成 `a.b.c` 长条）+
  一行「需要后端 `/api/v1` 写入端点」。

### M9-F · 候选列表：删除 + 手动添加更正

- 候选多选栏增加**彻底删除 / 彻底删除并删文件**（`candidates/batch` 的
  `delete` / `delete-files`，两次不同确认）。
- 手动添加：重复时走 409 分支，提示「作品已存在」并给「查看已有候选 #id」按钮。
- 行内「重新排队」入口：`actions.requeue` 为真的候选（`REQUEUEABLE_STATUSES`）。

## 5. 界面影响

- 详情页：操作区从滚动内容末尾 → **固定底栏**；按钮集合按真实 `actions` 渲染；
  正文新增告警 / 画廊 / 种子 / 归档 / 消息 / 原始元数据 / 任务卡。
- 已下载页 / 活动页：新增多选与批量动作、行内打包 / 重新下载 / 任务操作。
- 设置页：新增「外观」（可编辑）、「服务器」（可跳转）、三区可写表单、六区结构化只读。
- 候选页：多选栏新增删除。
- 移除：详情页 `prev_id` / `next_id` 按钮（后端 JSON 不提供，永远是死按钮）。

## 6. 后端契约影响

- `CONTRACT.md` 已在本批（`d50d398`）更正；本期**不改后端**，只按已就绪端点接线。
- 若后续要让「重获元数据 / 四来源拉取 / 打包 / 需修订 / 改名 / 设置六区写入」
  也在 App 里可用，需要在 EhBot 仓库再开一期（走
  `MOBILE_API_COMPLETION_PROPOSAL.md` §6），本文档不预判其形状。

## 7. 待办（本期不做，已记录）

1. 详情页「上一 / 下一作品」：JSON 详情不含 `prev_id` / `next_id`，
   需由列表上下文（候选 / 已下载列表的相邻项）推导后传入。
2. 需后端补口的那批动作（见 §3 下半张表）。
3. 设置六区写入（`sources` / `parse` / `auto-approval` / `archive` / `paths` / `ai`）。

## 8. 测试计划

- 每期：`flutter analyze` 零告警 + `flutter test` 只增不减（收尾基线见 `progress.md`）。
- M9-A：主题模式 / 配色持久化 + 设置页外观区渲染（3 条）。
- M9-B：`WorkDetail.jobs` / `WorkActions.sources` 解析、每个新 API 方法的路径与 body
  （用 `MockClient` 断言 URL 与 JSON）。
- M9-C：底栏按钮按 `actions` 渲染、job id 正确（回归：**不允许**再打
  `/jobs/{candidate_id}/…`）、删除两条确认文案、切源 provider 正确、
  任务动作按钮来自 `job_summary.actions`。
- M9-D：已下载批量 action / `delete_files` 正确；去重打 `/downloaded/dedup`。
- M9-E：三区表单提交 body 正确；API Key 明文只在对话框出现一次。
- M9-F：删除走 `candidates/batch`；手动添加 409 → 「查看已有候选」。

## 9. 要同步的文档

- `AgentHelp/CONTRACT.md`：已更正（本批 `d50d398`）；本期若发现新事实继续补。
- `README.md`：功能清单（详情底栏、已下载批量、设置可写分区、外观）。
- `AgentHelp/progress.md`：每期一条 M 编号条目 + 基线数字。
- `AgentHelp/PHASES.md`：M9-A..F 状态与指针；顺手把「B1/B2 待实施」等过时表述改掉。

## 10. 分期与依赖

| 期 | 内容 | 后端依赖 | 立即可用 |
|----|------|---------|---------|
| M9-A | 主题模式 + 配色 | 无 | 是 |
| M9-B | 数据层重写（jobs / 真实 actions / 新端点 / PUT） | 无 | 是 |
| M9-C | 详情页固定底栏 + 真实动作 + 内容补全 | 无（R64/R65 已就绪） | 是 |
| M9-D | 已下载 / 活动 / 去重 | 无（已就绪） | 是 |
| M9-E | 设置：外观 + 服务器 + 三区写入 + 六区只读 | 无（R67–R69 已就绪） | 是 |
| M9-F | 候选删除 + 重新排队 + 手动添加更正 | 无（R64/R66 已就绪） | 是 |

运营者已批准按此顺序开工（2026-10-11）。一期一个 commit，代码 / 测试 /
`README.md` / `progress.md` / `PHASES.md` 一起提交。
