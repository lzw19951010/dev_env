---
name: switch-account
description: Claude Code 多账号切换 — 保存/切换/列出 profile，支持 macOS Keychain 和 Linux 文件凭证
triggers:
  - switch-account
  - 切换账号
  - 账号切换
  - profile
  - save account
  - use account
argument-hint: "<save|use|list|current|delete> [name]"
---

# Claude Code Account Switcher

## Purpose

在多个 Claude Code 账号之间快速切换（如 Work / Personal），无需反复登录登出。
切换后自动更新 HUD 显示当前账号。

## When to Activate

- 用户说"切换账号"、"switch account"、"save profile"、"use profile"
- 用户提到需要在多个 Claude Code 账号间切换
- 用户问"当前用的哪个账号"

## Script Location

脚本与本 skill 同仓库，路径解析优先级：
1. 当前目录: `scripts/switch-account.sh`
2. Skill 所在仓库: `$(dirname "$(readlink ~/.claude/skills/omc-learned/switch-account)")/../../scripts/switch-account.sh`
3. 固定路径: `~/github/dev_env/scripts/switch-account.sh`

## Workflow

### 保存当前账号为 profile

```bash
scripts/switch-account.sh save <名称>
```

先用 `claude` 正常登录一个账号，然后用 `save` 保存凭证快照。

### 切换到已保存的 profile

```bash
scripts/switch-account.sh use <名称>
```

切换后需要**重启 Claude Code 会话**才能生效。

### 列出所有 profile

```bash
scripts/switch-account.sh list
```

### 查看当前 profile

```bash
scripts/switch-account.sh current
```

### 删除 profile

```bash
scripts/switch-account.sh delete <名称>
```

## Platform Support

| 平台 | 活跃凭证存储 | 读写方式 |
|------|-------------|---------|
| macOS | Keychain (`Claude Code-credentials`) | `security` 命令 |
| Linux | `~/.claude/.credentials.json` | 文件读写 |

Profile 文件统一存储在 `~/.claude/profiles/<name>.json`，跨平台通用。

## Examples

```
# 典型工作流：先保存两个账号
scripts/switch-account.sh save Work
scripts/switch-account.sh save Personal

# 之后随时切换
scripts/switch-account.sh use Work
# → 重启 Claude Code 会话

# 查看当前
scripts/switch-account.sh current
# → 当前 profile: Work (pro/t1)
#   平台: macOS (Keychain)
```

## Notes

- 切换后必须重启 Claude Code 会话（凭证在启动时加载）
- HUD 的 `organizationTag` 会自动更新，状态栏显示当前账号名
- 切换时自动清除 usage-api 缓存，避免显示旧账号数据
