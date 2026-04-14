# dev_env

跨平台开发环境 dotfiles + Claude Code 配置管理。

支持 **macOS / Debian / WSL**（Windows 原生暂留位）。

## 一键 bootstrap

```bash
git clone git@github.com:lzw19951010/dev_env.git ~/github/dev_env
cd ~/github/dev_env
bash scripts/setup.sh          # 自动检测平台
```

运行后将：

1. 把 `claude/` 下的共享配置合并进 `~/.claude/`（settings、personal-rules、prefs、commands、skills）
2. 按 `plugins.lock.json` 注册 marketplace 并安装 Claude Code 插件
3. 跑平台专属步骤（见下方"平台差异"）

指定平台覆盖自动检测：

```bash
bash scripts/setup.sh macos    # 或 debian / wsl
```

## 目录结构

```
claude/                  共享 Claude Code 配置（所有 OS 通用）
├── settings.base.json   全局 settings.json 合并基线
├── personal-rules.md    注入 ~/.claude/CLAUDE.md 的 OMC 块之后
├── prefs/*.md           可 @import 的偏好文件
├── commands/*.md        自定义 slash commands
└── skills/              OMC/Claude 技能（install.sh 用 symlink 装）

platforms/
├── macos/               tmux + zsh vi + Ghostty OSC9 通知
├── debian/              apt + oh-my-zsh + tpm + xclip + Ghostty terminfo
├── wsl/                 复用 debian + powershell.exe 通知桥接
└── windows/             未支持（占位）

scripts/
├── setup.sh             主入口：检测 OS → 共享步骤 → 平台 dispatch
├── diagnose.sh          环境健康检查（只读）
└── switch-account.sh    Claude 账号切换（macOS Keychain / Linux file）

plugins.lock.json        Claude Code 插件版本锁
CLAUDE.md                项目级 CLAUDE.md（给在此仓库里跑的 Claude 看）
docs/
└── debian-setup-notes.md  Debian 踩坑备忘（历史 issues）
```

## 平台差异

| 步骤 | macOS | Debian | WSL |
|---|---|---|---|
| 共享 Claude 配置 | all | all | all |
| 剪贴板 | pbcopy | xclip | xclip (需 WSLg) |
| 终端通知 | OSC 9 → Ghostty | OSC 9 → Ghostty SSH / notify-send | powershell.exe BurntToast |
| CLI 工具 | 假设 brew 已装 | apt + GitHub Releases | 同 debian |
| tmux 配置 | patch 现有 ~/.tmux.conf | 写入完整 tmux.conf + tpm | 同 debian |
| zshrc | vi-mode + 快捷键块 | 完整 oh-my-zsh 块 | 同 debian |
| Ghostty terminfo | 不需要 | 自动注入 | 同 debian |

## 诊断

```bash
bash scripts/diagnose.sh
```

打印系统/插件/配置/skills/磁盘用量报告。出现断裂符号链接会给出清理命令。

## 切换 Claude 账号

已封装为 skill，通过 `/switch-account` 或自然语言触发：

```
/switch-account list
/switch-account use Personal
/switch-account save Work
```

详见 `claude/skills/switch-account/SKILL.md`。

## 贡献 / 修改约定

- **共享改动**：改 `claude/` 下的源文件（不要直接改 `~/.claude/*`，会被下次 setup 覆盖）
- **平台差异**：只改 `platforms/<OS>/`，不要把平台代码混进 `scripts/setup.sh`
- **个人行为偏好**：写进 `claude/personal-rules.md`

## 手动后续步骤

`setup.sh` 不做、需要手动跑一次的：

- `chsh -s $(which zsh) $(whoami)`（设 zsh 为默认 shell，Debian/WSL 需要）
- 进入 tmux 后按 `prefix + I` 安装 tpm 插件
- Claude Code 会话里运行 `/oh-my-claudecode:omc-setup`（首次安装 OMC 插件后重建 symlinks）
