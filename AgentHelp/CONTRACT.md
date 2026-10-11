# 后端契约（EhBot `/api/v1`）

> 本文件记录移动端依赖的**最小**后端契约。后端实现记录在 EhBot 仓库的
> `AgentHelp/MOBILE_CLIENT_PROPOSAL.md`（B1/B2 期）。**后端一变，先改本文件，再改代码。**
>
> 就绪探测：`POST /api/v1/auth/login` 返回业务响应而不是 404。
> EhBot R52（v0.3.0rc2）**不含**移动端鉴权，必须等 B1/B2 部署后客户端才可用。

## 1. 通用

- Base URL 由用户在 App 内配置，可带反向代理前缀（对应后端 `APP_ROOT_PATH`）。
- 鉴权：`Authorization: Bearer <public_id>.<secret>`。
- 错误信封：`{"error": {"code", "message", "details"}}`。
- 列表信封：`{"items", "total", "page", "page_size", "pages"}`（不同端点会附带
  `counts`、`tab`、`sort`、`direction`、`search`、`filters` 等上下文，客户端按需读）。
- 分页 / 搜索参数：`search`、`sort`、`dir=asc|desc`、`page`、`page_size`（上限 200）。
- `401 NOT_AUTHENTICATED`：凭据缺失 / 无效 / 过期 / 被吊销。
- `403 PASSWORD_CHANGE_REQUIRED`：仅浏览器会话路径会出现；Bearer 签发时已保证改过密码。
- Bearer 请求**不需要** CSRF（`X-CSRF-Token` 只用于浏览器 cookie 会话）。

## 2. 鉴权端点（B1 新增）

| 方法 | 路径 | 鉴权 | 请求 | 响应 |
|------|------|------|------|------|
| POST | `/api/v1/auth/login` | 无 | `{"password": "...", "label": "Pixel 9"}` | `{"access_token", "refresh_token", "token_type": "Bearer", "expires_in"}` |
| POST | `/api/v1/auth/refresh` | 凭 refresh token | `{"refresh_token": "..."}` | 同上；旧 refresh 立即吊销（轮换） |
| POST | `/api/v1/auth/logout` | Bearer | 空 | 吊销本设备 access/refresh 族；**不动 API Key** |
| GET | `/api/v1/auth/whoami` | Bearer | — | `{"username", "kind", "expires_at", "must_change_password"}` |

要点：

- 密码校验复用后端 `admin_users` 与失败锁定；连续失败返回 `429`。
- 错误码：`AUTH_INVALID_CREDENTIALS`、`AUTH_TOKEN_EXPIRED`、`AUTH_TOKEN_REVOKED`。
- 未改初始密码时 login 返回 `403 PASSWORD_CHANGE_REQUIRED`，**不签发 token**。
- `expires_at` 为 `null` 表示不过期（API Key）。

### 2.1 凭据族隔离（重要）

| 动作 | 密码认证族（access/refresh） | API Key 族 |
|------|------------------------------|------------|
| 改管理员密码 | **整族吊销** | 不受影响 |
| 网页刷新 API Key | 不受影响 | 旧 Key 立即失效 |
| 网页撤销 API Key | 不受影响 | 当前 Key 失效 |
| 移动端 logout | 只吊销本设备 | 不受影响 |

- API Key：`ehk_` 前缀，**不过期**，**全局最多一条有效**，网页端手动生成 / 刷新 / 撤销，
  默认不生成。刷新 = 吊销旧 + 生成新；明文只在生成响应里出现一次。
- 客户端不得假设「改密会保活 Key」之外的行为；收到 401 时按凭据类型分流处理（§4）。

## 3. 缩略图（`GET /api/v1/thumbnails/{hash}`）

- `hash` 是 64 位十六进制内容摘要；URL 不可变，就绪响应带
  `Cache-Control: private, max-age=31536000, immutable` 与 `ETag: "<hash>"`。
- 需要 Bearer（与其它端点一致）。客户端方案 A：带鉴权加载器 +
  `If-None-Match` 条件请求 + 按 hash 落盘缓存。
