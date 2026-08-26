# Changelog

本文件记录 cursor-standards 的版本变更。遵循 [Semantic Versioning](https://semver.org/)。

## [Unreleased]

## [0.2.0-test.3] - 2026-08-26

> **测试版本**（分支 `test1`，tag `v0.2.0-test.3`）。  
> 其他项目：`cursor-std install <目标> --version 0.2.0-test.3`

### Added
- Skill `add-e2e-test`：主路径定稿后按 stage 补页面 E2E / `data-testid`；含**小程序自动化占位**（不生成驱动）。
- `std-typescript.mdc`：单测与 E2E / testid / 小程序占位约定。
- REQ 模板「自动化」表；`使用指南` §5.2.1；smoke 校验 `add-e2e-test`。

### Changed
- `implement-req`：自动化两档（未定禁铺 / 定稿可补）；简报含 E2E、小程序、单测状态。
- `req-workflow` / `WORKFLOW.md`：步骤 ②′ 与口令「主路径已定，补 E2E」；区分 E2E vs 人工详测。
- `std-req-workflow` / `std-comments` / `sync-req-docs`：与上述对齐。

## [0.2.0-test.2] - 2026-08-24

> **测试版本**（分支 `test1`，tag `v0.2.0-test.2`）。  
> 其他项目：`cursor-std install <目标> --version 0.2.0-test.2`

### Changed
- 流程地图相关文案去业务化：去掉支付/弹层/登录等项目向举例，改为语言无关表述；示例改为通用「提交导出任务」流水线。

## [0.2.0-test.1] - 2026-08-24

> **测试版本**（分支 `test1`，tag `v0.2.0-test.1`）。首个公开发布的 git tag；正式版号可能仍调整。  
> 其他项目安装：`cursor-std install <目标> --version 0.2.0-test.1`（需本地 standards 源已 `git fetch --tags`）。

### Changed
- `std-readability.mdc`：新增「主流程可扫读」——唯一编排入口、流程地图（stage 1→N）、stage 命名约定；弹层/overlay 同样要薄入口；禁止为测试硬拆函数。
- `std-comments.mdc`：编排入口须写流程地图；主流程用 `// --- stageName ---` 分段（与地图/日志同名）；补支付示例。
- `implement-req`：实现主路径时补流程地图；结束简报强制含入口路径、stage 表、新增文件数、调用深度。
- `std-req-workflow.mdc`、`req-workflow` 口令模板 B：与上述简报字段对齐。
- `install --version`：自动 `fetch --tags`，并兼容带/不带 `v` 前缀的版本号。

### Added（随本 tag 一并首次发布，此前未打 tag）
- **REQ 文档驱动工作流**（从业务项目工作流抽离的通用包）：
  - 规则 `std-req-workflow.mdc`（摘要，`alwaysApply`）。
  - Skills：`req-workflow`（总览 + `WORKFLOW.md` + backlog/changelog assets）、`req-register`、`implement-req`、`sync-req-docs`。
  - 新命令 `cursor-std configure-req`：由用户提供 `--doc-root` / `--repo label=path`，写入不受 clean sync 覆盖的 `.cursor/rules/req-workflow.local.mdc`；可选 `--seed-docs` 初始化台账 stub、`--force` 覆盖已有配置。
- 新增两条常驻规则（`alwaysApply: true`，语言无关）：
  - `std-readability.mdc`：可读性优先——避免过度封装、控制调用深度（≤3 层）、拆分门槛，以及「可读优先、性能其次」并保留性能例外条款。
  - `std-comments.mdc`：面向 AI 生成代码的注释规范——必须注释项、详细程度门槛、无废话红线与反例/正例；正文中文、术语英文。
- `cursor-std remove [目标]`：卸载受管子目录与 lock，保留 `local.mdc` 与 hooks（Q6）。
- CI：`.github/workflows/ci.yml`（ubuntu/macos 跑 smoke 测试）与 `release-check.yml`（发版时断言 `VERSION == tag`，Q8）。
- 下发规则文件统一加 `std-` 前缀；`commit-helper` 通用版；`std-git-workflow` 补齐 type 与 footer。

## [0.1.0] - 2026-07-03

### Added
- `cursor-std` CLI（Bash，零运行时依赖）：`install` / `check` / `update` / `verify` / `init` / `version`。
- 分发机制：**copy + `.standards-lock.json` + clean sync + 完整性 manifest**。
  - clean sync：原子替换 `.cursor/rules/standards` 与 `.cursor/skills/standards`，传播上游删除，不触碰 `local.mdc` 等同级文件。
  - manifest：记录受管文件 sha256，`verify` 可检测手改 / 缺失 / 多余文件。
- 版本 pin：`install --version <tag>` / `--commit <sha>`（通过 `git archive`，不改动源工作树）。
- 全局安装：`install --global`（装到 `~/.cursor/`）。
- 首版规则：`general.mdc`、`git-workflow.mdc`（alwaysApply），`python.mdc`、`typescript.mdc`（glob 作用域）。
- 首版 skills：`commit-helper`、`pr-workflow`。
- sessionStart hook 模板 `check-standards.sh`：升级提醒三层降级（agent 注入 / stderr / marker 文件）+ 结果缓存。
- 引导脚本 `install.sh`（把 `cursor-std` 链接到 PATH）。
