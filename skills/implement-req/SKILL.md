---
name: implement-req
description: >-
  Implements a backlog REQ by reading the REQ ledger and changing configured code
  repos. Use when the user says「按 REQ 实现」「实现 REQ-xxx」「按 REQ-YYYYMMDD-xx 开发」,
  or asks to implement a backlog REQ without syncing docs yet.
---

# 实现 REQ（阶段 A）

按台账驱动改代码。本阶段**不**大改功能真相 / changelog / ops。

## 前置：路径配置

1. 读取 `.cursor/rules/req-workflow.local.mdc`。
2. 若缺失：停止并提示 `cursor-std configure-req`。**禁止猜测路径。**
3. 文档根：`backlog/REQ-index.md` + 可选 `REQ-*.md`；代码仓：配置表中的 label → 绝对路径。

## 必读顺序（先短后深）

1. 文档根下 `backlog/REQ-index.md` — 定位目标 `REQ-ID`
2. 若有详情：`backlog/REQ-*.md` 对应文件
3. 按需读功能真相文档**相关章节**（勿整本塞进上下文）
4. 在台账标明的端对应代码仓中定位页面/路由/接口后改代码

## 执行步骤

1. 确认 REQ-ID、类型、端（label）、验收句。
2. 范围外问题**另开 REQ**，勿塞进本单。
3. 可将台账状态改为 `开发中`；**不要**更新 changelog、功能真相、版本功能/测试、ops。
4. 实现保持最小改动；遵守各仓已有 coding rules。
5. Commit（仅当用户明确要求提交时）：Conventional Commits，footer 写同一 `REQ-ID`；多仓各自 commit 都带该 ID。

```text
feat(scope): 一句话

REQ-YYYYMMDD-XX
```

6. 结束后用中文简报：改了哪些端/文件、如何自测验收句、未做事项（文档同步留给阶段 B）。

## 禁止

- 未经用户确认就 `git commit` / `push`
- 「实现」阶段顺手批量改文档真相 / changelog / ops
- 把多个无关需求塞进一次实现
- 缺少本地路径配置时继续改码
