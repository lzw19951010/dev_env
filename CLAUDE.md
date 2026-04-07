# Claude Code Configuration

## Permissions

- All tool calls are pre-authorized. Do not ask for confirmation.
- Bash commands: always allowed (including sudo, git, curl, install operations)
- File operations: always allowed (Read, Write, Edit, Glob, Grep)
- Task/Agent operations: always allowed
- Web operations: always allowed (WebFetch, WebSearch)

## Preferences

- Language: respond in the same language as the user (Chinese if user writes Chinese)
- Be concise, execute directly, don't over-explain
- When given a plan, execute it without asking for confirmation

## Model Settings

- **Effort level**: always use `high` (extended thinking enabled)
- **Output mode**: always use max output tokens — do not truncate or abbreviate responses
- These are enforced via `~/.claude/settings.json`: `effortLevel: "high"`, `alwaysThinkingEnabled: true`

---

# Personal Dev Environment Setup Plan

> Generated: 2026-02-10 | Platform: Debian 12 (bookworm) x86_64 (Linux 5.4.250)
> Base Image: base-image (Debian 12, CUDA 12.8)
> Shell: zsh 5.9 + oh-my-zsh | Terminal Multiplexer: tmux 3.3a

## Current State

| Tool | Status | Version | Source |
|------|--------|---------|--------|
| apt | ✅ | Debian 12 bookworm | base image |
| zsh | ✅ | 5.9 | base image (Dockerfile) |
| oh-my-zsh | ✅ | installed | base image (Dockerfile) |
| tmux | ✅ | 3.3a | base image (Dockerfile) |
| git | ✅ | 2.39.5 | base image |
| python3 | ✅ | 3.11.2 | base image |
| jq | ✅ | 1.6 | **this plan** |
| fzf | ✅ | 0.38.0 | **this plan** |
| fd | ✅ | 8.6.0 (fdfind, symlinked) | **this plan** |
| bat | ✅ | 0.22.1 (batcat, symlinked) | **this plan** |
| eza | ✅ | 0.23.4 (GitHub release) | **this plan** |
| zoxide | ✅ | 0.4.3 | **this plan** |
| lazygit | ✅ | 0.59.0 (GitHub release) | **this plan** |
| neovim | ✅ | 0.7.2 | **this plan** |
| node (symlink) | ✅ | v18.15.0 (auto-detected) | **this plan** |
| zsh-autosuggestions | ✅ | installed | **this plan** |
| zsh-syntax-highlighting | ✅ | installed | **this plan** |
| zsh-completions | ✅ | installed | **this plan** |
| tmux plugin manager (tpm) | ✅ | installed | **this plan** |
| xterm-ghostty terminfo | ✅ | ~/.terminfo/x/xterm-ghostty | **this plan** |
| oh-my-claudecode (OMC) | ✅ | plugin (git marketplace) | **this plan** |
| OMC HUD wrapper | ✅ | ~/.claude/hud/omc-hud.mjs | **this plan** |
| claude_settings.json | ✅ | ~/.claude/settings.json | pre-existing |
| account switcher (skill) | ✅ | skills/switch-account + scripts/switch-account.sh | **this plan** |

---

## Execution Plan

### Phase 1: Install CLI Tools via apt + GitHub Releases

```bash
# apt packages
sudo apt-get update && sudo apt-get install -y fzf fd-find bat zoxide neovim jq

# Create symlinks for Debian naming (fd-find -> fd, batcat -> bat)
sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd
sudo ln -sf /usr/bin/batcat /usr/local/bin/bat

# Node.js symlink (base image may have node outside PATH, auto-detect it)
NODE_BIN=$(find /opt /usr/local -name "node" -type f -executable 2>/dev/null | head -1)
[ -n "$NODE_BIN" ] && sudo ln -sf "$NODE_BIN" /usr/local/bin/node && echo "Linked: $NODE_BIN" || echo "WARN: node not found, install manually"

# eza (not in Debian repos, install from GitHub)
EZA_VERSION=$(curl -s https://api.github.com/repos/eza-community/eza/releases/latest | jq -r .tag_name)
curl -sL "https://github.com/eza-community/eza/releases/download/${EZA_VERSION}/eza_x86_64-unknown-linux-gnu.tar.gz" | sudo tar xz -C /usr/local/bin/

# lazygit (not in Debian repos, install from GitHub)
LG_VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | jq -r .tag_name)
curl -sL "https://github.com/jesseduffield/lazygit/releases/download/${LG_VERSION}/lazygit_${LG_VERSION#v}_Linux_x86_64.tar.gz" | sudo tar xz -C /usr/local/bin/ lazygit
```