- **失败态返回 200 + `thumb-placeholder.svg`（SVG）+ 头 `X-Thumbnail-State: failed`**，
  可选 `X-Thumbnail-Error`。客户端必须读该头并渲染本地占位组件，
  **不要把 SVG 交给位图解码器**（Flutter 解码器不认 SVG）。

## 4. 客户端 401 处理

| 当前凭据 | 收到 401 时 |
|----------|-------------|
| 密码登录（access） | 用 refresh 换一次；成功则重放原请求；失败 → 清凭据回登录页 |
| 密码登录（refresh 也被拒） | 清凭据回登录页 |
| API Key | 直接提示「密钥无效或已在网页端刷新」，**不尝试 refresh** |

## 5. MVP 用到的端点

| 方法 | 路径 | 用途 |
|------|------|------|
| GET | `/healthz` | 连通探测（无需鉴权） |
| GET | `/api/v1/meta` | 状态词表、功能开关、轮询间隔、时区 |
| GET | `/api/v1/summary` | 工作台概览 |
| GET | `/api/v1/candidates?tab=&search=&sort=&dir=&tags=&artist=&language=&category=&page=&page_size=` | 候选列表（附 `counts`/`tab_counts`） |
| GET | `/api/v1/candidates/facets?tab=` | 过滤可选值与计数 |
| GET | `/api/v1/works/{candidate_id}` | 候选 / 作品详情 |
| POST | `/api/v1/candidates/batch` | `{"action":"approve|reject","candidate_ids":[...]}`，单个也是批量 |
| PATCH | `/api/v1/works/{candidate_id}/metadata` | 修改元数据（MVP 可先不做） |
| GET | `/api/v1/queue` | 下载 / 打包进行中快照（含 `live` 标志） |
| GET | `/api/v1/history?limit=` | 已完成任务 |
| POST | `/api/v1/jobs/{job_id}/{action}` | 任务操作：重试 / 取消 / 暂停 / 继续等 |
| POST | `/api/v1/jobs/{job_id}/priority` | 调整优先级 |
| POST | `/api/v1/jobs/{job_id}/switch-source` | 切换来源 |
| GET | `/api/v1/downloaded?tab=&search=&sort=&dir=&page=&page_size=` | 已下载列表 |
| GET | `/api/v1/logs` | 日志（MVP 可选） |
| GET | `/api/v1/events` | SSE 事件流 |
| GET | `/api/v1/thumbnails/{hash}` | 封面 |

- `dir` 省略时由后端按 `sort` 给出默认方向；响应里回显 `direction`，
  客户端应读回显而不是自己推导。
- POST 的写操作走 Bearer 时无需 CSRF；浏览器网页端仍要求 `X-CSRF-Token`。

## 5.1 已核对的响应形状（M3 实现时对照 EhBot 源码）

- `/summary`：`{candidates: {<count key>: int, total}, activity: {downloads, packing, live},
  attention: {total, items: [job_summary]}, connections, startup_errors}`
  （count key = `CANDIDATE_COUNT_KEYS`：`pending_review` / `needs_info` / …）。
- `/candidates`：通用信封 + `counts`（按状态）+ `tab_counts`（按 tab）+ `tab` / `sort` /
  `direction` / `search` / `filters`。列表项字段见 `candidate_summary`，
  其中 `cover` 是 `{url, hash}`（hash 即缩略图路径参数），`actions:{approve,reject}`。
- `/works/{candidate_id}`：详情没有顶层 `artist/category/tags/cover`，正文在
  `metadata`（含 `field_label`/`field_value`/`is_manual`/`is_locked`）、`timeline`
  （含 `action_view.label` / `reason` / `created_at`）、`messages`、`jobs`、`archive`、`actions`。
  客户端在 M6 后在 `WorkDetail` 模型中预见这些字段；后端未返回时默认空值，按钮不渲染。
- `/queue`：`{downloads: [{group, count, jobs}], packing: [...], counts:{downloads,packing},
  attention:{total,reasons}, live}`（后端已分好组，客户端不重新分组）。
- `/history`：`{items: [job_summary], total, limit}`。
- `/downloaded`：**列表键是 `works`（不是 `items`）**，附 `tab` / `tab_view` / `direction` /
  `counts` / `total` / `live`。客户端兼容 `works` 与 `items` 两种键。
