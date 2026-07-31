---
description: REQ 工作流 · 本项目路径（本地配置，不受 cursor-std clean sync 管理）
alwaysApply: true
---

# REQ 工作流 · 本项目路径

> 由 `cursor-std configure-req` 生成。手改后请自行保持与真实仓库一致。  
> 升级 standards（`install`/`update`）**不会**覆盖本文件。

## 路径表

| 角色 | 路径 |
|------|------|
| 文档根 | {{DOC_ROOT}} |
{{REPO_ROWS}}

## 相对文档根约定

| 用途 | 相对路径 |
|------|----------|
| 台账 | backlog/REQ-index.md |
| REQ 详情模板 | backlog/_template.md |
| 功能真相 | {{FEATURE_DOC}} |
| changelog | {{CHANGELOG}} |
| 操作手册 | ops/ |

## Agent 约定

- 登记 / 实现 / 归档前必须使用上表路径；禁止猜测未列出的仓库。
- 「端」列使用上表代码仓的 **label**。
- 细则见 `.cursor/skills/standards/req-workflow/WORKFLOW.md`。
