# 方案：M4 —— SSE + 轮询回退 + 离线 / 错误态 + v0.1.0 打磨

> 状态：运营者已批准「一直做到 M4」（2026-10-03）。范围见 `DEVELOPMENT_PLAN.md` §2 的 M4
> 与 §1 验收线，契约见 `CONTRACT.md` §5（`/api/v1/events`、`/api/v1/meta`）。

## 1. 需求

SSE 收到状态变化时页面自动刷新；断流自动回退轮询并尝试恢复；断线 / 出错有明确提示；
README 与发布说明把 v0.1.0 讲清楚。

## 2. 现状

M1–M3 已有会话、封面、四块页面，但页面只在进入 / 下拉时刷新；没有实时通道。

## 3. 方案

- **SSE 解析**：`parseSse` 把字节流按 SSE 规范切成事件（`event:` / `data:`、空行分隔、
  `:` 开头是心跳注释、多行 data 用 `\n` 连接）。Dart 客户端能带 `Authorization` 头，
  这正是原生端相对浏览器 `EventSource` 的优势。
- **流式取流**：`AuthClient.stream()` 复用鉴权与 401 分流（先刷新再重连一次），
  返回 `StreamedResponse`；非 200 抛 `ApiException`。超时只作用于「拿到响应头」，
  不断开长连接。
- **`LiveMonitor`**（`ChangeNotifier`）：启动时读 `/meta` 的 `polling.interval_ms`
  作为轮询间隔；连上 SSE → `streaming`，每收到事件发一次 tick；断流 / 出错 →
  `polling` 并按间隔轮询（每次轮询也发 tick），同时按 `reconnectDelay` 重试 SSE 并恢复。
  对外暴露 `ticks` 广播流，页面订阅后刷新。
- **离线 / 错误态**：外壳在 `polling` 时显示「实时连接已断开，已回退轮询」横幅（可手动重试）；
  单页请求失败仍走 `ErrorView` + 中文提示 + 重试。
- **打磨**：README 写清用法与限制，新增 `CHANGELOG.md`（v0.1.0 条目）。

## 4. 备选（否决）

- `package:eventsource` 之类的浏览器语义封装：浏览器 EventSource 不能带 Authorization 头，
  与原生端优势相反；自己解析 SSE 只有几十行且完全可测。
- 只在页面停留时轮询、完全不做 SSE：MVP 要求「收到状态变化」，SSE 是主通道。
- 收到事件就全量刷新所有页面：M4 先按「tick → 各页刷新」做，简单且够用；
  精细化失效（按事件类型只刷相关页）留后续版本。

## 5. 界面影响

四个页面在实时 tick 到来时自动刷新；外壳顶部新增实时状态横幅（仅断流时出现，
带「重试」）。无其它界面变化。

## 6. 契约影响

不新增 / 不改契约；使用 `CONTRACT.md` §5 已有的 `/api/v1/events`（需 Bearer）与
`/api/v1/meta` 的 `polling.interval_ms` / `idle_interval_ms`。

## 7. 测试计划

- SSE 解析：单事件、多行 data、心跳注释忽略、`event:` 名字、跨 chunk 拆包。
- `AuthClient.stream`：带 Bearer、非 200 抛错、401 → 刷新一次后重连。
- `LiveMonitor`：SSE 事件 → `streaming` + tick；SSE 出错 → `polling` + 定时 tick；
  到点重试 SSE 并恢复 `streaming`；`dispose` 停止计时器与订阅。
- Widget：外壳在轮询态显示横幅（注入 forced monitor）。
- 基线：`flutter test` 只增不减；`flutter analyze` 零告警。

## 8. 文档同步

`README.md`（实时 / 轮询行为、v0.1.0 用法）、新增 `CHANGELOG.md`、
`progress.md`（M4 条目）、`PHASES.md`（M4 完成 + 基线链）、`AgentHelp/AGENTS.md`（测试基线）。
