# Claude Code 环境整合 — 待处理清单

> 上个会话学习了 Claude Code 各项特性，并从 7 个日常痛点出发做了大量改造。
> 本文件用于在新会话中继续推进剩余工作。

**上次更新**: 2026-04-14

---

## 背景（新会话读这一段就够）

我是 bytedance 的开发者，已有一个成熟的 dotfiles 仓库 `~/github/dev_env/`（git@github.com:lzw19951010/dev_env.git）管理 Claude Code + tmux + zsh 环境。

仓库已重构为**多平台架构**（macOS / Debian / WSL），见 `README.md`。

---

## 🔴 待处理

### 3. OMC 版本更新

- [ ] 当前：OMC npm 4.9.1 / plugin 4.10.2 / 最新 4.11.6 —— 运行 `omc update` 统一
- [ ] 更新后确认 `~/.claude/CLAUDE.md` 的 OMC 块是否会被覆盖（会丢掉个人规则吗？）
- [ ] 更新 `plugins.lock.json` 中 omc 版本号

### 4. 提交未决的改动

- [ ] `~/github/claude-howto/.gitignore` 增加了 `CLAUDE.local.md` 一行 —— 决定是否 commit 到 upstream
- [ ] `~/github/dev_env/scripts/switch-account.sh` 增加了 token 验证 + 自动 re-save 逻辑 —— 测试后 commit
- [ ] `~/github/claude-howto/.claude/agents/*.md`（3 个学习产物，被 `.claude/*` gitignore 了）—— 决定保留还是清理
- [ ] `~/github/dev_env/` 本次重构的全部改动 —— commit 并 push

---

## ✅ 已完成

### 1. 合并 `~/.claude/sync/` 到 `~/github/dev_env/` (2026-04-14)

- [x] `plugins.lock.json` 插件版本锁
- [x] `scripts/setup-claudecode-env.sh` → 新 `scripts/setup.sh`（多平台入口 + 共享 Claude 配置）
- [x] `scripts/diagnose.sh` 环境诊断
- [x] `notify-activate-ghostty.sh` 移入 `platforms/macos/`
- [x] `rm -rf ~/.claude/sync/`

### 2. 解决 CLAUDE.md 同步分裂问题 (2026-04-14)

- [x] 拆分：旧 28KB CLAUDE.md → `claude/personal-rules.md`（可注入 ~/.claude/CLAUDE.md）+ `claude/settings.base.json` + `docs/debian-setup-notes.md`（历史参考）
- [x] 新 `CLAUDE.md` 只保留项目级约定
- [x] `setup.sh` 中 `patch_claude_md` 函数自动注入 personal-rules（带 marker 块，幂等）
- [x] `patch_claude_settings` 函数自动合并 `settings.base.json` → `~/.claude/settings.json`

### 5. README.md (2026-04-14)

- [x] 仓库目标、bootstrap 流程、目录结构、平台差异表、诊断/账号切换说明

### 多平台重构 (2026-04-14)

- [x] `platforms/macos/setup.sh` — tmux + zsh vi-mode + Ghostty OSC9 通知
- [x] `platforms/debian/setup.sh` — apt 工具 + oh-my-zsh + tpm + xclip + terminfo + 分布式 FS 优化
- [x] `platforms/wsl/setup.sh` — 复用 debian + powershell.exe 通知桥接
- [x] `platforms/windows/README.md` — stub（设计留位）
- [x] 每个平台独立的 `claude-notify.sh`

---

## 🟡 延后的学习主题（原 self-assessment 未走完）

- **Hooks**（钩子）—— 事件驱动自动化，项目级强制规则。原学习路径的 Phase 1 第二项，暂停在此
- **自定义插件开发** —— 如何把 dev_env 的 skills/scripts 打包成一个正式的 Claude Code plugin（类似 oh-my-claudecode）

---

## 🎯 新会话建议的开场

> 读 `~/github/dev_env/TODO.md`。继续处理 **待处理 3**（OMC 更新）和 **待处理 4**（commit 并 push）。
