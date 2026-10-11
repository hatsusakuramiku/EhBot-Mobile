# EhBot-Mobile

EhBot 的 Flutter 移动客户端。连接自建的 EhBot 服务，用**密码**或 **API Key** 登录，
浏览工作台、候选、活动队列与已下载内容，并对候选执行通过 / 驳回。

- 服务端是另一个仓库 `EhBot`，本客户端只通过其 `/api/v1` 通信。
- 依赖的后端契约见 [`AgentHelp/CONTRACT.md`](AgentHelp/CONTRACT.md)。
- MVP 验收线与分期见 [`AgentHelp/DEVELOPMENT_PLAN.md`](AgentHelp/DEVELOPMENT_PLAN.md)。
- 环境与开发约定见 [`AgentHelp/AGENTS.md`](AgentHelp/AGENTS.md)；开工先读
  [`AgentHelp/PHASES.md`](AgentHelp/PHASES.md)。

## 前置

- Flutter **3.47.6** stable / Dart 3.13.5（安装路径、基线见 `AgentHelp/AGENTS.md`）。
- Android SDK 或 Xcode 之一（`flutter analyze` / `flutter test` 不需要，`flutter run` 需要）。
- 一个已部署并**已启用移动端鉴权**的 EhBot 服务端：需要 EhBot **R53 / R54**
  （凭据表 + `/api/v1/auth/*` + Bearer 通道），动作面另需 **R64–R69**。
  更早的版本 `POST /api/v1/auth/login` 会是 404。见 `CONTRACT.md`。

## 快速开始

    flutter pub get
    flutter run      # 需要 Android SDK 或 Xcode

质量门禁（本地与 CI 同一套，Flutter 锁定 3.47.6）：

    flutter analyze  # 要求零告警
    flutter test     # 当前基线 196 tests / 0 failed

发布（Android）：一次出 4 份 APK，目标平台在文件名里。需要在 `android/app/build.gradle.kts` 里开 `splits.abi` + `universalApk = true`（M6 follow-up）：

```
flutter build apk --release
# 输出：
#   app-arm64-v8a-release.apk     (~18 MB)
#   app-armeabi-v7a-release.apk   (~16 MB)
#   app-x86_64-release.apk        (~20 MB)
#   app-release.apk               (~53 MB, universal)
```

Google Play 分发用 `.aab`：

```
flutter build appbundle --release
# 输出 app-release.aab，Play 商店会按设备 ABI 自动分发拆分包
```

## 使用

登录后是五个页面（底部导航），顶栏可切换**多台服务器**：

- **工作台**：候选计数、活动概况（下载中 / 打包中）、需干预清单，以及
  「手动添加 / 一键去重」快捷入口。
- **候选**：tab（全部 / 待审核 / 待补充 / 已通过 / 已驳回 / 失败）+ 搜索 + 加载更多；
  点开是详情（封图、状态、元数据、时间线），底部可**通过 / 驳回**，成功后列表自动刷新。
  **长按**进入多选可批量通过 / 驳回；**右滑通过、左滑驳回**。
- **活动**：下载 / 打包队列按后端分组展示 + 已完成历史（本期只读）。
- **已下载**：搜索 + 加载更多；显示状态与打包状态。
- **日志**：运行日志历史 + 实时流（SSE），可切级别、可暂停。

- **设置**（AppBar 右上角图标）：**外观**（主题模式 + 配色方案，纯本机）、
  **服务器**（多台服务器的档案入口）、**当前凭据**（只读：用户名 / 凭据类型 /
  到期）、外部服务状态、启动告警、退出登录，以及**后端分区设置**
  （外部连接 / 来源规则 / 解析规则 / 自动审批 / 归档与工具 / 路径与命名 /
  AI 供应商 / 密码库 / 系统九个分区）。

## 设置

EhBot 是**单用户**系统：设置里没有任何「账号管理」，只有「当前这台服务器用的
是什么凭据」这一行只读信息；要换的是**服务器**（多台，不是多个账号）。

- **外观**：主题模式 + 配色，纯本机（见上一节）。
- **服务器**：进入档案列表，可添加 / 编辑 / 重命名 / 删除 / 切换。
- **后端分区设置**（九个分区）：
  - **可直接编辑**（EhBot R67–R69 已有写入端点）：
    **外部连接**（Telegram Bot Token / Telegram 用户 MTProto 登录与验证 /
    ExHentai Cookie，每条都能断开）、**系统**（并发、轮询间隔、时区、
    自动审批间隔、移动端 token 时长、日志等级、下载来源优先级）、
    **密码库**（归档密码增删、API Key 生成与撤销——明文只在生成的那一次显示）。
  - **目前只读**（`sources` / `parse` / `auto-approval` / `archive` / `paths` / `ai`）：
    按顶层字段分组展示，并说明「写入需要后端补 `/api/v1` 端点」。
  - 凭据**永不回显**：表单里永远是空输入框，后端快照只说「配没配」。

## 外观