**Tool descriptions:**
- **fzf** - Fuzzy finder for files, history, processes (Ctrl+R history search is amazing)
- **fd** - Modern `find` replacement, faster and more intuitive syntax
- **bat** - `cat` with syntax highlighting and git integration
- **eza** - Modern `ls` replacement with icons, git status, tree view
- **zoxide** - Smarter `cd` that learns your most used directories
- **lazygit** - Beautiful terminal UI for git operations
- **neovim** - Modern vim with better plugin ecosystem

**Debian-specific notes:**
- `fd` is packaged as `fd-find`, binary is `fdfind` - symlink to `/usr/local/bin/fd`
- `bat` is packaged as `bat`, binary is `batcat` - symlink to `/usr/local/bin/bat`
- `eza` and `lazygit` are not in Debian repos, installed from GitHub releases

### Phase 2: Install Zsh Plugins

> oh-my-zsh is pre-installed in the base-image Dockerfile, but only under `/root/.oh-my-zsh/`.
> If the runtime user is NOT root, must copy oh-my-zsh to `$HOME/.oh-my-zsh/` first.

```bash
# Copy oh-my-zsh to current user's HOME if not already present (Dockerfile installs to /root only)
if [ "$HOME" != "/root" ] && [ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
  mkdir -p "$HOME/.oh-my-zsh"
  rsync -a --ignore-existing /root/.oh-my-zsh/ "$HOME/.oh-my-zsh/"
  chown -R "$(whoami):$(id -gn)" "$HOME/.oh-my-zsh"
fi

# zsh-autosuggestions: fish-like autosuggestions based on history
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions

# zsh-syntax-highlighting: real-time syntax highlighting as you type
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# zsh-completions: additional completion definitions
git clone https://github.com/zsh-users/zsh-completions ~/.oh-my-zsh/custom/plugins/zsh-completions
```

### Phase 3: Update ~/.zshrc

The .zshrc preserves platform-specific workspace configs (sourced via `emulate bash` for zsh compatibility) and adds oh-my-zsh + tool integrations:

