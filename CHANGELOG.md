# 变更日志

## v0.1.0（未发布）

首个可试用版本：登录 + 四块数据页 + 审核 + 实时刷新。

- **连接与登录**：服务器地址（支持反代前缀）、自签证书开关（可填 SHA-1 指纹 pin）、
  明文 http 显式确认与告警；密码登录与 API Key 登录（凭据族隔离）；
  refresh token / API Key 存 Keychain / Keystore，access 只在内存；
  access 过期自动刷新一次，失败回登录页。
- **封面**：带鉴权的缩略图加载器，按 hash 落盘缓存 + `If-None-Match`；
  后端 `X-Thumbnail-State: failed` 时渲染本地占位（不解码后端 SVG）。
- **数据页**：工作台概览、候选列表（tab / 搜索 / 加载更多）、候选详情
  （元数据 / 时间线）、通过 / 驳回、活动队列 + 历史、已下载列表（搜索 / 加载更多）。
- **实时**：`/api/v1/events` SSE 主通道；断流自动回退轮询（间隔取自 `/api/v1/meta`）
  并周期性重试恢复；断流时外壳顶部有横幅与手动重试。
- **质量**：`flutter analyze` 零告警；`flutter test` 90 tests / 0 failed；
  CI（`.github/workflows/ci.yml`）锁定 Flutter 3.47.6 跑 analyze + test。
- **已知限制**：活动页只读（重试 / 取消 / 优先级不在本期）；
  设置编辑、批量操作、日志流、推送、主题 / 无障碍精修留待后续版本；
  尚未在真机与真实后端（B1/B2）上做端到端验证。
