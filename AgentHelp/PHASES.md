# 阶段索引

> **先读这份**。每条一行摘要 + `progress.md` 的行号指针；要细节再下钻。
> 基线链（移动端）：**M0 = 1 → M1 = 45 → M2 = 56 → M3 = 76 → M4 = 90 → M5 = 90 tests / 0 failed**
> （`flutter analyze` 零告警）。后端基线在 EhBot 仓库，与本仓库分开记。

## 一、后端依赖（在 EhBot 仓库实施，本仓库只依赖）

| 编号 | 内容 | 状态 | 记录 |
|------|------|------|------|
| B1 | 凭据表迁移 `023` + `/api/v1/auth/*` + deps 接受 Bearer | 待实施 | EhBot `AgentHelp/MOBILE_CLIENT_PROPOSAL.md` §4、§7 |
| B2 | 网页「设置 › 密码库」单 Key 生成 / 刷新 / 撤销 | 待实施 | 同上 §4.5 |

## 二、本仓库阶段

| 编号 | 内容 | 状态 | 记录 |
|------|------|------|------|
| M0 | 建 Flutter 工程 + CI（analyze/test）+ 文档骨架核对 | **完成**（文档 + 工程 + CI 已就位） | `progress.md` M0 |
| M1 | 服务器配置页 + 密码 / API Key 双登录 + secure storage + 401 刷新拦截器 | **完成** | `progress.md` M1 |
| M2 | 缩略图带鉴权加载器 + 磁盘缓存（方案 A） | **完成** | `progress.md` M2 |
| M3 | 工作台 / 候选列表与详情 / 通过驳回 / 活动队列 / 已下载列表 | **完成** | `progress.md` M3 |
| M4 | SSE + 轮询回退 + 离线/错误态 + v0.1.0 打磨 | **完成** | `progress.md` M4 |
| M5 | 仓库改名 `ehbot-mobile` → `EhBot-Mobile` + 文档同步 | **本地完成**，远端待配置 | `progress.md` M5 |

## 三、当前状态

- M0–M4 已完成：文档骨架、Flutter 工程与 CI、双登录与会话保持、带鉴权的封面缓存、
  四块数据页与审核、SSE + 轮询回退；基线 `90 tests / 0 failed`，
  即 `DEVELOPMENT_PLAN.md` §1 的 v0.1.0 验收线（就绪待真机试跑）。
- M5 已把本地仓库目录和当前文档统一为 `EhBot-Mobile`；Dart/Android/iOS 发布标识不变。
  当前仓库没有 Git remote，远端仓库创建或配置后仍待推送。
- MVP 验收线见 `DEVELOPMENT_PLAN.md` §1；达成即 v0.1.0 可试用。
- 已知前置：开发机已装 Flutter 3.47.6 + Android SDK（android-36/build-tools 36.0.0/NDK 28.2），
  `flutter build apk --debug` 已通过；无 `/dev/kvm`、无真机、无 Chrome，故 `flutter run`
  到 Android/web 仍不可行。后端 B1/B2 未实施，`/api/v1/auth/login` 目前为 404。
- 未验证项：**没有真机 / 真实后端**，M1–M4 的验证是 analyze + 单测/widget 测试
  （MockClient 假后端）+ 对照 EhBot 源码核对字段；端到端待运营者用自己的部署试跑。
- 后续版本（不在本期）：活动页任务操作（重试 / 取消 / 优先级）、设置编辑、批量操作、
  日志实时流、推送、主题 / 无障碍精修、iOS 商店签名发布。
