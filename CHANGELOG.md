# 变更日志

## v0.2.0（未发布）

UI 重构 + WEBUI 功能复刻第一期。基线 `105 → 158 tests / 0 failed`。

- **UI 重构（M7）**：Material 3 主题与设计 token（`EhSpacing` / `EhRadius` / `EhAnim` /
  `EhBreakpoints`，seed `#E91E63`）；13 个统一组件（`EhCard` / `ToneChip` / `CoverThumb` /
  `TagChip` / `EmptyState` / `SectionHeader` / `MenuFab` / `BottomSheet` / `SearchBar` /
  `LargeTitleAppBar` / `MetricStrip` / `NavBar` / `Gap`）；七页重写为大标题 + 卡片式移动布局；
  窄屏列表 / 宽屏网格的响应式断点；列表项与封面加 `RepaintBoundary`。
  **移除 `dynamic_color` 依赖**（它的 2.1.0 依赖独立 `material_ui` 包，与
  `package:flutter/material.dart` 类型不兼容），主题改用 seed 兜底色。
- **多服务器（M7-C + M8-A）**：`ServerProfile` + `ServerStore`；顶栏服务器切换入口；
  列表页支持切换 / 编辑 / 重命名 / 删除 / 新增；旧单服务器配置自动迁移。
  仍然**不做账号体系**——多份档案只是多台服务器。
- **手动添加（M8-C）**：粘贴 ExHentai / 预览页 / 磁力链接入队；重复链接给已有候选入口。
- **一键去重（M8-C）**：先看保留 / 移除计划，再确认执行。
- **运行日志（M8-D）**：历史 + SSE 实时流，可切级别、可暂停。
- **设置九区（M8-E）**：分区导航（宽屏 Rail / 窄屏选择条）；后端快照 200 时按 key/value
  渲染，404 时提示「后端未就绪」。
- **批量与手势（M8-F）**：候选长按多选 + 批量通过 / 驳回；右滑通过、左滑驳回。
- **后端依赖**：M8-C/D/E 的完整功能需要 EhBot 仓库 `B-M8` 期端点（见 `CONTRACT.md` §7）；
  未部署时相应页面给出降级提示，不影响其它功能。
- **已知限制**：各设置分区的专用编辑表单待后端 `B-M8` 落地后逐区补齐；黄金截图基线未建立
  （改用可移植断言，理由见 `progress.md` M7-D）；仍未在真机与真实后端做端到端验证。

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