```zsh
# --- Platform/Workspace Config (preserve existing, bash-compat) ---
# NOTE: Paths below are platform-specific. Adjust to your environment.
# These source bash scripts from the base image's deploy directory.
emulate bash -c 'source /workspace/mlx/../vscode/prep_env.sh' 2>/dev/null
# greeting.sh 只在首次交互式 shell 显示（非 tmux 子窗口）
if [[ -z "$TMUX" || -z "$_GREETING_SHOWN" ]]; then
    sh -c "${PLATFORM_DEPLOY_DIR:-/opt/deploy}/greeting.sh" 2>/dev/null
    export _GREETING_SHOWN=1
fi
for rc_file in pythonpath_rc userrc; do
    local rc_path="${PLATFORM_DEPLOY_DIR:-/opt/deploy}/${rc_file}"
    [ -f "$rc_path" ] && emulate bash -c "source $rc_path" 2>/dev/null
done

# --- Oh My Zsh ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

# 禁用 git dirty check（git status 在分布式 FS 上非常慢）
DISABLE_UNTRACKED_FILES_DIRTY="true"

# 跳过每次启动的 compinit 安全检查（每天只检查一次）
ZSH_DISABLE_COMPFIX="true"
export ZSH_COMPDUMP="$HOME/.zcompdump-${SHORT_HOST}-${ZSH_VERSION}"

# --- Plugins ---
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  fzf
  extract                    # built-in, extract any archive
  sudo                       # built-in, press ESC twice to prepend sudo
)

source $ZSH/oh-my-zsh.sh

# 编译 zcompdump 加速后续加载
if [[ -f "$ZSH_COMPDUMP" && ( ! -f "${ZSH_COMPDUMP}.zwc" || "$ZSH_COMPDUMP" -nt "${ZSH_COMPDUMP}.zwc" ) ]]; then
    zcompile "$ZSH_COMPDUMP" &!
fi

# --- 检测是否在慢速文件系统上 ---
function _is_slow_fs() {
    [[ "$PWD" == /mnt/* ]] || [[ "$PWD" == /nfs/* ]]
}

# --- 覆盖 git_prompt_info：慢速 FS 上用缓存 + 跳过 dirty check ---
typeset -g _git_prompt_cache=""
typeset -g _git_prompt_cache_dir=""

function git_prompt_info() {
    # 同目录下使用缓存，避免每次 prompt 都调 git
    if [[ "$PWD" == "$_git_prompt_cache_dir" ]]; then
        echo -n "$_git_prompt_cache"
        return
    fi
    _git_prompt_cache_dir="$PWD"

    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        _git_prompt_cache=""
        return
    fi
    local ref
    ref=$(git symbolic-ref --short HEAD 2>/dev/null) || \
    ref=$(git rev-parse --short HEAD 2>/dev/null) || { _git_prompt_cache=""; return; }

    if _is_slow_fs; then
        # 慢速 FS：只显示分支名，跳过 git status (dirty check)
        _git_prompt_cache="${ZSH_THEME_GIT_PROMPT_PREFIX}${ref}${ZSH_THEME_GIT_PROMPT_CLEAN}${ZSH_THEME_GIT_PROMPT_SUFFIX}"
    else
        _git_prompt_cache="${ZSH_THEME_GIT_PROMPT_PREFIX}${ref}$(parse_git_dirty)${ZSH_THEME_GIT_PROMPT_SUFFIX}"
    fi
    echo -n "$_git_prompt_cache"
}

# cd 时清除缓存
function _clear_git_prompt_cache() { _git_prompt_cache_dir=""; }
add-zsh-hook chpwd _clear_git_prompt_cache

# --- fzf config (去掉 --follow，分布式 FS 上跟踪符号链接很慢) ---
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline'

# --- zoxide (smarter cd) ---
eval "$(zoxide init zsh)"

# --- Aliases - modern replacements ---
alias ls='eza --icons'
alias ll='eza -alh --icons --git'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never'
alias lg='lazygit'
alias vi='nvim'
alias vim='nvim'

# --- Git shortcuts ---
alias gst='git status'
alias gd='git diff'
alias glog='git log --oneline --graph --all'

# --- Quick navigation ---
alias pg='cd $HOME/playground'  # adjust to your playground path

# --- Editor ---
export EDITOR='nvim'
export VISUAL='nvim'

# --- tmux window auto-rename (带缓存，避免频繁 git 调用) ---
# 普通 shell 窗口：自动命名为 "目录:git分支"
# dmux Agent 窗口（$DMUX_PANE_ID 存在）：跳过，由 dmux hook 管理
typeset -g _tmux_git_branch=""
typeset -g _tmux_git_dir=""

function _tmux_update_branch() {
    # 只在切目录时更新 git branch 缓存
    if [[ "$PWD" != "$_tmux_git_dir" ]]; then
        _tmux_git_dir="$PWD"
        _tmux_git_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    fi
}

function _tmux_auto_rename() {
    [ -z "$TMUX" ] && return
    [ -n "$DMUX_PANE_ID" ] && return
    _tmux_update_branch
    local dir=$(basename "$PWD")
    local name="${dir}${_tmux_git_branch:+:$_tmux_git_branch}"
    tmux rename-window "$name"
}
# preexec: 命令开始时显示命令名（如 "claude"、"vim"、"python"）
function _tmux_preexec_rename() {
    [ -z "$TMUX" ] && return
    [ -n "$DMUX_PANE_ID" ] && return
    local cmd="${1%% *}"
    tmux rename-window "$cmd"
}
add-zsh-hook chpwd _tmux_auto_rename
add-zsh-hook preexec _tmux_preexec_rename
add-zsh-hook precmd _tmux_auto_rename
_tmux_auto_rename
```

