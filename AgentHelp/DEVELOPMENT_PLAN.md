# 开发计划

> 设计来源：`MOBILE_CLIENT_PROPOSAL.md`（已审阅通过，2026-10-03）。
> 一期一个 commit；代码 / 测试 / 文档一起交付。

## 1. MVP 验收线（v0.1.0 = 基本可用）

| # | 验收项 | 判据 |
|---|--------|------|
| 1 | 服务器配置 | 能填 base URL，自签 / 明文策略有明确开关与告警 |
| 2 | 密码登录 | 输入密码能登录；错误密码给出提示；未改初始密码有明确指引 |
| 3 | API Key 登录 | 粘贴有效 Key 能登录；无效 / 被刷新给出明确提示 |
| 4 | 会话保持 | 杀进程重开后仍登录（refresh token / Key） |
| 5 | 工作台 | 展示 `/summary` 的概览 |
| 6 | 候选 | 列表 + 详情；封面正常；分页 / 搜索可用 |
| 7 | 审核 | 通过 / 驳回成功，列表状态刷新 |
| 8 | 活动 / 已下载 | `/queue`、`/history`、`/downloaded` 可读 |
| 9 | 实时 | SSE 收到状态变化；断流自动回退轮询并恢复 |
| 10 | 质量 | `flutter analyze` 零告警；`flutter test` 全绿；无 token 入日志 |

以上全部满足即 v0.1.0。

## 2. 分期

### 后端（在 EhBot 仓库实施，本仓库只依赖）

- **B1**：迁移 `023_api_credentials.sql`（`api_credentials` 表 + 单 Key 部分唯一索引）；
  新 `app/api/auth.py`（login / refresh / logout / whoami）；`app/api/deps.py` 统一
  接受 Bearer，`require_csrf` 对 Bearer 放行；`login_throttle.py` 抽取；测试。
  完成判据：curl 能用 token 访问全部 `/api/v1`，浏览器用例全过。
- **B2**：网页「设置 › 密码库 › API 密钥（移动端）」生成 / 刷新 / 撤销；
  明文只显示一次；`settings_snapshot` 加元数据；测试 + 文档。

### 客户端（本仓库）

- **M0 工程与骨架**：安装 Flutter SDK，`flutter create`，目录落位
  （`lib/api`、`lib/state`、`lib/ui`、`lib/media`），CI 跑 `flutter analyze` +
  `flutter test`，记录首个基线数字。本仓库文档骨架已先行到位（本次）。
- **M1 连接与登录**：服务器配置页、两种登录、`flutter_secure_storage`、
  鉴权 HTTP 客户端 + 401→refresh 拦截器、`whoami` 连通测试。
- **M2 缩略图**：方案 A 的 `ThumbnailImageProvider`：带 Authorization 与
  `If-None-Match`、读 `X-Thumbnail-State`、按哈希磁盘缓存、失败态本地占位。
- **M3 核心页面**：工作台、候选列表 / 详情、通过 / 驳回、活动 / 队列、已下载列表。
- **M4 实时与打磨**：SSE 消费 + 轮询回退、离线 / 错误态、`README` 与发布说明，
  达成 §1 验收线 → v0.1.0。

## 3. 风险与对策

| 风险 | 对策 |
|------|------|
| 开发机未装 Flutter SDK | M0 第一步安装，版本写进 `progress.md`；锁定 SDK 版本 |
| 后端 B1/B2 未完成 | 客户端用 `POST /api/v1/auth/login` 是否 404 探测；未就绪给出明确提示；可先用 mock server 开发 M1 |
| 明文 / 自签部署 | 默认 HTTPS；自签用指纹 pin；明文需显式确认并标红 |
| 单 Key 泄露 | 网页端常驻「最近使用」+ 一键撤销；刷新即失效；README 说明风险 |
| 缩略图解码 SVG 占位 | 加载器读 `X-Thumbnail-State`，failed 时渲染本地占位，不交给位图解码器 |
| 契约漂移 | `CONTRACT.md` + `openapi.json` 快照；后端先改契约再改客户端 |

## 4. 文档责任

每期更新：`README.md`（用户可见行为）、`progress.md`（M 条目）、`PHASES.md`（状态与指针）、
`AGENTS.md`（测试基线）；契约变化时 `CONTRACT.md` 先行。
