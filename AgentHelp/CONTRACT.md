# 后端契约（EhBot `/api/v1`）

> 本文件记录移动端依赖的**最小**后端契约。后端实现记录在 EhBot 仓库的
> `AgentHelp/MOBILE_CLIENT_PROPOSAL.md`（B1/B2 期）与 `MOBILE_API_COMPLETION_PROPOSAL.md`
> （R64–R69 补齐的动作面）。**后端一变，先改本文件，再改代码。**
>
> 就绪探测：`POST /api/v1/auth/login` 返回业务响应而不是 404。
>
> **后端现状（2026-10-11，核对 EhBot `7ebab47` / R69）**：B1/B2 即 EhBot 的
> **R53 / R54，已经完成**——凭据表 `023`、`/api/v1/auth/*`、`require_session` 同时接受会话与
> `Authorization: Bearer`、Bearer 豁免 CSRF。本文档早前写的「B1/B2 未部署」是过时的。
> 其后 R60–R69 又补了 `downloaded/dedup`、`logs`、`logs/stream`、`settings/{section}`（只读）
> 以及本文件 §7 的动作面。移动端可以直接对接。

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

## 2. 鉴权端点（EhBot R53 / R54 已实现）

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
| GET | `/api/v1/works/{candidate_id}` | 候选 / 作品详情（`actions` 真实形状见 §5.2） |
| POST | `/api/v1/candidates/batch` | `{"action":"approve|reject","candidate_ids":[...]}`；**同一端点也接受 `delete` / `delete-files`**（R64），返回同一 `{action,requested,applied,skipped}` |
| POST | `/api/v1/candidates/manual` | 手动添加（R66）：`{url}`；重复 → **409** `CANDIDATE_DUPLICATE` + `details.existing_candidate_id` |
| PATCH | `/api/v1/works/{candidate_id}/metadata` | 修改元数据：`{fields:{...}, locks:{...}}` |
| POST | `/api/v1/works/{candidate_id}/requeue` | 重新排队（R65）：`{note?}` |
| POST | `/api/v1/works/{candidate_id}/needs-revision` | 要求修订（R70）：`{reason}`；理由为空 → 400 `REVISION_REASON_REQUIRED` |
| POST | `/api/v1/works/{candidate_id}/convert` | 打包 / 重新打包（R70）：空 body，返回 `{candidate_id, job_id}`；无产物 → 400 `ARCHIVE_NOT_READY` |
| POST | `/api/v1/works/{candidate_id}/fetch-metadata` | 重获画廊元数据（R71）：空 body；无关联画廊 → 400 `CANDIDATE_HAS_NO_EX_REFERENCE`，未配连接 → 503 |
| POST | `/api/v1/works/{candidate_id}/sources/{provider}` | 按来源拉取（R72）：provider ∈ `TELEGRAM` / `TELEGRAM_USER` / `EXHENTAI` / `TELEGRAPH` / `EH_TORRENT`，返回 `{candidate_id, provider, job_id}`，一律「再拉一次」；`EXHENTAI` 花 GP |
| POST | `/api/v1/downloaded/{candidate_id}/rename` | 改名 / 移动（R73）：`{filename?, directory?, repack?}`，返回 `{candidate_id, moved, relative_path, repacked}`；**两栏一起发**，只给 filename 等于移到库根 |
| GET | `/api/v1/queue` | 下载 / 打包进行中快照（含 `live` 标志） |
| GET | `/api/v1/history?limit=` | 已完成任务 |
| POST | `/api/v1/jobs/{job_id}/{action}` | 任务操作：重试 / 取消 / 暂停 / 继续等 |
| POST | `/api/v1/jobs/{job_id}/priority` | 调整优先级：`{priority}` |
| POST | `/api/v1/jobs/{job_id}/switch-source` | **下载方式切换**：`{provider}` |
| GET | `/api/v1/downloaded?tab=&search=&sort=&dir=&page=&page_size=` | 已下载列表 |
| POST | `/api/v1/downloaded/batch` | **重新下载 / 重新打包 / 移除**：`{action:"redownload"|"repack"|"remove", candidate_ids:[...], delete_files?:bool}` |
| GET | `/api/v1/downloaded/dedup` | 一键去重的计划（只读） |
| POST | `/api/v1/downloaded/dedup` | 执行去重 |
| GET | `/api/v1/logs?level=&limit=` | 日志历史 |
| GET | `/api/v1/logs/stream` | 日志实时流（SSE） |
| GET | `/api/v1/settings` | 设置分区清单 |
| GET | `/api/v1/settings/{section}` | 分区快照（**只读**） |
| PUT | `/api/v1/settings/connections` | 连接区写入（R67）：`{action:"telegram|telegram-disconnect|telegram-user-login|telegram-user-verify|telegram-user-disconnect|exhentai|exhentai-disconnect", ...}` |
| PUT | `/api/v1/settings/system` | 系统区写入（R68）：只写 body 里出现过的字段；空 body → 400 |
| PUT | `/api/v1/settings/passwords` | 密码库写入（R69）：`{action:"add|delete|api-key-generate|api-key-revoke", ...}` |
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

## 5.2 `/works/{id}` 的 `actions` 真实形状（**客户端必须按这个渲染，不要自造键**）

核对 EhBot `app/api/works.py::work_actions`（`25e1404`）：

```json
{
  "approve": bool, "reject": bool, "needs_revision": bool, "requeue": bool,
  "edit_metadata": true,
  "fetch_metadata": bool,          // 有 ex_gid 且 ExHentai 可用
  "convert": bool, "reconvert": bool, "edit_archive_path": bool,
  "sources": [
    { "provider": {"code": "...", "label": "..."}, "available": bool,
      "hint": "...", "action": "/candidates/<id>/<web-route>" }
  ]
}
```

