# 方案：M3 —— 工作台 / 候选 / 审核 / 活动 / 已下载

> 状态：运营者已批准「一直做到 M4」（2026-10-03）。范围见 `DEVELOPMENT_PLAN.md` §2 的 M3，
> 端点在 `CONTRACT.md` §5。响应字段按 **EhBot 仓库当前实现**核对
> （`app/api/serializers.py` / `candidates.py` / `works.py` / `activity.py` / `downloaded.py`），
> 不靠猜。

## 1. 需求

登录后四块数据页可用：工作台概览、候选列表 + 详情 + 通过 / 驳回、活动队列 + 历史、
已下载列表；封面走 M2 的鉴权加载器；列表能分页、能搜索。

## 2. 现状

M1 有会话与带鉴权的 `AuthClient`，M2 有缩略图加载器；`HomeShell` 还是占位页。
`lib/api` 里没有数据端点与模型。

## 3. 方案

- **模型（薄，手写）**：只取界面要用的字段，全部**容错解析**（缺字段给默认值，
  不因后端多/少一个键而崩）。状态统一用 `StatusView{code,label,tone,live}`，
  文案取自后端 resolved vocabulary，不在客户端硬编码中文状态名。
- **端点封装 `EhBotApi`**：`/summary`、`/candidates`、`/works/{id}`、
  `/candidates/batch`、`/queue`、`/history`、`/downloaded`、`/meta`。
  列表页 `page_size=30`（后端上限 200）。
- **页面**：`HomeShell` 换成 4 个 tab 的 `NavigationBar` +
  `IndexedStack`（切页不丢状态）；工作台、候选（tab + 搜索 + 加载更多）、
  候选详情（元数据 / 时间线 + 通过 / 驳回）、活动（队列分组 + 历史）、已下载（搜索 + 加载更多）。
- **审核写操作**：`POST /candidates/batch`，单个候选也走批量（契约如此）；
  结果按 `applied`/`skipped` 反馈，成功后回列表刷新。
- **错误态**：统一的 `ErrorView` + `describeError`（复用 M1 的中文映射），带「重试」。
- **活动页 MVP 只读**：`jobs/{id}/{action}` 不在 §1 验收线内，留到后续版本。

## 4. 备选（否决）

- 用 `json_serializable`/`freezed` 生成模型：契约薄、字段少，手写 + 容错更透明，少一层构建步骤。
- 活动页做任务操作（重试 / 取消）：超出 M3 验收线，且需要逐动作的失败语义，留后。
- 分页做「上一页 / 下一页」：移动端列表按「加载更多」追加更顺手。

## 5. 界面影响

占位首页 → 真四页；候选卡片显示封面 / 标题 / 作者 / 状态 / 标签；详情显示元数据与时间线；
通过 / 驳回后列表状态刷新并给出结果提示。

## 6. 契约影响

不新增 / 不改后端契约。实现时发现的两处**实现细节**记在此处，供 `CONTRACT.md` 参考：
`/downloaded` 的列表键是 `works`（不是通用信封的 `items`），且带 `counts`/`live`；
`/queue` 返回 `downloads`/`packing` 分组 + `counts` + `attention` + `live`。
客户端对 `/downloaded` 兼容 `works` 与 `items` 两种键。

## 7. 测试计划

- `EhBotApi`：候选解析（items + counts + tab_counts + 空 cover）、`/downloaded` 的
  `works`/`items` 兼容、审核批量结果（applied/skipped）、错误信封透传、查询参数拼装。
- Widget：工作台渲染概览数字；候选列表渲染卡片并能触发搜索；候选详情显示字段，
  通过按钮调用接口并返回 `true`；活动页渲染队列分组与历史；已下载页渲染列表。
- 基线：`flutter test` 只增不减；`flutter analyze` 零告警。

## 8. 文档同步

`README.md`（四块页面与审核行为）、`progress.md`（M3 条目）、`PHASES.md`（M3 状态与基线）、
`AgentHelp/AGENTS.md`（测试基线）；`CONTRACT.md` 按 §6 的两条实现细节做小幅补充。
