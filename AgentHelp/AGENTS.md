# ehbot-mobile — Agent Notes

`EhBot` 的 Flutter 移动客户端。连接自建后端，用密码或 API Key 登录，浏览工作台 /
候选 / 活动 / 已下载，并对候选执行通过 / 驳回。

**依赖方向单向：本仓库 → EhBot 的 HTTP 契约。** 不复制后端业务代码，不反向依赖；
后端契约的事实以 `CONTRACT.md` 为准，后端一变先更新它。

## Session start

1. 先读 `PHASES.md`（各期一行 + `progress.md` 指针），再按需下钻 `progress.md`。
2. `codegraph` 对本仓库**帮助有限**：`codegraph doctor` 的原生语法列表不含 Dart
   （c/cpp/csharp/css/go/html/java/js/kotlin/less/php/python/ruby/rust/scss/sql/swift/ts/tsx/zig）。
   查 Dart 代码用 IDE / `dart analyze` / `grep -rn`；`.codegraph/` 已 git-ignored，
   `codegraph sync` 只对 Markdown/配置有有限价值，不要依赖它找符号。

## 工作约定：先写方案，后开工

**不可协商。** 一个任务不从 prompt 直接开写：

1. **先写方案**：任何可见行为改动，先写 `AgentHelp/<FEATURE>_PROPOSAL.md`：
   需求、现状、方案、备选、界面影响、后端契约影响、测试计划、要同步的文档。
2. **停下等审阅**：把方案交给运营者，等明确的开工指令。不要在「等审阅」期间顺手实现。
3. **审阅通过才实现**：一期 = 一个 commit，代码 / 测试 / `README.md` / `progress.md` /
   `PHASES.md` 一起提交。

## 文档同步是交付的一部分

- 功能、界面、行为一变，就同步改 `README.md` 与相关 `AgentHelp/*.md`，
  **包括删掉已经不存在的旧描述**。
- 每完成一期，在 `progress.md` 追加一条 **M 编号**条目（对照上一期保持相同格式），
  更新 `PHASES.md` 的状态与指针，并把测试基线数字写进本文件与 `progress.md`。
- 后端契约一变，先改 `CONTRACT.md`，再改代码。
- 若这次改动确实不触碰任何用户可见行为，提交说明写一句「无文档变更」，说明考虑过。

## 环境

- 本仓库当前在 Linux 容器里开发：`bash`、UTF-8、POSIX 工具链。
- **Flutter 3.47.6 stable**（Dart 3.13.5、DevTools 2.60.0；framework revision
  `5fc346839b`）装在 `/home/coder/flutter`，`flutter`/`dart` 已在 PATH
  （`/usr/local/bin` 软链 + `~/.bashrc`）。工程由 `flutter create --empty` 生成：
  包名 `ehbot_mobile`、org `com.ehbot`、平台 android/ios。装别处时先 `flutter --version`
  对齐版本，避免「我这是好的」类争议。
- **Android 工具链已装**（2026-10-04）：SDK 在 `/home/coder/Android/Sdk`
  （platform `android-36` + `android-35`、build-tools `36.0.0`、platform-tools、
  NDK `28.2.13676358`、CMake `3.22.1`），JDK 21 在 `/opt/java`；
  `~/.bashrc` 已导出 `JAVA_HOME` / `ANDROID_HOME` / `ANDROID_SDK_ROOT` / `PATH`。
  `flutter build apk --debug` 已验证通过，产物 `build/app/outputs/flutter-apk/app-debug.apk`。
- **内存坑（踩过一次，别再踩）**：本机 7.8G 内存、**无 swap**，而 Flutter 模板的
  `android/gradle.properties` 默认 `org.gradle.jvmargs=-Xmx8G`，首次构建会把 Gradle
  daemon OOM 掉（daemon 日志静默截断、无报错，容易误判成卡死）。**不要改仓库里那个值**
  （CI 需要），用环境变量覆盖：
  `GRADLE_OPTS='-Dorg.gradle.jvmargs=-Xmx3g -XX:MaxMetaspaceSize=1g -XX:ReservedCodeCacheSize=256m'`；
  另在 `~/.gradle/gradle.properties` 加 `kotlin.daemon.jvmargs=-Xmx1280m -XX:MaxMetaspaceSize=512m`
  限制 Kotlin 编译 daemon。后台跑构建要 `setsid nohup … &`，否则会话结束时整组进程被清理。
