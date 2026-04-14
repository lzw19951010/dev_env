# platforms/windows/

**Status**: Not yet supported.

日常 Windows 环境通过 WSL 使用（见 `../wsl/`）。如果未来需要原生 PowerShell 上跑 Claude Code，在此补一份 `setup.ps1`：

## 计划做的事

- PowerShell profile 注入：等价于 zshrc 的 vi-mode + 快捷键
- Claude Code plugins 安装（复用仓库根目录的 `plugins.lock.json`）
- Windows Terminal 配置：`desktop-notifications`
- `claude-notify.ps1`：BurntToast 或 Windows Toast API
- 可执行工具（fd/bat/eza/lazygit）通过 scoop 或 winget 安装

## 被 scripts/setup.sh 调用的约定

当 `scripts/setup.sh` 检测到 `MINGW/MSYS/CYGWIN` 时，会执行 `platforms/windows/setup.sh`（未来也可加 setup.ps1 分派）。
目前该文件不存在，orchestrator 会打印 warning 并继续。
