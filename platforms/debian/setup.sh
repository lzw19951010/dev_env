#!/usr/bin/env bash
#
# platforms/debian/setup.sh — Debian 12+ 开发机：CLI 工具 + zsh 插件 + tmux + Ghostty 通知
#
# 典型场景：SSH 进入干净的 Debian 容器/服务器，从头配置一套开发环境。
# 继承 REPO_ROOT, CLAUDE_DIR 由 scripts/setup.sh 注入（独立运行时自动推断）。

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PLATFORM_DIR="$REPO_ROOT/platforms/debian"

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

MARKER_BEGIN_TMUX='# >>> claude-code-optimization >>>'
MARKER_END_TMUX='# <<< claude-code-optimization <<<'

SUDO=""
if [ "$EUID" -ne 0 ] && command -v sudo &>/dev/null; then
    SUDO="sudo"
fi

# ==================== TOOLS: apt + GitHub Releases ====================
install_cli_tools() {
    echo; echo "--- CLI tools (apt + GitHub releases) ---"
    if ! command -v apt-get &>/dev/null; then
        fail "apt-get not available; this script targets Debian/Ubuntu"
        return 1
    fi

    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq \
        fzf fd-find bat zoxide neovim jq xclip curl git zsh tmux python3 || warn "some apt packages failed"

    # Debian naming → symlinks
    [ -e /usr/bin/fdfind ] && $SUDO ln -sf /usr/bin/fdfind /usr/local/bin/fd
    [ -e /usr/bin/batcat ] && $SUDO ln -sf /usr/bin/batcat /usr/local/bin/bat

    # node symlink（基础镜像可能把 node 安装在非标准路径）
    if ! command -v node &>/dev/null; then
        local node_bin
        node_bin=$(find /opt /usr/local -name 'node' -type f -executable 2>/dev/null | head -1)
        if [ -n "$node_bin" ]; then
            $SUDO ln -sf "$node_bin" /usr/local/bin/node
            info "node linked: $node_bin → /usr/local/bin/node"
        else
            warn "node not found; install manually (npm/Claude Code 需要 node)"
        fi
    fi

    # eza (not in Debian repos)
    if ! command -v eza &>/dev/null; then
        local ver
        ver=$(curl -fsSL https://api.github.com/repos/eza-community/eza/releases/latest | jq -r .tag_name)
        if [ -n "$ver" ] && [ "$ver" != "null" ]; then
            curl -fsSL "https://github.com/eza-community/eza/releases/download/${ver}/eza_x86_64-unknown-linux-gnu.tar.gz" \
                | $SUDO tar xz -C /usr/local/bin/ && info "eza $ver installed"
        else
            warn "eza: could not fetch latest version"
        fi
    fi

    # lazygit
    if ! command -v lazygit &>/dev/null; then
        local ver
        ver=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | jq -r .tag_name)
        if [ -n "$ver" ] && [ "$ver" != "null" ]; then
            curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/${ver}/lazygit_${ver#v}_Linux_x86_64.tar.gz" \
                | $SUDO tar xz -C /usr/local/bin/ lazygit && info "lazygit $ver installed"
        else
            warn "lazygit: could not fetch latest version"
        fi
    fi
}

# ==================== ZSH + oh-my-zsh ====================
install_zsh_plugins() {
    echo; echo "--- zsh plugins ---"

    # oh-my-zsh：Dockerfile 可能只装在 /root，非 root 用户需要复制
    if [ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
        if [ -d /root/.oh-my-zsh ] && [ "$HOME" != "/root" ]; then
            mkdir -p "$HOME/.oh-my-zsh"
            rsync -a --ignore-existing /root/.oh-my-zsh/ "$HOME/.oh-my-zsh/" 2>/dev/null || cp -r /root/.oh-my-zsh/* "$HOME/.oh-my-zsh/"
            chown -R "$(whoami):$(id -gn)" "$HOME/.oh-my-zsh" 2>/dev/null || true
            info "oh-my-zsh copied from /root → $HOME"
        else
            warn "oh-my-zsh not found; install via 'sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\"'"
            return
        fi
    fi

    local custom="$HOME/.oh-my-zsh/custom/plugins"
    mkdir -p "$custom"
    for repo in zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
        if [ ! -d "$custom/$repo" ]; then
            git clone --depth 1 "https://github.com/zsh-users/$repo" "$custom/$repo" && info "$repo installed" || warn "$repo clone failed"
        else
            info "$repo already present"
        fi
    done
}

# ==================== ZSHRC ====================
patch_zshrc() {
    echo; echo "--- .zshrc ---"
    local file="$HOME/.zshrc"
    touch "$file"

    # 移除旧块
    local begin='# >>> dev-env-debian >>>'
    local end='# <<< dev-env-debian <<<'
    if grep -qF "$begin" "$file"; then
        # portable sed -i（Debian 是 GNU sed）
        sed -i "/$begin/,/$end/d" "$file"
    fi

    cat >> "$file" <<'ZSHRC'
# >>> dev-env-debian >>>

# --- Oh My Zsh ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
DISABLE_UNTRACKED_FILES_DIRTY="true"
ZSH_DISABLE_COMPFIX="true"
export ZSH_COMPDUMP="$HOME/.zcompdump-$(hostname -s)-${ZSH_VERSION}"

plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions fzf extract sudo)
source $ZSH/oh-my-zsh.sh 2>/dev/null

# zcompdump 后台编译
if [[ -f "$ZSH_COMPDUMP" && ( ! -f "${ZSH_COMPDUMP}.zwc" || "$ZSH_COMPDUMP" -nt "${ZSH_COMPDUMP}.zwc" ) ]]; then
    zcompile "$ZSH_COMPDUMP" &!
fi

# 分布式 FS 识别 + git prompt 缓存
function _is_slow_fs() { [[ "$PWD" == /mnt/* ]] || [[ "$PWD" == /nfs/* ]]; }

typeset -g _git_prompt_cache=""
typeset -g _git_prompt_cache_dir=""
function git_prompt_info() {
    if [[ "$PWD" == "$_git_prompt_cache_dir" ]]; then echo -n "$_git_prompt_cache"; return; fi
    _git_prompt_cache_dir="$PWD"
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then _git_prompt_cache=""; return; fi
    local ref
    ref=$(git symbolic-ref --short HEAD 2>/dev/null) || ref=$(git rev-parse --short HEAD 2>/dev/null) || { _git_prompt_cache=""; return; }
    if _is_slow_fs; then
        _git_prompt_cache="${ZSH_THEME_GIT_PROMPT_PREFIX}${ref}${ZSH_THEME_GIT_PROMPT_CLEAN}${ZSH_THEME_GIT_PROMPT_SUFFIX}"
    else
        _git_prompt_cache="${ZSH_THEME_GIT_PROMPT_PREFIX}${ref}$(parse_git_dirty)${ZSH_THEME_GIT_PROMPT_SUFFIX}"
    fi
    echo -n "$_git_prompt_cache"
}
function _clear_git_prompt_cache() { _git_prompt_cache_dir=""; }
autoload -U add-zsh-hook && add-zsh-hook chpwd _clear_git_prompt_cache

# fzf
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline'

# zoxide
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# Modern replacements
command -v eza &>/dev/null && { alias ls='eza --icons'; alias ll='eza -alh --icons --git'; alias lt='eza --tree --level=2 --icons'; }
command -v bat &>/dev/null && alias cat='bat --paging=never'
command -v lazygit &>/dev/null && alias lg='lazygit'
command -v nvim &>/dev/null && { alias vi='nvim'; alias vim='nvim'; export EDITOR='nvim'; export VISUAL='nvim'; }

alias gst='git status'
alias gd='git diff'
alias glog='git log --oneline --graph --all'

# Claude Code shortcuts
alias cc='claude'
alias ccc='claude --continue'
alias ccr='claude --resume'
ccw() { tmux new-window -c "$(pwd)" "claude $*" }

# Vi mode
bindkey -v
export KEYTIMEOUT=1
function zle-keymap-select() {
    case $KEYMAP in
        vicmd) echo -ne '\e[2 q' ;;
        viins|main) echo -ne '\e[6 q' ;;
    esac
}
function zle-line-init() { echo -ne '\e[6 q' }
zle -N zle-keymap-select
zle -N zle-line-init

# tmux window auto-rename
typeset -g _tmux_git_branch="" _tmux_git_dir=""
function _tmux_update_branch() {
    if [[ "$PWD" != "$_tmux_git_dir" ]]; then
        _tmux_git_dir="$PWD"
        _tmux_git_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    fi
}
function _tmux_auto_rename() {
    [ -z "$TMUX" ] && return
    [ -n "${DMUX_PANE_ID:-}" ] && return
    _tmux_update_branch
    local dir=$(basename "$PWD")
    tmux rename-window "${dir}${_tmux_git_branch:+:$_tmux_git_branch}" 2>/dev/null
}
function _tmux_preexec_rename() {
    [ -z "$TMUX" ] && return
    [ -n "${DMUX_PANE_ID:-}" ] && return
    tmux rename-window "${1%% *}" 2>/dev/null
}
add-zsh-hook chpwd _tmux_auto_rename
add-zsh-hook preexec _tmux_preexec_rename
add-zsh-hook precmd _tmux_auto_rename

# <<< dev-env-debian <<<
ZSHRC
    info "patched $file (块: $begin .. $end)"
}

# ==================== TMUX ====================
install_tpm_and_conf() {
    echo; echo "--- tmux tpm + config ---"
    [ -d "$HOME/.tmux/plugins/tpm" ] || git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"

    local file="$HOME/.tmux.conf"
    touch "$file"
    if grep -qF "$MARKER_BEGIN_TMUX" "$file"; then
        sed -i "/$MARKER_BEGIN_TMUX/,/$MARKER_END_TMUX/d" "$file"
    fi

    # 直接把权威 tmux.conf 写入（Debian 下没有 pbcopy，用 xclip）
    cat >> "$file" <<'TMUX'
# >>> claude-code-optimization >>>

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
set -g allow-passthrough on
set -g allow-rename off
setw -g automatic-rename on
set -g visual-bell off
set -g set-titles on
set -g set-titles-string '#S:#I #W — #{pane_current_path}'

setw -g mode-keys vi

bind '"' split-window -v -c "#{pane_current_path}"
bind % split-window -h -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"

bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

bind C new-window -c "#{pane_current_path}" "claude"
bind S split-window -h -c "#{pane_current_path}" "claude"
bind P display-popup -w 80% -h 80% -d "#{pane_current_path}" "claude"

# Copy mode → xclip (Linux system clipboard)
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"

bind r source-file ~/.tmux.conf \; display "Config reloaded!"

set -g status-position bottom
set -g status-interval 5
set -g status-style 'bg=#1e1e2e fg=#cdd6f4'
set -g status-left '#[fg=#1e1e2e,bg=#89b4fa,bold] #S #[default] '
set -g status-right '#[fg=#a6adc8]%Y-%m-%d %H:%M '

set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore 'on'
set -g @resurrect-capture-pane-contents 'on'

run '~/.tmux/plugins/tpm/tpm'

# <<< claude-code-optimization <<<
TMUX
    info "patched $file"
    [ -n "${TMUX:-}" ] && tmux source-file "$file" 2>/dev/null || true
}

# ==================== GHOSTTY terminfo ====================
install_ghostty_terminfo() {
    echo; echo "--- xterm-ghostty terminfo ---"
    if infocmp xterm-ghostty &>/dev/null; then
        info "xterm-ghostty terminfo already present"
        return
    fi
    if ! command -v tic &>/dev/null; then
        warn "tic not found (apt install ncurses-bin)"
        return
    fi
    local tmp; tmp=$(mktemp)
    cat > "$tmp" <<'TERMINFO'
xterm-ghostty|ghostty terminal emulator,
    use=xterm-256color,
TERMINFO
    tic -x "$tmp" 2>/dev/null && info "xterm-ghostty terminfo installed" || warn "tic failed"
    rm -f "$tmp"
}

# ==================== NOTIFICATION ====================
install_notify_script() {
    echo; echo "--- notifications ---"
    local src="$PLATFORM_DIR/claude-notify.sh"
    local dst="$HOME/.claude/claude-notify.sh"

    if [ ! -f "$src" ]; then
        fail "$src not found"
        return 1
    fi
    mkdir -p "$HOME/.claude"
    cp "$src" "$dst" && chmod +x "$dst"
    info "installed $dst"
}

# ==================== VERIFY ====================
verify() {
    echo; echo "--- verify ---"
    local errs=0
    for cmd in fzf fd bat eza zoxide lazygit nvim jq xclip; do
        if command -v "$cmd" &>/dev/null; then
            info "$cmd"
        else
            fail "$cmd missing"; ((errs++))
        fi
    done
    [ -d ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions ] && info "zsh-autosuggestions" || { fail "zsh-autosuggestions missing"; ((errs++)); }
    [ -d ~/.tmux/plugins/tpm ] && info "tpm" || { fail "tpm missing"; ((errs++)); }
    [ -x ~/.claude/claude-notify.sh ] && info "claude-notify.sh" || { fail "claude-notify.sh missing"; ((errs++)); }

    if [ "$errs" -eq 0 ]; then
        echo && info "Debian setup: all checks passed"
        echo "后续手动步骤："
        echo "  1. chsh -s \$(which zsh) \$(whoami)     # 设置 zsh 为默认 shell"
        echo "  2. 进入 tmux 后按 prefix + I 安装 tpm 插件"
    else
        fail "$errs check(s) failed"
    fi
}

main() {
    install_cli_tools
    install_zsh_plugins
    patch_zshrc
    install_tpm_and_conf
    install_ghostty_terminfo
    install_notify_script
    verify
}

main "$@"
