# M6 提案 — 可点击导航 + 详情页丰满 + 设置入口

> 状态：**草稿，待运营者审阅**（AGENTS.md "先写方案，运营者审阅，再动手"）。
> 验收基线要更新；M6 落地后基线 `flutter test` 用例数会增加。

## 1. 需求

运营者在真机/模拟器上点开 M3 收尾后的 App，发现四个可见行为缺口：

1. 工作台的「候选项 / 待办」chip 点不动 — 卡片只是 `Chip`，没有 onTap。
2. 候选列表行点不动 — `Card` 渲染了封面 / 标题，但没 push 详情。
3. 活动页（队列 / 打包 / 历史）的 job 行点不动。
4. 已下载页的行点不动。
5. 设置入口不存在 — 想知道当前服务器 URL、Token 类型、连接状态都无处查看；退出登录只能走 AppBar 的登出图标。
6. 作品详情页内容太少 — 只显示了 `title / stage / status / 元数据 / 时间线 / 通过 / 退回`，比 web UI (`E:\Github\EhBot\app\web\templates\work_detail.html`) 少一截：
   - 没有「下载 / 打包 / 转换 / 重排队 / 重新获取元数据」按钮；
   - 没有 4 个来源切换按钮；
   - 没有「彻底删除 / 彻底删除并删文件」；
   - 没有「上一作品 / 下一作品」导航；
   - 没有 cover / tags / artist / category / language（这些都在 `Candidate` 上，`WorkDetail` 缺）。

## 2. 现状

- `lib/ui/home_shell.dart`：四 tab（工作台 / 候选 / 活动 / 已下载），AppBar 只有登出。
- `lib/ui/dashboard_page.dart`：候选计数用 `Wrap(children: [Chip(...)])` 渲染，**没 onTap**；
  「需并查」用 `ListTile` 渲染 `JobSummary`，**没 onTap**。
- `lib/ui/candidates_page.dart`：行用 `Card(... child: InkWell(...))` 渲染，但**只点了封面**，正文无 push。
- `lib/ui/activity_page.dart` / `lib/ui/downloaded_page.dart`：行只有 `Card`，**没 onTap**。
- `lib/ui/candidate_detail_page.dart`：`WorkDetail` 模型里只解析 `title / status / stage / filter_reason / cbz_path / metadata / timeline / job_count / live`，**没有 `actions / sources / prev_id / next_id / cover / artist / category / language`**；模型字段先扩。
- 后端契约：`CONTRACT.md` §5 已列 `/api/v1/works/{id}` 返回结构；客户端对齐 `WorkDetail` 后，**当前 detail 端点没有返 `actions / prev / next`** —— 需要补。
- `MOBILE.md` §2.2 明确说「设置页的编辑」不在 v0.1.0 — 本提案**只做只读设置入口**，编辑功能留给后 v0.1.0。

## 3. 方案

### 3.1 导航点击（最小代价）

- **工作台 chip → 候选页 tab + 过滤**：把每个计数 chip 包成 `ActionChip` / `InkWell`，onTap 切到 candidates tab 并写入 `tabCounts.firstKey` 对应的 tab（`pending / needs_info / approved / rejected / failed`）。在 `HomeShell` 暴露一个 `setTab(int, {String? subTab})` 让子页面回调。
- **工作台「需并查」行 → 候选详情**：`ListTile` 加 `onTap` push `CandidateDetailPage`。
- **候选列表行 → 候选详情**：把现有 `InkWell` 范围扩到整张 `Card`。
- **活动 job → 候选详情**：job 卡片 onTap → push，按 `candidate_id` 走。
- **已下载行 → 作品详情**：复用同一个 `CandidateDetailPage`（「下载」与「候选」是同一本书的不同 stage，端点都是 `/api/v1/works/{id}`）。

### 3.2 设置入口（只读）

- AppBar 加一个 `IconButton(Icons.settings)` → push `SettingsPage`。
- `SettingsPage` 列出当前会话信息：
  - 服务器 base URL
  - 凭据类型（密码 / API Key）
  - 用户名（来自 `whoami`）
  - Telegram / ExHentai 连接状态（来自 `summary.connections`，M3 已对齐）
  - 启动告警（`summary.startup_errors`，M3 已对齐）
  - **不**编辑任何规则 / 路径 / 凭据 — 按 `MOBILE.md` §2.2 留后 v0.1.0。

### 3.3 作品详情丰满

