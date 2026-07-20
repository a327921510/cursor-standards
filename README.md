# cursor-standards

跨项目、跨语言、跨电脑统一分发 **Cursor Rules 与 Skills** 的中央仓库 + 通用 CLI（`cursor-std`）。

- **单一来源**：所有 Rules / Skills 维护在本仓库。
- **通用安装**：任意项目（Python / Node / Go / 混合）通过 `cursor-std` 一键同步，零运行时依赖（bash + git + coreutils）。
- **版本可追溯**：每次安装写入 `.standards-lock.json`（含 version / commit / 完整性 manifest）。
- **升级可提醒**：`check` 命令 + sessionStart hook。
- **分层共存**：中央规范放 `.cursor/rules/standards/`，项目本地规则放 `.cursor/rules/local.mdc`，互不干扰。

分发机制：**copy + `.standards-lock.json` + clean sync + manifest**。

## 快速开始

```bash
# 1. 克隆本仓库并把 CLI 装到 PATH
git clone <this-repo> ~/dev/cursor-standards
cd ~/dev/cursor-standards
./install.sh              # macOS / Linux
# ./install-windows.sh    # Windows：请在 Git Bash 中运行
export STANDARDS_HOME=~/dev/cursor-standards   # 建议写入 shell profile

# 2. 在任意项目中安装规范
cursor-std install /path/to/my-app

# 3. 日常检查与升级
cursor-std check  /path/to/my-app     # 有新版本时退出码为 1
cursor-std update /path/to/my-app

# 4. 首次接入（顺带写入升级提醒 hook）
cursor-std init   /path/to/my-app
```

| 系统 | 安装命令 |
|------|----------|
| macOS / Linux | `./install.sh` |
| Windows（Git Bash） | `./install-windows.sh` |

Windows 路径写成 `/d/project/...`，不要用 PowerShell / 系统自带的 `bash.exe`。详见 [`docs/使用指南.md`](docs/使用指南.md) §1。

## 仓库结构

```
cursor-standards/
├── VERSION                # 版本号（发版时与 git tag 对齐）
├── CHANGELOG.md
├── install.sh             # macOS / Linux：软链到 PATH
├── install-windows.sh     # Windows（Git Bash）：写 wrapper 到 PATH
├── bin/cursor-std         # CLI 入口
├── lib/                   # install / check / update / verify / init / common
├── rules/                 # 下发的 .mdc 规则（统一 std- 前缀）
├── skills/                # 下发的 SKILL.md 技能
├── templates/             # hooks.json + hooks/check-standards.sh
├── tests/                 # 冒烟测试（纯 bash）
├── .github/workflows/     # ci（smoke）+ release-check（VERSION==tag）
└── docs/                  # 使用指南、评审、待确认问题
```

详细命令与用法见 [`docs/使用指南.md`](docs/使用指南.md)。
需求、评审、设计决策与实现对照见 [`docs/设计文档.md`](docs/设计文档.md)。
