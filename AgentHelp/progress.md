# 实施日志

> 新条目追加在**文件末尾**（与 EhBot 相反，本仓库从零开始，顺序阅读即可）。
> 每条对照上一条保持相同格式；基线数字每期更新。

## 条目格式

```
## M<n> · <日期> · <一句话主题>

- 版本：
- 测试基线：<N tests / 0 failed>（`flutter analyze` 零告警）
- 后端依赖：B1 / B2 是否已部署
- 改动：<主要文件与行为>
- 验证：<跑了什么命令，结果如何>
- 文档：<README/AgentHelp 改了哪些；无变更则写明>
```

---

## M0 · 2026-10-03 · Flutter 工程骨架 + CI（analyze / test 首基线）

- 版本：Flutter 3.47.6 stable（Dart 3.13.5、DevTools 2.60.0，framework revision `5fc346839b`）
- 测试基线：`1 tests / 0 failed`（`flutter analyze` 零告警）
- 后端依赖：B1 / B2 均未部署；M0 不依赖后端（`/api/v1/auth/login` 仍会是 404）
- 改动：`flutter create --empty`（包名 `ehbot_mobile`、org `com.ehbot`、平台 android/ios）；
  `lib/main.dart` 引导 + `lib/ui/app.dart` 骨架页；`lib/api`、`lib/state`、`lib/media`
  三层占位落位（M1 / M2 填充）；`test/app_test.dart` 首条 widget 测试；
  `.github/workflows/ci.yml`（Flutter 3.47.6，`flutter analyze` + `flutter test`）。
- 验证：`flutter analyze` → No issues found!；`flutter test` → All tests passed!（1 条）；
  `dart format lib test` → 0 changed。
- 文档：`README.md`（前置 / 快速开始改为真实命令与基线）、`AgentHelp/AGENTS.md`
  （环境与测试基线）、`AgentHelp/PHASES.md`（M0 完成 + 基线链）、`AgentHelp/task_plan.md`。
