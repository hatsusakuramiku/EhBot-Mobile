# 方案：仓库改名 `ehbot-mobile` → `EhBot-Mobile`

> 状态：运营者已批准并于 2026-10-04 实施（本地完成，远端待配置）。
> 本方案只调整**仓库名**，不调整 App 的包名、applicationId / bundle ID 或发布身份。

## 1. 需求

把当前仓库名称从 `ehbot-mobile` 统一改为 `EhBot-Mobile`，并同步仓库内指向当前
仓库路径和仓库名称的文档，避免改名后出现失效路径或两套名称。

## 2. 现状

- 当前本地路径：`/home/coder/workspace/ehbot-mobile`。
- Git 当前分支为 `main`，工作区干净；`.git/config` 未配置任何远端，因此本次无法通过
  Git remote 同步修改托管平台上的仓库名。
- `README.md`、根 `AGENTS.md`、`AgentHelp/AGENTS.md`、`AgentHelp/MOBILE.md` 以及
  已批准的历史方案中仍有 `ehbot-mobile` 或旧绝对路径。
- `ehbot_mobile` 同时是 Flutter/Dart 包名，并出现在 Android namespace / applicationId、
  iOS bundle ID、Dart import 和平台配置中；它与仓库展示名不是同一个标识，本次不改。

## 3. 方案

### 3.1 本地仓库目录

审阅通过后执行：

```text
mv /home/coder/workspace/ehbot-mobile /home/coder/workspace/EhBot-Mobile
```

`git` 元数据随目录整体移动，不重建仓库、不改分支、不改历史。此后以
`/home/coder/workspace/EhBot-Mobile` 作为工作目录。

### 3.2 当前文档中的仓库名

把描述**当前仓库身份或当前路径**的引用统一改为 `EhBot-Mobile`：

- `README.md` 一级标题。
- 根 `AGENTS.md` 与 `AgentHelp/AGENTS.md` 标题及当前路径说明。
- `AgentHelp/MOBILE.md` 标题。
- 当前环境、阶段索引和任务说明中指向本仓库路径的引用。

### 3.3 历史方案记录

`AgentHelp/MOBILE_CLIENT_PROPOSAL.md` 是已经审阅通过的历史设计记录。为避免改写当时的
决策上下文，不逐段回写旧名称；在该文件顶部增加一条简短的重命名说明，注明历史文本里的
`ehbot-mobile` / 旧绝对路径均指现在的 `EhBot-Mobile`。

### 3.4 明确不改的标识

- Dart package：`ehbot_mobile`
- Android namespace / applicationId：`com.ehbot.ehbot_mobile`
- iOS bundle identifier：`com.ehbot.ehbotMobile`
- App 在系统中的显示名称

这些标识涉及 import、签名、安装升级和数据归属；若后续需要改，应另立发布迁移方案。

## 4. 备选（否决）

- **只移动目录，不更新文档**：会留下失效的绝对路径和两套仓库名，否决。
- **全局把 `ehbot-mobile` 替换成 `EhBot-Mobile`**：会改写历史方案记录，且容易误碰
  `ehbot_mobile` 包标识，否决。
- **同时改 Flutter 包名和 Android/iOS 标识**：影响全部 import、签名与已安装版本升级，
  超出“仓库改名”的范围，否决。
- **在本机修改托管平台仓库名**：当前仓库没有 Git remote，也没有可确认的托管平台信息，
  本次无法执行；以后配置远端时应同步更新远端仓库名和 URL。

## 5. 界面影响

无。App 的运行行为、界面文字和发布包标识不变。

## 6. 后端契约影响

无。请求路径、鉴权、响应处理和后端依赖均不变。

## 7. 测试计划

- 改名后从新路径确认 `git rev-parse --show-toplevel` 指向 `EhBot-Mobile`，工作区状态正常。
- 用 `git grep` 检查仓库名引用：除历史方案说明和包标识外，不再出现旧仓库路径。
- 运行 `flutter analyze`，要求零告警。
- 运行 `flutter test`，要求不低于现有基线 `90 tests / 0 failed`。

## 8. 文档同步

- 更新 `README.md`、根 `AGENTS.md`、`AgentHelp/AGENTS.md`、`AgentHelp/MOBILE.md`
  及当前路径引用。
- 在 `AgentHelp/MOBILE_CLIENT_PROPOSAL.md` 顶部补历史名称说明。
- 在 `AgentHelp/progress.md` 追加本次改名记录；若属于独立维护阶段，同时更新
  `AgentHelp/PHASES.md`。

## 9. 执行边界

本方案不含托管平台上的远端仓库改名或发布物重命名。当前仓库未配置 Git remote，
因此本次只完成本地目录、文档和本地提交；远端 URL / 凭据确认后再推送。
