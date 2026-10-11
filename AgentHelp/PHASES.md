# 阶段索引

> **先读这份**。每条一行摘要 + `progress.md` 的行号指针；要细节再下钻。
> 基线链（移动端）：**M0 = 1 → M1 = 45 → M2 = 56 → M3 = 76 → M4 = 90 → M5 = 90 →
> M6 = 105 → M7 = 140 → M8 = 158 → M9-A = 161 tests / 0 failed**
> （`flutter analyze` 零告警）。后端基线在 EhBot 仓库，与本仓库分开记。

## 一、后端依赖（在 EhBot 仓库实施，本仓库只依赖）

| 编号 | 内容 | 状态 | 记录 |
|------|------|------|------|
| B1 | 凭据表迁移 `023` + `/api/v1/auth/*` + deps 接受 Bearer | **已完成**（EhBot **R53**） | EhBot `AgentHelp/MOBILE_CLIENT_PROPOSAL.md` §4、§7 |
| B2 | 网页「设置 › 密码库」单 Key 生成 / 刷新 / 撤销 | **已完成**（EhBot **R54**） | 同上 §4.5 |
| B-M8 | settings / dedup / logs / manual_add 端点 | **已完成**（EhBot **R60–R63**） | 本仓 `M8_FEATURE_REPLICATION_PROPOSAL.md` §4.2 |
| B-M9 | 动作面补口：删除 / 重新排队 / 手动添加 / 设置写入 | **已完成**（EhBot **R64–R69**） | EhBot `AgentHelp/MOBILE_API_COMPLETION_PROPOSAL.md`；本仓 `CONTRACT.md` §5、§5.2、§7 |

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
| M8-A | 多服务器 UI（选择 / 编辑 / 切换） | **完成**（基线 144） | `progress.md` M8-A |
| M8-B | 后端契约（EhBot 仓库 `B-M8`，本仓只改 `CONTRACT.md`） | **完成**（契约快照已写入 §7） | `CONTRACT.md` §7 |
| M8-C | Manual Add + Dedup | **完成**（基线 150） | `progress.md` M8-C |
| M8-D | Logs live（SSE） | **完成**（基线 152） | `progress.md` M8-D |
| M8-E | Settings 九区（导航 + 两态渲染骨架） | **完成**（基线 155；各专用表单待后端） | `progress.md` M8-E |
| M8-F | 多选 + 滑动手势 | **完成**（基线 158） | `progress.md` M8-F |
| M9-A | 外观：主题模式 + 配色方案 | **完成**（基线 161；App 升 v0.3.0） | `progress.md` M9-A |
| M9-B | 数据层重写：`jobs` / 真实 `actions` / 新端点 / PUT | **完成**（与 M9-C 同一提交） | `progress.md` M9-B/C |
| M9-C | 详情页固定操作底栏 + 真实动作 + 内容补全 | **完成**（基线 177） | `progress.md` M9-B/C |
| M9-D | 已下载 / 活动 / 去重：重下载 / 重打包 / 移除 / 切源 | **完成**（基线 184） | `progress.md` M9-D |
| M9-E | 设置：外观 + 服务器 + 三区写入 + 六区只读 | 待实施 | 同上 §4 |
| M9-F | 候选多选删除 + 手动添加 409 更正 | **完成**（基线 187） | `progress.md` M9-F |

## 三、当前状态

- M0–M6 已完成：文档框架、Flutter 工程与 CI、双登录与
  会话保持、带鉴权的封面缓存、四块数据页与审核、SSE + 轮询
  间隔、仓库重命名、所有行可点 + 设置只读 + 详情动态按钮；基线 `M6 = 105 tests / 0 failed`。
- **M7 / M8 已由运营者放行并全部落地**：M7-A..D + M8-A..F 八个子阶段完成，
  基线 `105 → 158 tests / 0 failed`；App 版本 v0.2.0。
- **M9 正在推进**（运营者实测 v0.2.0 后提的五项修订，方案
  `M9_OPERATOR_FIXES_PROPOSAL.md` v2，已按 EhBot `7ebab47` 重写）：
  M9-A 已落地（基线 161；App 升 **v0.3.0**），M9-B..F 待实施。
- 后端依赖**已经全部就绪**：B1/B2 = EhBot R53/R54，B-M8 = R60–R63，
  B-M9（动作面补口）= R64–R69。`CONTRACT.md` 已按 `7ebab47` 更正
  （早前写的「B1/B2 未部署」是过时描述）。
- 未完成的收尾项：设置六区（`sources` / `parse` / `auto-approval` / `archive` /
  `paths` / `ai`）的**写入**仍需后端 `/api/v1` 端点；详情页「上一 / 下一作品」
  需要由列表上下文推导（JSON 详情不含 `prev_id` / `next_id`）；
  黄金截图基线未建立（改用可移植断言，理由见 `progress.md` M7-D）。
- 依赖变更：`dynamic_color` 已移除——它的 2.1.0 依赖独立 `material_ui` 包，
  其 `ColorScheme`/`Widget` 与 `package:flutter/material.dart` 不是同一套类型，
  引发跨包类型冲突；主题改为 seed 兜底色（`0xFFE91E63`）。
- M5 已把本地仓库目录和当前文档统一为 `EhBot-Mobile`；Dart/Android/iOS 发布标识不变。
  当前仓库没有 Git remote，远端仓库创建或配置后仍待推送。
- v0.1.0 MVP 验收线见 `DEVELOPMENT_PLAN.md` §1；M7/M8 落地后基线与版本会进一步升到 v0.2.0 / v0.3.0。
- 已知前置：开发机已装 Flutter 3.47.6 + Android SDK（android-36/build-tools 36.0.0/NDK 28.2），
  `flutter build apk --release` 已出多 ABI + universal 四份 APK；无 `/dev/kvm`、无真机、
  无 Chrome，故 `flutter run` 到 Android/web 仍不可行。后端 B1/B2 已完成，
  `POST /api/v1/auth/login` 可用于就绪探测。
- 未验证项：**没有真机 / 真实后端**，M1–M6 的验证是 analyze + 单测/widget 测试
  （MockClient 假后端）+ 对照 EhBot 源码核对字段；端到端待运营者用自己的部署试跑。
- 后续版本（不在本期）：iOS 商店签名发布、推送通知、主题 / 无障碍精修、APK 体积优化。
