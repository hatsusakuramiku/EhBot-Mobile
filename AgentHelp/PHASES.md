# 阶段索引

> **先读这份**。每条一行摘要 + `progress.md` 的行号指针；要细节再下钻。
> 基线链（移动端）：**M0 = 1 → M1 = 45 → M2 = 56 → M3 = 76 → M4 = 90 → M5 = 90 → M6 = 105 → M7 = 140 tests / 0 failed**
> （`flutter analyze` 零告警）。后端基线在 EhBot 仓库，与本仓库分开记。

## 一、后端依赖（在 EhBot 仓库实施，本仓库只依赖）

| 编号 | 内容 | 状态 | 记录 |
|------|------|------|------|
| B1 | 凭据表迁移 `023` + `/api/v1/auth/*` + deps 接受 Bearer | 待实施 | EhBot `AgentHelp/MOBILE_CLIENT_PROPOSAL.md` §4、§7 |
| B2 | 网页「设置 › 密码库」单 Key 生成 / 刷新 / 撤销 | 待实施 | 同上 §4.5 |
| B-M8 | M8-B 在 EhBot 仓库加的 settings/dedup/logs/manual_add 端点 | 待实施 | 本仓 `M8_FEATURE_REPLICATION_PROPOSAL.md` §4.2 |

## 二、本仓库阶段

| 编号 | 内容 | 状态 | 记录 |
|------|------|------|------|
| M0 | 建 Flutter 工程 + CI（analyze/test）+ 文档骨架核对 | **完成**（文档 + 工程 + CI 已就位） | `progress.md` M0 |
| M1 | 服务器配置页 + 密码 / API Key 双登录 + secure storage + 401 刷新拦截器 | **完成** | `progress.md` M1 |
| M2 | 缩略图带鉴权加载器 + 磁盘缓存（方案 A） | **完成** | `progress.md` M2 |
| M3 | 工作台 / 候选列表与详情 / 通过驳回 / 活动队列 / 已下载列表 | **完成** | `progress.md` M3 |
| M4 | SSE + 轮询回退 + 离线/错误态 + v0.1.0 打磨 | **完成** | `progress.md` M4 |
| M5 | 仓库改名 `ehbot-mobile` → `EhBot-Mobile` + 文档同步 | **本地完成**，远端待配置 | `progress.md` M5 |
| M6 | 工作台 / 候选 / 活动 / 已下载 行可点 + 设置页只读 + 作品详情按钮动态渲染 | **完成** | `progress.md` M6 |
| M7-A | 主题 + 设计 token + 13 个新组件 + 组件测试 | **完成**（基线 `132 tests / 0 failed`） | `progress.md` M7-A |
| M7-B | 七页重写（工作台 / 候选 / 活动 / 已下载 / 详情 / 设置 / 登录） | **完成**（契约零破坏，基线仍 132） | `progress.md` M7-B |
| M7-C | 多服务器数据层 + 启动迁移 | **完成**（基线 138） | `progress.md` M7-C |
| M7-D | 响应式断点 + `RepaintBoundary`（黄金截图改可移植断言，见 `progress.md`） | **完成**（基线 140） | `progress.md` M7-D |
| M8-A | 多服务器 UI（选择 / 编辑 / 切换） | 待实施 | `M8_FEATURE_REPLICATION_PROPOSAL.md` §7 |
| M8-B | 后端契约（EhBot 仓库 `B-M8`，本仓只改 `CONTRACT.md`） | 待实施 | 同上 §4.2 |
| M8-C | Manual Add + Dedup | 待实施 | 同上 §7 |
| M8-D | Logs live（SSE） | 待实施 | 同上 §7 |
| M8-E | Settings 八区 | 待实施 | 同上 §7 |
| M8-F | 多选 + 滑动手势 | 待实施 | 同上 §7 |

## 三、当前状态

- M0–M6 已完成：文档框架、Flutter 工程与 CI、双登录与
  会话保持、带鉴权的封面缓存、四块数据页与审核、SSE + 轮询
  间隔、仓库重命名、所有行可点 + 设置只读 + 详情动态按钮；基线 `M6 = 105 tests / 0 failed`。
- **M7 / M8 已由运营者放行**，正在按 sub-phase 逐步落地：`M7-A` 已完成
  （`theme.dart` + 13 个组件 + 组件测试，基线 `132 tests / 0 failed`）。
- 依赖变更：`dynamic_color` 已移除——它的 2.1.0 依赖独立 `material_ui` 包，
  其 `ColorScheme`/`Widget` 与 `package:flutter/material.dart` 不是同一套类型，
  引发跨包类型冲突；主题改为 seed 兜底色（`0xFFE91E63`）。
- M5 已把本地仓库目录和当前文档统一为 `EhBot-Mobile`；Dart/Android/iOS 发布标识不变。
  当前仓库没有 Git remote，远端仓库创建或配置后仍待推送。
- v0.1.0 MVP 验收线见 `DEVELOPMENT_PLAN.md` §1；M7/M8 落地后基线与版本会进一步升到 v0.2.0 / v0.3.0。
- 已知前置：开发机已装 Flutter 3.47.6 + Android SDK（android-36/build-tools 36.0.0/NDK 28.2），
  `flutter build apk --debug` 已通过；无 `/dev/kvm`、无真机、无 Chrome，故 `flutter run`
  到 Android/web 仍不可行。后端 B1/B2 仍未实施，`/api/v1/auth/login` 目前为 404。
- 未验证项：**没有真机 / 真实后端**，M1–M6 的验证是 analyze + 单测/widget 测试
  （MockClient 假后端）+ 对照 EhBot 源码核对字段；端到端待运营者用自己的部署试跑。
- 后续版本（不在本期）：iOS 商店签名发布、推送通知、主题 / 无障碍精修、APK 体积优化。
