# Changelog

本文件记录 cursor-standards 的版本变更。遵循 [Semantic Versioning](https://semver.org/)。

## [Unreleased]

### Added
- `cursor-std remove [目标]`：卸载受管子目录与 lock，保留 `local.mdc` 与 hooks（Q6）。
- CI：`.github/workflows/ci.yml`（ubuntu/macos 跑 smoke 测试）与 `release-check.yml`（发版时断言 `VERSION == tag`，Q8）。

### Changed
- 下发规则文件统一加 `std-` 前缀（`std-general.mdc` / `std-git-workflow.mdc` / `std-python.mdc` / `std-typescript.mdc`），避免与项目本地规则重名、`@` 引用歧义（Q7）。
- `commit-helper` skill 升级为**通用版**：不再绑定特定项目结构，type/scope/语言风格从当前仓库自适应推断（探测 commitlint / `.gitmessage` / `git log` 历史）。
  - 覆盖完整 Conventional Commits type 集合（含 `perf` / `build` / `ci` / `revert`）；澄清 `style` 仅指代码格式、UI 视觉改动归 `feat`/`fix`；补充 Breaking Change 与 `Closes #123` footer。
  - 默认**只读暂存区**、不自动 `git add`/`commit`；暂存区为空即停止并提示。
  - 增加遗漏/风险检查（构建产物、`.env`/密钥、调试代码），多主题时主动建议拆分为多条 commit。
  - 输出固定为两段：可直接复制的 message + 跨平台提交命令（bash HEREDOC / PowerShell / `-F` 文件）；subject 固定中文。
- `std-git-workflow.mdc`：补齐完整 type 列表、`style` 语义澄清、`build`/`ci` 归类、Breaking Change 与工单 footer，并指向 `commit-helper` skill。

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