**Notes:**
- Removed `z` plugin (conflicts with zoxide's `z` function)
- Removed `command-not-found` plugin (requires extra package on Debian)
- Platform scripts wrapped with `emulate bash` for zsh compatibility
- tmux window auto-rename: `preexec` hook 在命令运行时显示命令名，`precmd` hook 在命令结束后恢复 `目录:branch` 格式
- **分布式 FS 性能优化**：`git_prompt_info` 和 tmux rename hook 均带目录级缓存，`/mnt/*` 路径跳过 `git status` dirty check
- fzf 去掉 `--follow`，避免在网络 FS 上跟踪符号链接导致卡顿
- greeting.sh 在 tmux 子窗口中跳过（通过 `_GREETING_SHOWN` 环境变量）
- zcompdump 后台编译（`zcompile`），`ZSH_DISABLE_COMPFIX=true` 跳过安全检查

### Phase 4: Install Tmux Plugin Manager & Update ~/.tmux.conf

> tmux is pre-installed in the base-image Dockerfile, only need tpm + config.

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

`~/.tmux.conf`:

```tmux
# --- Preserve existing settings ---
set-window-option -g remain-on-exit on
set-option -g destroy-unattached off

# --- General ---
set-option -g default-shell /usr/bin/zsh
set-option -g history-limit 50000
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -sg escape-time 0
set -g focus-events on
set -g allow-passthrough on   # Allow OSC 9 notifications to pass through tmux to Ghostty
set -g allow-rename off      # 禁止应用程序通过 escape sequence 修改 window 名（由 zsh hook 统一管理）
setw -g automatic-rename on  # 全局默认开启，实际由 zsh preexec/precmd hook 调用 tmux rename-window 控制

# --- Vi mode ---
setw -g mode-keys vi
set -g @shell_mode 'vi'
set -g @yank_selection 'primary'

# --- Key Bindings ---
# Split panes preserving current path
bind '"' split-window -v -c "#{pane_current_path}"
bind % split-window -h -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"

# Vi-style pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Copy mode vi-style (Linux: use xclip)
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"

# Reload config
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# --- Status Bar ---
set -g status-position bottom
set -g status-interval 5
set -g status-style 'bg=#1e1e2e fg=#cdd6f4'
set -g status-left '#[fg=#1e1e2e,bg=#89b4fa,bold] #S #[default] '
set -g status-left-length 30
set -g status-right '#[fg=#a6adc8]%Y-%m-%d %H:%M '
set -g status-right-length 50
setw -g window-status-format '#[fg=#6c7086] #I:#W '
setw -g window-status-current-format '#[fg=#1e1e2e,bg=#a6e3a1,bold] #I:#W '

# --- Plugins (managed by tpm) ---
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-resurrect'    # save/restore sessions
set -g @plugin 'tmux-plugins/tmux-continuum'     # auto-save sessions

set -g @continuum-restore 'on'
set -g @resurrect-capture-pane-contents 'on'

# Initialize tpm (keep at bottom)
run '~/.tmux/plugins/tpm/tpm'
```

After saving:
```bash
# Set zsh as login shell (so new tmux sessions default to zsh)
sudo chsh -s /usr/bin/zsh $(whoami)

# Reload tmux config for running server
tmux source-file ~/.tmux.conf
```

Then inside tmux press `prefix + I` (capital I) to install plugins.

### Phase 5: Claude Code Settings

Ensure `~/.claude/settings.json` exists with full permissions and plugin config:

```bash
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'EOF'
{
    "permissions": {
        "allow": [
            "Bash",
            "Read",
            "Write",
            "Edit",
            "Glob",
            "Grep",
            "Task",
            "WebFetch",
            "WebSearch"
        ],
        "deny": []
    },
    "env": {
        "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": 1
    },
    "statusLine": {
        "type": "command",
        "command": "node $HOME/.claude/hud/omc-hud.mjs"
    },
    "enabledPlugins": {
        "superpowers@claude-plugins-official": true,
        "swift-lsp@claude-plugins-official": true,
        "oh-my-claudecode@omc": true
    },
    "extraKnownMarketplaces": {
        "omc": {
            "source": {
                "source": "git",
                "url": "https://github.com/Yeachan-Heo/oh-my-claudecode.git"
            }
        }
    },
    "effortLevel": "high",
    "notifications": {
        "enabled": true,
        "terminalBell": true
    },
    "editorMode": "vim",
    "omcHud": {
        "usageApiPollIntervalMs": 1000
    }
}
EOF
```

This file is loaded at Claude Code startup and grants all tool permissions automatically.

**Key settings explained:**
- `enabledPlugins` — 启用 oh-my-claudecode 插件（多 agent 编排）和 superpowers 插件
- `extraKnownMarketplaces` — 注册 OMC 的 git marketplace 源
- `statusLine` — 使用 OMC HUD 脚本显示状态栏（token 用量、成本等）
- `omcHud.usageApiPollIntervalMs: 1000` — HUD 每 1 秒刷新一次（默认 5s）
- `effortLevel: "high"` — 始终使用高 effort（extended thinking）
- `editorMode: "vim"` — 编辑器 vi 模式

### Phase 7: Install oh-my-claudecode (OMC) Plugin

oh-my-claudecode 是 Claude Code 的多 agent 编排插件，提供专业化 agent（architect、executor、reviewer 等）、自动化工作流（autopilot、ultrawork、ralph）和 HUD 状态显示。

**安装方式：** OMC 通过 Claude Code 的 plugin marketplace 机制安装，配置已在 Phase 5 的 `settings.json` 中声明。首次启动 Claude Code 时会自动从 git 仓库拉取插件。

```bash
# 验证插件已加载（在 Claude Code 会话中）
# 方式 1：检查 settings.json 中 OMC 配置
jq '.enabledPlugins["oh-my-claudecode@omc"]' ~/.claude/settings.json
# 应返回 true

# 方式 2：检查 marketplace 源
jq '.extraKnownMarketplaces.omc' ~/.claude/settings.json
# 应返回 omc git 仓库 URL

# 方式 3：在 Claude Code 中运行
# /oh-my-claudecode:omc-setup  — 初始化/诊断 OMC 安装
# /oh-my-claudecode:omc-doctor — 诊断并修复安装问题
```

**HUD 安装（插件安装后必须手动执行）：**

OMC 插件安装不会自动创建 HUD wrapper 脚本，需要手动执行：

```bash
# 1. 创建 HUD 目录
mkdir -p ~/.claude/hud

# 2. 创建 HUD wrapper 脚本（在 Claude Code 会话中执行）
# /oh-my-claudecode:hud setup
# 或手动写入 ~/.claude/hud/omc-hud.mjs（内容见 skills/hud/SKILL.md）

# 3. 验证 HUD 可运行
node ~/.claude/hud/omc-hud.mjs
# 应输出 "[OMC] HUD v4.x.x | preset: focused" 而非 "not found" 错误

# 4. 如果报 "Cannot find module" 错误（dist 编译不完整）：
# 检查 src/ 和 dist/ 的文件差异，手动转译缺失的 .ts -> .js 文件
# 已知 v4.11.1 缺失 dist/hud/elements/hostname.js
```

**注意：** `settings.json` 中的 `statusLine.command` 依赖 `node` 在 PATH 中（Phase 1 已添加 symlink）。如果 node 不在 PATH，HUD 会静默失败，不报错。

**OMC 核心功能：**
- **专业 Agent**：`architect`（架构分析）、`executor`（代码执行）、`code-reviewer`（代码审查）、`debugger`（调试）、`designer`（UI/UX）等
- **编排工作流**：`autopilot`（全自动）、`ultrawork`（并行执行）、`ralph`（循环直到完成）、`team`（多 agent 协作）
- **HUD 状态栏**：实时显示 token 用量、成本、会话时长（刷新频率 1s）
- **Skills 系统**：可扩展的技能库，支持自定义 skill 创建

### Phase 6: Fix Ghostty Terminal terminfo

Ghostty 终端设置 `TERM=xterm-ghostty`，但 Debian 12 系统没有对应的 terminfo 条目，导致依赖 terminfo 的程序（`less`、`clear`、`tmux` 等）报错 `missing or unsuitable terminal: xterm-ghostty`。

```bash
# 创建基于 xterm-256color 的 xterm-ghostty terminfo 别名
cat > /tmp/ghostty.terminfo << 'EOF'
xterm-ghostty|ghostty terminal emulator,
    use=xterm-256color,
EOF
tic -x /tmp/ghostty.terminfo
# 验证
infocmp xterm-ghostty > /dev/null 2>&1 && echo "OK" || echo "FAILED"
```

安装位置：`~/.terminfo/x/xterm-ghostty`（用户级，无需 sudo）

### Phase 8: Claude Code Account Switcher & Skill 安装

多账号切换工具，支持 macOS（Keychain）和 Linux（文件）双平台。已封装为 OMC skill，可通过 `/switch-account` 在 Claude Code 中原生调用。

**项目结构：**
```
scripts/switch-account.sh          # 核心脚本
skills/
├── install.sh                     # skill 安装脚本（symlink 方式）
└── switch-account/SKILL.md        # OMC skill 定义
```

**安装（必须执行）：**
```bash
# 将项目中的 skills 通过 symlink 安装到用户级 OMC skill 目录
./skills/install.sh
# → ~/.claude/skills/omc-learned/switch-account -> <project>/skills/switch-account/
```

安装后即可在 Claude Code 中使用：
- `/switch-account save Work` — 保存当前账号
- `/switch-account use Personal` — 切换账号
- `/switch-account list` — 列出所有 profile
- `/switch-account current` — 查看当前账号
- 或直接说"切换账号"、"switch account" 等关键词自动触发

**平台适配：**
| 平台 | 活跃凭证存储 | 读写方式 |
|------|-------------|---------|
| macOS | Keychain (`Claude Code-credentials`) | `security` 命令 |
| Linux | `~/.claude/.credentials.json` | 文件读写 |

Profile 统一存储在 `~/.claude/profiles/<name>.json`，跨平台通用。

**注意：** 切换后需重启 Claude Code 会话。HUD `organizationTag` 和 usage 缓存会自动更新。

---

## Post-Setup Verification

```bash
# Verify all tools are available
for cmd in fzf fd bat eza zoxide lazygit nvim jq; do
  printf "%-10s: " "$cmd"
  command -v $cmd >/dev/null 2>&1 && echo "OK - $($cmd --version 2>&1 | head -1)" || echo "MISSING"
done

# Verify zsh plugins
for p in zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
  printf "%-30s: " "$p"
  test -d ~/.oh-my-zsh/custom/plugins/$p && echo "OK" || echo "MISSING"
done

# Verify tpm
echo -n "tpm: " && test -d ~/.tmux/plugins/tpm && echo "OK" || echo "MISSING"

# Verify terminfo
echo -n "xterm-ghostty terminfo: " && infocmp xterm-ghostty > /dev/null 2>&1 && echo "OK" || echo "MISSING"

# Verify claude settings
echo -n "claude settings.json: " && test -f ~/.claude/settings.json && echo "OK" || echo "MISSING"

# Verify OMC HUD (requires node in PATH)
echo -n "node in PATH: " && command -v node >/dev/null 2>&1 && echo "OK - $(node --version)" || echo "MISSING - run Phase 1 node symlink step"
echo -n "OMC HUD script: " && test -f ~/.claude/hud/omc-hud.mjs && echo "OK" || echo "MISSING - run: /oh-my-claudecode:hud setup"
echo -n "OMC HUD renders: " && node ~/.claude/hud/omc-hud.mjs 2>&1 | grep -q "\[OMC\]" && echo "OK" || echo "FAILED - check node ~/.claude/hud/omc-hud.mjs output"

# Verify account switcher skill
echo -n "account switcher script: " && test -x scripts/switch-account.sh && echo "OK" || echo "MISSING"
echo -n "account switcher skill: " && test -L ~/.claude/skills/omc-learned/switch-account && echo "OK (symlink)" || echo "MISSING - run: ./skills/install.sh"
```

---

## Issues Fixed During Execution

1. **No Homebrew on Linux** - Replaced with `apt-get` for most tools; `eza` and `lazygit` installed from GitHub releases
2. **Debian package naming** - `fd` is `fd-find`/`fdfind`, `bat` is `batcat`; created `/usr/local/bin` symlinks
3. **Platform scripts bash-incompatible** - Wrapped with `emulate bash -c '...'` for zsh compatibility
4. **`z` plugin conflicts with zoxide** - Removed `z` plugin since zoxide provides the same `z` command
5. **`pbcopy` not available on Linux** - Replaced with `xclip -selection clipboard`
6. **tmux split pane NFS workaround unnecessary** - Simplified to standard `#{pane_current_path}`
7. **oh-my-zsh 安装在错误的 HOME 目录** - Dockerfile 以 root 安装 oh-my-zsh 到 `/root/.oh-my-zsh/`，但实际运行用户非 root（`$HOME` 不同）。Phase 2 的插件 clone 到了 `~/.oh-my-zsh/custom/plugins/`，但 oh-my-zsh 主体不在该目录下，导致 `source $ZSH/oh-my-zsh.sh` 失败。修复：`rsync -a --ignore-existing /root/.oh-my-zsh/ $HOME/.oh-my-zsh/` + `chown -R $(whoami):$(id -gn) $HOME/.oh-my-zsh`
8. **tmux window 名不随运行命令更新** - `tmux rename-window` 被显式调用时，tmux 会自动将该窗口的 `automatic-rename` 设为 off，导致后续无法自动更新窗口名。根本原因是 `.zshrc` 的 `chpwd` hook 只在切换目录时重命名，没有 `preexec` hook。修复：添加 `_tmux_preexec_rename`（命令开始时显示命令名）和 `precmd` → `_tmux_auto_rename`（命令结束后恢复 `目录:branch`）
9. **Claude Code + Ghostty + tmux 通知点击无法跳回终端** — 三层问题叠加：(a) Claude Code 子进程没有 TTY，BEL 字符无法到达 Ghostty；(b) tmux `visual-bell on` 拦截 BEL，转为视觉闪烁而非传递给 Ghostty；(c) macOS Sequoia 限制了 terminal-notifier 的 `-activate`/`-execute` 回调（Ghostty Discussion #10445）。修复：使用 OSC 9 escape sequence 通过 tmux DCS passthrough（`\ePtmux;\e\e]9;message\a\e\\`）直达 Ghostty，Ghostty 原生处理为桌面通知，点击自动激活 Ghostty 窗口。需要 tmux 设置 `allow-passthrough on` + `visual-bell off`，Ghostty 设置 `desktop-notifications = true`。脚本：`scripts/claude-notify.sh`
10. **Ghostty 终端 terminfo 缺失** - 使用 Ghostty 终端 SSH 连入时 `TERM=xterm-ghostty`，但系统无对应 terminfo 条目，导致 `missing or unsuitable terminal: xterm-ghostty` 错误（影响 `less`、`clear`、`tmux` 等依赖 terminfo 的程序）。修复：创建基于 `xterm-256color` 的 `xterm-ghostty` terminfo 别名并用 `tic` 编译安装到 `~/.terminfo/`
11. **分布式 FS 上 tmux/zsh 极慢** - `/mnt/*` 是分布式文件系统，git 操作延迟高。每次 prompt 触发 `git_prompt_info()`（内含 `git status`）和 `_tmux_auto_rename`（内含 `git branch --show-current`），累积延迟导致交互卡顿。修复：(1) 覆盖 `git_prompt_info` 加目录级缓存，`/mnt/*` 路径跳过 `parse_git_dirty`；(2) tmux rename hook 缓存 git branch 结果，只在 cd 时刷新；(3) `DISABLE_UNTRACKED_FILES_DIRTY=true` 全局禁用 untracked 检查；(4) fzf 去掉 `--follow`；(5) greeting.sh 在 tmux 子窗口跳过；(6) zcompdump 编译加速 + `ZSH_DISABLE_COMPFIX=true`
12. **node 不在 PATH 中** — 基础镜像中 node 安装在非标准路径下，没有 symlink 到 `/usr/local/bin/`。导致 `settings.json` 的 `statusLine` command 静默失败，HUD 不显示。修复：Phase 1 添加自动检测 + symlink 步骤
13. **OMC HUD wrapper 脚本未自动创建** — OMC 插件通过 marketplace 安装后，`~/.claude/hud/omc-hud.mjs` 不会自动生成，需要手动执行 `/oh-my-claudecode:hud setup` 或手动创建。原计划 Phase 7 缺失此步骤。修复：Phase 7 增加 HUD 安装步骤
14. **OMC v4.11.1 dist 编译不完整** — `src/hud/elements/hostname.ts` 存在但 `dist/hud/elements/hostname.js` 缺失，导致 HUD import 失败。上游打包 bug。修复：手动从 TS 源码转译缺失文件
16. **账号切换脚本跨平台适配** — 原版仅支持 Linux（直接读写 `~/.claude/.credentials.json`），macOS 上 Claude Code 使用 Keychain 存储凭证，直接操作文件无效。修复：抽象出 `read_active_creds`/`write_active_creds`/`has_active_creds` 三个平台适配函数，macOS 通过 `security` 命令读写 Keychain（service: `Claude Code-credentials`），Linux 保持文件方式。Profile 统一存 `~/.claude/profiles/<name>.json`，与平台无关
15. **zsh 启动在分布式 FS 上 1.1s→0.4s** - 根因：CWD 在 `/mnt/*` 时所有 shell 操作（stat/glob/git 等系统调用）都变慢，bare `zsh -c true` 就从 3ms 涨到 96ms。oh-my-zsh 加载 28 个文件累积放大到 1.1s。修复：(1) `.zshrc` 开头检测 `/mnt/*` 时 `cd /tmp`，加载完毕后 `cd` 回原目录；(2) 预先计算 `SHORT_HOST` 确保 `ZSH_COMPDUMP` 路径一致（之前路径不匹配导致每次都重跑 compinit 925ms）；(3) 用 no-op wrapper 劫持 oh-my-zsh 的 compinit 调用，预先用 `compinit -C` 快速加载；(4) 关闭 oh-my-zsh async git prompt（`zstyle ':omz:alpha:lib:git' async-prompt no`）；(5) `_tmux_auto_rename` 缓存窗口名，同名时跳过 `tmux rename-window` IPC。precmd 延迟从 200ms→20ms

## Pre-installed by base-image Dockerfile (skipped)

The following are already in the base Docker image and do **not** need installation:
- `tmux` / `zsh` / `ninja-build` — installed via `apt-get` in Dockerfile
- `oh-my-zsh` — installed for root + yarn user in Dockerfile
- `git` / `python3` / `pip` / `curl` / `wget` — from base image (lab.cuda.test)