- `/candidates/batch`：`{action, requested, applied: [...], skipped: [{code, message}]}`；
  单个候选也走这个端点。
- `/meta`：`polling.interval_ms` / `polling.idle_interval_ms`（客户端轮询回退间隔）。

## 6. 未决 / 注意

- 后端没有 `api.version`（已定）：客户端靠 `POST /api/v1/auth/login` 是否 404 探测。
- `openapi.json` 由 FastAPI 默认暴露（`/openapi.json`），作为契约快照校对；
  本仓库不生成客户端代码（手写 model，保持薄）。
- 若将来做 Flutter Web 构建，需要后端加 CORS 与 cookie/CSRF 策略——当前**不做**。

## 7. M8 端点快照（EhBot 仓库 `B-M8` 期新增；本仓库按 404 降级消费）

> 本节是 M8 复刻 WEBUI 功能所需的端点清单。**后端尚未实现**——本仓库不等待，
> 客户端按「端点存在则启用、404 则降级提示」两态处理。后端实现后本节升级为事实契约。
>
> 全部走 Bearer；`POST .../verify` 这类运行时检查不写 CSRF；列表与错误沿用 §1 信封。

| 模块 | 方法 | 路径 | 用途 |
|------|------|------|------|
| manual_add | POST | `/api/v1/candidates/manual` | `{url}`；返回新候选或 `{existing_candidate_id}` |
| dedup | GET | `/api/v1/dedup/plan` | 每个重复组的「保留 / 移除」判定（只读） |
| dedup | POST | `/api/v1/dedup` | `{apply:true}` 执行去重 |
| logs | GET | `/api/v1/logs?level=&limit=` | 历史日志（级别为展示下限） |
| logs | GET | `/api/v1/logs/stream` | 实时日志（SSE，与 `/events` 平行） |
| connections | GET/PUT | `/api/v1/settings/connections` | Telegram Bot / TG 用户 / ExHentai 状态与保存 |
| sources | GET/POST/PATCH/DELETE | `/api/v1/settings/sources` + `/{id}` | 监听来源白名单 + 过滤规则 |
| sources | POST | `/api/v1/settings/sources/dialogs` | 用 TG 用户账户读会话列表 |
| parse | GET/PUT | `/api/v1/settings/parse` | 消息解析规则 + AI 候选判定 |
| auto-approval | GET/POST/PATCH/DELETE | `/api/v1/settings/auto-approval/rules` + `/{id}` | 自动审批规则 CRUD |
| auto-approval | POST | `/api/v1/settings/auto-approval/rules/{id}/dry-run` | 试跑：返回命中数与样例 id |
| archive | GET/PUT | `/api/v1/settings/archive/{torrent,limits,profiles}` | qBittorrent / 自动打包 / 安全限制 / 工具 profile |
| paths | GET/PUT/POST | `/api/v1/settings/paths/{template,rules,ai,preview}` | 路径模板 / 路径规则 / AI 模式 / 预览 |
| paths | POST | `/api/v1/settings/paths/rearchive` | 一键重新归档（可选 `force`） |
| ai | GET/POST/PATCH/DELETE | `/api/v1/settings/ai/{providers,models}` + `/{id}` | AI 供应商与模型 CRUD |
| ai | GET/PUT | `/api/v1/settings/ai/chain` | 主力 + 备用模型链 |
| ai | POST | `/api/v1/settings/ai/verify` | 测试模型连通性 |
| passwords | GET/POST/DELETE | `/api/v1/settings/passwords` + `/{id}` | 归档密码条目（**永不回显明文**） |
| api-key | GET/POST/DELETE | `/api/v1/settings/api-key` | 移动端 API Key 生成 / 查看标识 / 撤销 |
| system | GET/PUT | `/api/v1/settings/system` | 运行参数 / 日志级别 / 时区 |

补充：

- **改管理员密码**（`change_password`）移动端**不实现**：那是浏览器会话路径的事，
  Bearer 签发时已保证改过密码。
- `passwords` / `api-key` / `connections` 三类**永不回显明文**：`GET` 只给标识、
  状态与时间；`api-key` 明文只在生成响应里出现一次。
- 404 处理：客户端把该模块标记为「后端未就绪」并在页面给出说明，不抛崩溃。