- 模型 `WorkDetail` 加字段（容错解析，**强字段缺失不阻断**）：
  - `cover: CoverRef?`、`tags: List<String>`、`artist: String`、`category: String`、`language: String`
  - `actions: Map<String, bool>`（approve / reject / needs_revision / requeue / convert / reconvert / repack / fetch_metadata / delete / delete_files / 4 个 sources 各自的 available）
  - `prevId: String?`、`nextId: String?`
- 端点对齐：后端若没返这些字段，客户端要按 `MOBILE.md` §3 协调后端加。
- 详情页结构（顺序）：
  1. 头部：封面 + 标题 + stage / status 两个 chip + 「上一 / 下一」图标（端点）
  2. 元数据卡片（artist / category / language / tags / cbz_path / filter_reason）
  3. 元数据列表（M3 已有，**保留**）
  4. 时间线（M3 已有，**保留**）
  5. 操作区：分组按钮 — 通过 / 退回（M3 已有，**保留**），加：重新获取元数据 / 重新打包 / 重新转换 / 切换来源（4 个）/ 重排队 / 彻底删除 / 彻底删除并删文件；后端没返 `actions` 时按钮隐藏（不是禁用，是**没有就绝不显示**）。
- 操作触发端：复用 M1 `review` / 新加 `POST /api/v1/jobs/{id}/{action}` / `PATCH /api/v1/works/{id}/metadata`（MVP 先不加编辑）。
- 反馈：每个操作走 `describeError` 错误展示 + 成功后 `SnackBar` + 列表刷新。

### 3.4 测试计划

- Widget：
  - 工作台 chip 点击后 `HomeShell` 的 `_index` 切到候选 + `candidates._tab` 等于对应 tab。
  - 候选 / 活动 / 已下载行点击 push `CandidateDetailPage`。
  - 设置页展示 base URL、凭据类型、连接状态。
  - 详情页根据后端返回的 `actions` 渲染按钮，缺字段时不崩溃。
- API：`WorkDetail` 容错解析覆盖 actions 缺、prev/next 缺、cover 缺、artist 空。
- 基线：`flutter analyze` 无警告；`flutter test` 全绿 + 用例增加。

## 4. 备选（否决）

- **把 chip 改成 `BottomNavigationBar` 的「筛选 chips」**：做额外的 5 个底部 tab，候选页本身已经有 tab，再多一层会让信息架构混乱。
- **直接拉 web 那套 8 节设置全搬到 App**：后 v0.1.0 才做编辑，**先只读**。
- **重写整页**：动作太大；M3 的 `candidate_detail_page.dart` 结构良好，**按顺序插入新区块**就行。

## 5. 界面影响

- 工作台：chip 颜色不变，加 ripple + 跳转；「需并查」行有 hover/pressed 反馈。
- 候选 / 活动 / 已下载：行整张可点；目前视觉基本不变（已有 InkWell 范围扩大）。
- 设置页：纯只读列表 + 退出登录（顶部已有，移到设置页底部）。
- 作品详情：变为「封面 + 标题 + 8 组按钮 + 元数据 + 时间线 + 上下导航」；按钮数变多，按来源列竖排。

## 6. 后端影响

- **模型对齐**：`WorkDetail` 新增字段（client 端容错）；后端 `/api/v1/works/{id}` 当前未返 `actions / prev / next`，本提案要求运营者**先与后端**把这些字段补齐再上。
- **新端点候选**：`POST /api/v1/jobs/{id}/{action}`（已存在于 `CONTRACT.md` §5，但本提案暂不调用，留按钮）。
- **CSRF**：Bearer 请求不需要，与 M1 一致。
- **本地存储**：不变。

## 7. 测试计划

- `EhBotApi.work`：解析 `actions` / `prev_id` / `next_id` / `cover` / `tags` / `artist` 等新增字段，缺字段不抛。
- `WorkDetail`：构造器默认值与后端契约对应。
- Widget：上述点击跳转路径、设置页字段可见性、详情页按钮根据 `actions` 渲染。
- 基线：M5 = `90 tests / 0 failed` → M6 增加 ~10 条。

## 8. 文档同步

- `AgentHelp/PHASES.md`：新增 M6 行（状态 = 完成于本 PR 后）。
- `AgentHelp/progress.md`：新增 M6 条目，写明版本 / 基线 / 改动 / 验证 / 文档。
- `AgentHelp/AGENTS.md`：测试基线从 `90 tests / 0 failed` 升到新数字。
- `README.md`：使用说明里加「作品详情按钮 / 设置入口」。
- `AgentHelp/CONTRACT.md`：补 `/api/v1/works/{id}` 的 `actions` / `prev_id` / `next_id` / `cover` 字段（M3 没补）。