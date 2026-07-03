---
name: commit-helper
description: 在需要生成 git commit 信息、拆分提交或审查暂存改动时使用。触发词：commit、提交、暂存、conventional commit。
---

# Commit Helper

当用户要求「提交」「写 commit message」「拆分改动」时，遵循以下流程。

## 步骤
1. 运行 `git status` 与 `git diff --staged` 了解改动。
2. 按「一个逻辑改动一个 commit」的原则判断是否需要拆分。
3. 生成 Conventional Commits 风格的信息：`type(scope): summary`。
4. 在真正执行 `git commit` 前，向用户展示拟定的 message 并征得确认。

## Commit message 规范
- type：`feat`/`fix`/`docs`/`refactor`/`test`/`chore` 等。
- summary：祈使句、简洁；必要时在正文补充「为什么」。
- 不要 `--amend` 或 force push 已推送内容，除非用户明确要求。