设置 › 外观 可自由选择：**主题模式**（跟随系统 / 浅色 / 深色）与**配色方案**
（8 个预设色 + 色相滑块自定义）。纯本机偏好，存在 `SharedPreferences`
（`ehbot.theme_mode` / `ehbot.seed_color`），不涉及服务器。

## 多服务器

EhBot 没有多用户概念——顶栏的服务器入口管理的是**多台服务器**，不是多个账号。

- 顶栏显示当前服务器名，点开可**切换 / 编辑 / 重命名 / 删除 / 新增**。
- 切换服务器即切后端：当前服务器的登录状态会清除，落到那台的登录页。
- 旧版本只存过一台服务器的用户**无感升级**：首次启动自动迁移成一条档案。

> 设置里的九分区：**连接 / 系统 / 密码库**三区可直接编辑（EhBot R67–R69），
> 其余六区目前只有读（见 `CONTRACT.md` §7）；后端返回就渲染，404 则给出
> 「后端未就绪」提示，不会崩。
**实时**：客户端优先消费 `/api/v1/events`（SSE，带 `Authorization` 头）；
断流会按 `/api/v1/meta` 的 `polling.interval_ms` 自动回退轮询，并周期性重试恢复。
回退期间顶部会出现「实时连接已断开，已回退轮询」横幅，可手动重试；各页面在每次
实时 tick 到来时自动刷新。

## 作品详情与动作

点开任何页面中的候选 / 作品行都会打开详情页。

**操作在固定底栏**（对应 WebUI 的 sticky 动作条），不必滑到底才能点：通过 /
驳回 / 重新排队 / 四个来源 / 彻底删除 / 彻底删除并删文件。按钮可见性读后端**真实**
的 `actions`（`approve` / `reject` / `needs_revision` / `requeue` / `fetch_metadata` /
`convert` / `reconvert` / `edit_archive_path` / `sources[]`），客户端不自造键名。

- **通过 / 驳回**：`POST /api/v1/candidates/batch`，成功后回上一页并刷新列表。
- **重新排队**：`POST /api/v1/works/{id}/requeue`（只有后端说 `requeue` 为真时出现）。
- **元数据**：点一行即可改值、锁定（`PATCH /api/v1/works/{id}/metadata`）。
- **彻底删除 / 彻底删除并删文件**：`candidates/batch` 的 `delete` / `delete-files`，
  两次**不同**的确认文案；删不删文件在按下的那个按钮上就看得出来。能否删由服务端
  判定，被拒时按原因提示。
- **任务**：每个任务一张卡，带它自己的动作——重试 / 继续 / 暂停 / 取消 / 停止做种
  （可见性来自 `job_summary.actions`，路径一律用 **job id**）；停滞的种子再多两个
  切源入口（改用预览图源 / 用 Archive Download，后者会消耗 GP，先确认）。
- **后端 `/api/v1` 还没有的动作**（重获元数据 / 打包与重新打包 / 要求修订 /
  按来源拉取原档）渲染为**禁用**并说明原因，不会装成能点的按钮去撞 404。

正文另有：告警与 `warning_hint`、过滤说明（含来源：自动规则 / 人工 / 来源元数据规则）、
来源消息与附件、画廊 ID / 预览页 / 种子 / 磁力链、归档目录与文件名、
原始元数据与时间线。

## 登录

1. 服务器页填 `base_url`，例如 `https://ehbot.example.com`；反向代理有前缀时一并带上
   （对应后端 `APP_ROOT_PATH`）。「测试连接」会先探 `/healthz`，再用凭据探
   `GET /api/v1/auth/whoami`。
2. **密码登录**：用网页端管理员密码。全新部署必须先在网页端改掉初始密码，
   否则后端拒绝签发 token。
3. **API Key 登录**：在网页端「设置 › 密码库 › API 密钥（移动端）」生成，粘贴 `ehk_...`。
   全局同时只有一条有效 Key；网页端刷新后旧 Key 立即失效，各设备需重新粘贴。

## 文档

| 文档 | 内容 |
|------|------|
| `AgentHelp/PHASES.md` | **先读**：各期一行摘要 + `progress.md` 指针 |
| `AgentHelp/AGENTS.md` | 环境、架构规则、业务不变量、测试基线、工作约定 |
| `AgentHelp/progress.md` | 分期实施日志（逐条追加） |
| `AgentHelp/MOBILE.md` | 需求规格 |
| `AgentHelp/DEVELOPMENT_PLAN.md` | 分期计划与 MVP 验收线 |
| `AgentHelp/CONTRACT.md` | 依赖的后端 API 契约与最低后端版本 |
| `AgentHelp/MOBILE_CLIENT_PROPOSAL.md` | 已审阅的整体设计记录（含后端改动） |
| `AgentHelp/M1_AUTH_PROPOSAL.md` 等 | M1–M4 各期的实现设计记录（先方案后开工） |
| `CHANGELOG.md` | 版本变更与已知限制 |
