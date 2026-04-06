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

---

# Personal Dev Environment Setup Plan

> Generated: 2026-02-10 | Platform: Debian 12 (bookworm) x86_64 (Linux 5.4.250)
> Base Image: megatron_b200 (Debian 12, CUDA 12.8)
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
| zsh-autosuggestions | ✅ | installed | **this plan** |
| zsh-syntax-highlighting | ✅ | installed | **this plan** |
| zsh-completions | ✅ | installed | **this plan** |
| tmux plugin manager (tpm) | ✅ | installed | **this plan** |
| claude_settings.json | ✅ | ~/.claude/settings.json | pre-existing |

---

## Execution Plan

### Phase 1: Install CLI Tools via apt + GitHub Releases

```bash
# apt packages
sudo apt-get update && sudo apt-get install -y fzf fd-find bat zoxide neovim jq

# Create symlinks for Debian naming (fd-find -> fd, batcat -> bat)
sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd
sudo ln -sf /usr/bin/batcat /usr/local/bin/bat

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

> oh-my-zsh is pre-installed in the megatron_b200 Dockerfile, but only under `/root/.oh-my-zsh/`.
> If the runtime user is NOT root (e.g. `tiger`), must copy oh-my-zsh to `$HOME/.oh-my-zsh/` first.

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
emulate bash -c 'source /workspace/mlx/../vscode/prep_env.sh' 2>/dev/null
sh -c /opt/tiger/mlx_deploy/greeting.sh
if [ -f "/opt/tiger/mlx_deploy/pythonpath_rc" ]; then
    emulate bash -c 'source /opt/tiger/mlx_deploy/pythonpath_rc' 2>/dev/null
fi
if [ -f "/opt/tiger/rh2_bashrc" ]; then
    emulate bash -c 'source /opt/tiger/rh2_bashrc' 2>/dev/null
fi
emulate bash -c 'source /opt/tiger/mlx_deploy/userrc' 2>/dev/null

# --- Oh My Zsh ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

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

# --- fzf config ---
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
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

# --- Editor ---
export EDITOR='nvim'
export VISUAL='nvim'

# --- tmux window auto-rename ---
# 普通 shell 窗口：自动命名为 "目录:git分支"
# dmux Agent 窗口（$DMUX_PANE_ID 存在）：跳过，由 dmux hook 管理
function _tmux_auto_rename() {
    [ -z "$TMUX" ] && return
    [ -n "$DMUX_PANE_ID" ] && return
    local dir=$(basename "$PWD")
    local branch=$(git branch --show-current 2>/dev/null)
    local name="${dir}${branch:+:$branch}"
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

### Phase 4: Install Tmux Plugin Manager & Update ~/.tmux.conf

> tmux is pre-installed in the megatron_b200 Dockerfile, only need tpm + config.

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

Ensure `~/.claude/settings.json` exists with full permissions pre-authorized:

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
    }
}
EOF
```

This file is loaded at Claude Code startup and grants all tool permissions automatically.

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

# Verify claude settings
echo -n "claude settings.json: " && test -f ~/.claude/settings.json && echo "OK" || echo "MISSING"
```

---

## Issues Fixed During Execution

1. **No Homebrew on Linux** - Replaced with `apt-get` for most tools; `eza` and `lazygit` installed from GitHub releases
2. **Debian package naming** - `fd` is `fd-find`/`fdfind`, `bat` is `batcat`; created `/usr/local/bin` symlinks
3. **Platform scripts bash-incompatible** - Wrapped with `emulate bash -c '...'` for zsh compatibility
4. **`z` plugin conflicts with zoxide** - Removed `z` plugin since zoxide provides the same `z` command
5. **`pbcopy` not available on Linux** - Replaced with `xclip -selection clipboard`
6. **tmux split pane NFS workaround unnecessary** - Simplified to standard `#{pane_current_path}`
7. **oh-my-zsh 安装在错误的 HOME 目录** - Dockerfile 以 root 安装 oh-my-zsh 到 `/root/.oh-my-zsh/`，但实际运行用户是 `tiger`（`$HOME=/home/tiger`）。Phase 2 的插件 clone 到了 `~/.oh-my-zsh/custom/plugins/`（即 `/home/tiger/.oh-my-zsh/custom/plugins/`），但 oh-my-zsh 主体不在该目录下，导致 `source $ZSH/oh-my-zsh.sh` 失败，tmux 新窗口 zsh 无主题无补全。修复：`rsync -a --ignore-existing /root/.oh-my-zsh/ /home/tiger/.oh-my-zsh/` + `chown -R tiger:tiger`
8. **tmux window 名不随运行命令更新** - `tmux rename-window` 被显式调用时，tmux 会自动将该窗口的 `automatic-rename` 设为 off，导致后续无法自动更新窗口名。根本原因是 `.zshrc` 的 `chpwd` hook 只在切换目录时重命名，没有 `preexec` hook。修复：添加 `_tmux_preexec_rename`（命令开始时显示命令名）和 `precmd` → `_tmux_auto_rename`（命令结束后恢复 `目录:branch`）
9. **Claude Code + Ghostty + tmux 通知点击无法跳回终端** — 三层问题叠加：(a) Claude Code 子进程没有 TTY，BEL 字符无法到达 Ghostty；(b) tmux `visual-bell on` 拦截 BEL，转为视觉闪烁而非传递给 Ghostty；(c) macOS Sequoia 限制了 terminal-notifier 的 `-activate`/`-execute` 回调（Ghostty Discussion #10445）。修复：使用 OSC 9 escape sequence 通过 tmux DCS passthrough（`\ePtmux;\e\e]9;message\a\e\\`）直达 Ghostty，Ghostty 原生处理为桌面通知，点击自动激活 Ghostty 窗口。需要 tmux 设置 `allow-passthrough on` + `visual-bell off`，Ghostty 设置 `desktop-notifications = true`。脚本：`scripts/claude-notify.sh`

## Pre-installed by megatron_b200 Dockerfile (skipped)

The following are already in the base Docker image and do **not** need installation:
- `tmux` / `zsh` / `ninja-build` — installed via `apt-get` in Dockerfile
- `oh-my-zsh` — installed for root + yarn user in Dockerfile
- `git` / `python3` / `pip` / `curl` / `wget` — from base image (lab.cuda.test)