- **没有** `delete` / `delete_files` / `repack` / `switch_source_*` 这些键。
  客户端此前按这些键取，等于按钮永远不渲染——删除与切源要用别的依据（见下）。
- **每个键对应的端点（R70–R72 之后全部就绪）**：
  - `approve` / `reject` → `POST /api/v1/candidates/batch`
  - `needs_revision` → `POST /api/v1/works/{id}/needs-revision`（**理由必填**）
  - `requeue` → `POST /api/v1/works/{id}/requeue`；`REQUEUEABLE_STATUSES = {REJECTED, NEEDS_REVISION, FAILED}`
  - `fetch_metadata` → `POST /api/v1/works/{id}/fetch-metadata`
  - `convert` / `reconvert` → `POST /api/v1/works/{id}/convert`（一个端点两件事，
    第二次按下就是把那条打包任务重新置为待跑）
  - `sources[]` → `POST /api/v1/works/{id}/sources/{provider.code}`
  - `edit_metadata` → `PATCH /api/v1/works/{id}/metadata`
  - `edit_archive_path` → **仍需后端**（网页 `/works/{id}/archive-path`）
- **删除**：`actions` 不给信号，删除入口由客户端按**状态**决定呈现（服务端会拒不可删的状态），
  走 `POST /api/v1/candidates/batch` 的 `delete` / `delete-files`。
- **切源**：读 `actions.sources[]`，用 `provider.code` 调
  `POST /api/v1/jobs/{job_id}/switch-source`。`actions.sources[].action` 是**网页路径**，
  不能直接调（网页层只认 cookie + CSRF）。因此客户端还需要该作品的 `job_id`（见 §5.1 的 `jobs`）。
- `provider` 取值：`TELEGRAM` / `TELEGRAM_USER` / `EXHENTAI` / `TELEGRAPH` / `EH_TORRENT` / `CONVERSION`。

## 6. 未决 / 注意

- 后端没有 `api.version`（已定）：客户端靠 `POST /api/v1/auth/login` 是否 404 探测。
- `openapi.json` 由 FastAPI 默认暴露（`/openapi.json`），作为契约快照校对；
  本仓库不生成客户端代码（手写 model，保持薄）。
- 若将来做 Flutter Web 构建，需要后端加 CORS 与 cookie/CSRF 策略——当前**不做**。

## 7. 复刻 WEBUI 所需的端点清单（2026-10-11 按 EhBot `7ebab47` 更正）

> 本节早前把整张表标成「后端尚未实现」，**那是错的**：dedup 与 logs 早已存在，
> 路径还写错了。下表已按当前源码更正，并标注每一行是**已就绪**还是**仍需后端**。
>
> 全部走 Bearer（`require_session` 接受 Bearer、`require_csrf` 对 Bearer 豁免）；
> 列表与错误沿用 §1 信封。

**已就绪（客户端可以直接接）**

| 模块 | 方法 | 路径 | 用途 |
|------|------|------|------|
| dedup | GET | `/api/v1/downloaded/dedup` | 每个重复组的「保留 / 移除」判定（只读） |
| dedup | POST | `/api/v1/downloaded/dedup` | 执行去重 |
| logs | GET | `/api/v1/logs?level=&limit=` | 历史日志（级别为展示下限） |
| logs | GET | `/api/v1/logs/stream` | 实时日志（SSE，与 `/events` 平行） |
| manual_add | POST | `/api/v1/candidates/manual` | `{url}`；重复 → 409 + `details.existing_candidate_id` |
| connections | GET / PUT | `/api/v1/settings/connections` | 状态读 `GET settings/connections`；写入 `PUT` + `{action,...}` |
| system | GET / PUT | `/api/v1/settings/system` | 读快照；写只提交 body 里出现过的字段 |
| passwords | GET / PUT | `/api/v1/settings/passwords` | `{action:"add"\|"delete"\|"api-key-generate"\|"api-key-revoke"}` |

**已就绪（R70–R73 补上，客户端已接）**

| 模块 | 方法 | 路径 | 用途 |
|------|------|------|------|
| 作品动作 | POST | `/api/v1/works/{id}/needs-revision` | 要求修订：`{reason}`，理由必填 |
| 作品动作 | POST | `/api/v1/works/{id}/convert` | 打包 / 重新打包：空 body，返回 job id |
| 作品动作 | POST | `/api/v1/works/{id}/fetch-metadata` | 重获画廊元数据 |
| 作品动作 | POST | `/api/v1/works/{id}/sources/{provider}` | 按来源拉取：五个 provider，一律重新拉 |
| 已下载 | POST | `/api/v1/downloaded/{id}/rename` | 改名 / 移动；两栏一起发 |

**仍需后端（客户端渲染为禁用态 + 说明，不要撞 404）**

| 模块 | 方法 | 路径 | 用途 |
|------|------|------|------|
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
| 作品动作 | PUT | `/api/v1/works/{id}/archive-path` | 改归档路径（`actions.edit_archive_path`） |

补充：

- **改管理员密码**（`change_password`）移动端**不实现**：那是浏览器会话路径的事，
  Bearer 签发时已保证改过密码。
- `passwords` / `connections` 两类**永不回显明文**：`GET` 只给标识、状态与时间。
  唯一例外是 `api-key-generate` 的**响应**——明文只出现那一次（与网页的一次性 reveal 同义）。
- 仍需后端的那批，若要补，走 EhBot 仓库的 `AgentHelp/MOBILE_API_COMPLETION_PROPOSAL.md` §6。
