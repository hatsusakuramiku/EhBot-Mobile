# 阶段索引

> **先读这份**。每条一行摘要 + `progress.md` 的行号指针；要细节再下钻。
> 基线链（移动端）：**M0 待填**。后端基线在 EhBot 仓库，与本仓库分开记。

## 一、后端依赖（在 EhBot 仓库实施，本仓库只依赖）

| 编号 | 内容 | 状态 | 记录 |
|------|------|------|------|
| B1 | 凭据表迁移 `023` + `/api/v1/auth/*` + deps 接受 Bearer | 待实施 | EhBot `AgentHelp/MOBILE_CLIENT_PROPOSAL.md` §4、§7 |
| B2 | 网页「设置 › 密码库」单 Key 生成 / 刷新 / 撤销 | 待实施 | 同上 §4.5 |

## 二、本仓库阶段

| 编号 | 内容 | 状态 | 记录 |
|------|------|------|------|
| M0 | 建 Flutter 工程 + CI（analyze/test）+ 文档骨架核对 | **进行中**（文档已就位，工程未建） | `progress.md`（待追加） |
| M1 | 服务器配置页 + 密码 / API Key 双登录 + secure storage + 401 刷新拦截器 | 未开始 | `DEVELOPMENT_PLAN.md` §2 |
| M2 | 缩略图带鉴权加载器 + 磁盘缓存（方案 A） | 未开始 | `DEVELOPMENT_PLAN.md` §2、`CONTRACT.md` §3 |
| M3 | 工作台 / 候选列表与详情 / 通过驳回 / 活动队列 / 已下载列表 | 未开始 | `DEVELOPMENT_PLAN.md` §2 |
| M4 | SSE + 轮询回退 + 离线/错误态 + v0.1.0 打磨 | 未开始 | `DEVELOPMENT_PLAN.md` §2 |

## 三、当前状态

- 本仓库刚建立：**只有计划文档，没有 Dart 代码**。下一期是 M0。
- MVP 验收线见 `DEVELOPMENT_PLAN.md` §1；达成即 v0.1.0 可试用。
- 已知前置：开发机未装 Flutter SDK；后端 B1/B2 未实施。
