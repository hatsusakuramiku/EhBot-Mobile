# 方案：M2 —— 缩略图带鉴权加载器 + 磁盘缓存（方案 A）

> 状态：运营者已批准「一直做到 M4」（2026-10-03）。方案 A 的结论见
> `MOBILE_CLIENT_PROPOSAL.md` §5.3 与 `CONTRACT.md` §3，本文件是 M2 的实现设计记录。

## 1. 需求

候选封面来自 `GET /api/v1/thumbnails/{hash}`，**需要 Bearer**，URL 不可变；
失败态后端返回 **200 + SVG 占位 + `X-Thumbnail-State: failed`**。
客户端必须：带鉴权取图、按 hash 落盘缓存、条件请求（`If-None-Match`）、
失败时渲染**本地占位组件**（绝不把 SVG 交给位图解码器）。

## 2. 现状

M1 只做了会话与鉴权客户端；`lib/media/` 还是空占位。没有列表页，所以封面暂时没有宿主
（M3 的候选列表 / 详情接入）。

## 3. 方案

- **`ThumbnailCache`**：抽象 + `FileThumbnailCache`（`path_provider` 的 cache 目录，
  按 hash 存 `<hash>.thumb` 字节与 `<hash>.etag`）。URL 不可变，所以命中即终态。
- **`ThumbnailLoader`**：复用 M1 的 `AuthClient`（自动带 Bearer、401 走刷新）；
  带 `If-None-Match` 条件请求，`304` 直接用缓存；`X-Thumbnail-State: failed`
  或非 200 → 抛 `ThumbnailException`（界面据此渲染本地占位）；成功则写盘。
  另加一层内存缓存（同一 hash 只请求一次，失败会清掉以便重试）。
- **`ThumbnailImage` widget**：`FutureBuilder` + `Image.memory`；
  加载中 / 失败都渲染本地灰底占位图标。

## 4. 备选（否决）

- **自定义 `ImageProvider`**（原计划名词）：失败态要求「不解码、直接本地占位」，
  走 `ImageProvider` 反而要在 codec 层绕；widget + loader 更薄、更好测。
  契约要求（鉴权 + 条件请求 + 落盘 + failed 占位）全部保留。
- 用 `Image.network`：拿不到 `X-Thumbnail-State`，也无法自定义磁盘缓存。
- 不落盘、只靠 HTTP 缓存：移动端弱网重进要重新下载，MVP 要求翻页命中缓存。

## 5. 界面影响

新增可复用的 `ThumbnailImage`；M3 的候选列表 / 详情用它显示封面。
失败与加载中都用本地占位，不显示后端 SVG。

## 6. 契约影响

不新增契约；按 `CONTRACT.md` §3 实现（`ETag` / `If-None-Match` /
`X-Thumbnail-State`）。hash 由后端给出，客户端不自行计算。

## 7. 测试计划

- 缓存：写读往返、未命中返回 `null`、etag 往返。
- 加载器：200 命中并写盘；第二次走内存不再发请求；有缓存时带 `If-None-Match`；
  304 用缓存；`failed` 头 → 抛错且不写盘；401 → 抛错；失败后允许重试。
- Widget：成功渲染 `Image`；失败渲染本地占位图标。

## 8. 文档同步

`README.md`（封面行为一句）、`progress.md`（M2 条目）、`PHASES.md`（M2 状态与基线）、
`AGENTS.md`（测试基线）。`CONTRACT.md` 无变化。