- **仍然做不到的**：无 `/dev/kvm` → 跑不了 Android 模拟器；无真机连接 → 无法 `flutter run`
  到 Android 设备；无 Chrome → web 目标不可用。也**没有真实后端**：M1–M4 的验证是
  `flutter analyze` + `flutter test`（MockClient 假后端）+ 对照 EhBot 源码核对响应字段，
  端到端待运营者用自己的部署试跑。
- 依赖：`http`、`flutter_secure_storage`、`shared_preferences`、`path_provider`。
- 写文件用 UTF-8、LF；改含中文的源文件优先用脚本（`io.open(..., encoding="utf-8",
  newline="\n")`），避免 shell 重定向把编码搞坏。
- 命令：`flutter pub get`、`flutter analyze`、`flutter test`、`dart format`。

## 测试基线

- 约定：`flutter analyze` 零告警；`flutter test` 的用例数作为基线，只增不减。
- **M4 基线：`90 tests / 0 failed`**（M0 = 1 → M1 = 45 → M2 = 56 → M3 = 76 → M4 = 90）。
  以后每期更新，格式「`N tests / 0 failed`」，并同步 `progress.md` 与 `PHASES.md` 的基线链。
- CI：`.github/workflows/ci.yml` 锁定 Flutter 3.47.6，push / PR 都跑 analyze + test。
- 后端回归基线（EhBot 侧）当前为 R52 = `1690 collected / 0 failed`；本仓库不改后端。

## 架构规则与不变量

- **鉴权**：`Authorization: Bearer <public_id>.<secret>`。两类凭据**族隔离**：
  - 密码登录 → access（默认 12h）+ refresh（默认 30d），两端都存服务端 DB，刷新即轮换；
  - API Key（`ehk_`）→ 不过期、全局最多一条有效、由网页端手动生成/刷新/撤销。
  - 改管理员密码只吊销密码认证族；刷新/撤销 Key 只影响 Key 认证族。客户端不得假设两者联动。
- **401 处理**：access 过期 → 用 refresh 自动换一次；refresh 也失败 → 回登录页。
  API Key 收到 401 → 提示「密钥无效或已被网页端刷新」，不要尝试 refresh。
- **凭据存储**：refresh token 与 API Key 只存 `flutter_secure_storage`（Keychain / Keystore）；
  access token 只放内存。**任何 token/密钥不得进日志、不得进崩溃上报。**
- **CSRF**：Bearer 请求不需要、也拿不到 CSRF；不要为 API 调用维护 cookie jar。
- **缩略图**：方案 A —— 客户端带鉴权加载器（复用鉴权 HTTP 客户端 + 磁盘缓存），
  后端零改动。响应头 `X-Thumbnail-State: failed` 时渲染本地占位，**不要解码后端
  返回的 SVG 占位图**。详见 `CONTRACT.md` §3。
- **实时**：优先消费 `/api/v1/events`（SSE，Dart 客户端可带 Authorization 头）；
  断流按 `/api/v1/meta` 的 `polling` 值回退轮询。
- **契约**：只用 `/api/v1`；响应信封与错误码见 `CONTRACT.md`。后端没加 `api.version`，
  用 `POST /api/v1/auth/login` 是否 404 判断后端是否就绪。

## 后端依赖

本仓库的可用性依赖 EhBot 仓库的 B1/B2 两期（见 `CONTRACT.md` §5）：

- B1：`api_credentials` 迁移 + `/api/v1/auth/*` + deps 统一接受 Bearer。
- B2：网页「设置 › 密码库」单 Key 管理面板。

B1/B2 未部署时，`/api/v1/auth/login` 返回 404，客户端应给出明确提示而不是崩溃。
