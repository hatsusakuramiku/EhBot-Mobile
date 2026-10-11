# 变更日志

## v0.3.0（未发布）

运营者实测 v0.2.0 后的五项修订（M9）。基线 `158 → 196 tests / 0 failed`。

- **外观（M9-A）**：设置新增「外观」区——主题模式（跟随系统 / 浅色 / 深色）+
  配色方案（8 个预设色 + 色相滑块）。纯本机偏好，存 `SharedPreferences`
  （`ehbot.theme_mode` / `ehbot.seed_color`）；主题 seed 改为运行时可变。
- **详情页固定操作底栏 + 真实动作（M9-B/C）**：操作从滚动内容末尾搬到
  `bottomNavigationBar`（对齐 WebUI 的 sticky 动作条），不必滑到底才能点。
  按钮可见性改读后端**真实**的 `actions`（`approve` / `reject` / `needs_revision` /
  `requeue` / `fetch_metadata` / `convert` / `reconvert` / `edit_archive_path` /
  `sources[]`）——M9 之前客户端读的是 `delete` / `switch_source_*` 这些**后端从不返回**
  的键，所以删除与切源按钮一个都不渲染。
- **动作修到正确的端点**：任务操作一律用 **job id** 打
  `/api/v1/jobs/{job_id}/{retry|pause|resume|cancel|stop-seeding}`（此前错打候选 id，
  且动作名是自造的）；切源 `…/switch-source`；重新排队 `/works/{id}/requeue`；
  彻底删除 / 删文件 `candidates/batch` 的 `delete` / `delete-files`；
  元数据 `PATCH /works/{id}/metadata`。
- **详情内容补全**：告警与 `warning_hint`、过滤说明（含来源）、任务卡（状态 / provider /
  进度 / 该任务自己的动作）、来源消息与附件、画廊 ID / 预览页 / 种子 / 磁力链、
  归档目录与文件名、原始元数据。
- **更正 M8 的三处端点错误**：去重改走 `/api/v1/downloaded/dedup`（GET 计划 /
  POST 执行）；手动添加的「重复」按后端实际行为识别为 **409** `CANDIDATE_DUPLICATE`
  （`error.details.existing_candidate_id`）；`AuthClient` 补 `putJson`（设置写入用 PUT）。
- **移除**：详情页「上一 / 下一作品」按钮——JSON 详情快照不含 `prev_id` / `next_id`，
  那是 HTML 页面才有的字段，按钮永远不会出现。后续用列表上下文推导（见待办）。
- **已下载 / 活动（M9-D）**：已下载列表长按多选 → **批量打包 / 重新下载 / 移除记录 /
  移除并删除文件**（两个移除是两条不同的确认），行内打包 / 重新打包 / 重新下载；
  活动页任务行补 **重试 / 继续 / 暂停 / 取消 / 停止做种**，停滞的种子再给
  **切换来源**（改用预览图源 / 用 Archive Download，后者先确认会消耗 GP），
  批量条 = 恢复 / 暂停 / 重试 / 调整优先级 / 取消（优先级会先做范围检查）。
- **候选删除（M9-F）**：候选页多选条新增 **彻底删除 / 彻底删除并删文件**；
  手动添加的「重复」按后端实际行为（**409** `CANDIDATE_DUPLICATE`）渲染并给
  「查看已有候选」入口。
- **设置（M9-E）**：设置页改为**外观 / 服务器 / 当前凭据（只读）/ 后端分区设置**，
  明确「不是账号管理台」（EhBot 是单用户系统）。九个后端分区里
  **外部连接、系统、密码库可直接编辑**（EhBot R67–R69），其余六区按顶层字段
  分组只读并说明需要后端端点。凭据永不回显；API Key 明文只在生成的那一次出现。
- **已知限制**：重获元数据 / 打包与重新打包 / 要求修订 / 按来源拉取原档在 `/api/v1`
  还没有端点，App 内渲染为禁用并说明原因；设置六区的**写入**同样待后端
  （清单见 `AgentHelp/CONTRACT.md` §7）。详情页「上一 / 下一作品」待用列表上下文推导。

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
