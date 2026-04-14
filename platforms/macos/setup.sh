#!/usr/bin/env bash
#
# platforms/macos/setup.sh — macOS 专属：tmux + zshrc + Ghostty 通知
#
# 由 scripts/setup.sh 调用（共享 Claude 配置已由上层完成）。
# 继承环境变量：REPO_ROOT, CLAUDE_DIR

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PLATFORM_DIR="$REPO_ROOT/platforms/macos"

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

MARKER_BEGIN_TMUX='# >>> claude-code-optimization >>>'
MARKER_END_TMUX='# <<< claude-code-optimization <<<'
MARKER_BEGIN_ZSH_VI='# >>> claude-code-vi-mode >>>'
MARKER_END_ZSH_VI='# <<< claude-code-vi-mode <<<'
MARKER_BEGIN_ZSH_CC='# >>> claude-code-shortcuts >>>'
MARKER_END_ZSH_CC='# <<< claude-code-shortcuts <<<'

remove_marker_block() {
    local file=$1 begin=$2 end=$3
    grep -qF "$begin" "$file" 2>/dev/null && sed -i '' "/$begin/,/$end/d" "$file"
}

insert_before() {
    local file=$1 pattern=$2 text=$3
    local bf of; bf=$(mktemp); of=$(mktemp)
    printf '%s\n' "$text" > "$bf"
    PAT="$pattern" awk -v bf="$bf" '
        index($0, ENVIRON["PAT"]) > 0 {
            while ((getline line < bf) > 0) print line
            print ""
        }
        { print }
    ' "$file" > "$of" && mv "$of" "$file"
    rm -f "$bf"
}

insert_after() {
    local file=$1 pattern=$2 text=$3
    local bf of; bf=$(mktemp); of=$(mktemp)
    printf '%s\n' "$text" > "$bf"
    PAT="$pattern" awk -v bf="$bf" '
        { print }
        index($0, ENVIRON["PAT"]) > 0 {
            print ""
            while ((getline line < bf) > 0) print line
        }
    ' "$file" > "$of" && mv "$of" "$file"
    rm -f "$bf"
}

# ==================== TMUX ====================
patch_tmux() {
    local file="$HOME/.tmux.conf"
    echo; echo "--- tmux ---"
    [ -f "$file" ] || { fail "~/.tmux.conf not found"; return 1; }

    remove_marker_block "$file" "$MARKER_BEGIN_TMUX" "$MARKER_END_TMUX"
    grep -qF '# --- Claude Code Integration ---' "$file" 2>/dev/null && sed -i '' '/^# --- Claude Code Integration ---$/,/^$/d' "$file"

    local block
    read -r -d '' block <<'BLK' || true
# >>> claude-code-optimization >>>

# Claude Code ↔ Ghostty bridge
set -g allow-passthrough on
set -g visual-bell off
set -g set-titles on
set -g set-titles-string '#S:#I #W — #{pane_current_path}'

# Launchers: prefix + C/S/P
bind C new-window -c "#{pane_current_path}" "claude"
bind S split-window -h -c "#{pane_current_path}" "claude"
bind P display-popup -w 80% -h 80% -d "#{pane_current_path}" "claude"

# mouse drag → pbcopy (macOS system clipboard)
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"

# <<< claude-code-optimization <<<
BLK

    if grep -qF '# --- Plugins' "$file"; then
        insert_before "$file" '# --- Plugins' "$block"
        info "tmux: block inserted before Plugins"
    else
        printf '\n%s\n' "$block" >> "$file"
        warn "tmux: Plugins section not found, appended"
    fi

    [ -n "${TMUX:-}" ] && tmux source-file "$file" 2>/dev/null && info "tmux: reloaded" || true
}

# ==================== ZSH ====================
patch_zshrc() {
    local file="$HOME/.zshrc"
    echo; echo "--- zshrc ---"
    [ -f "$file" ] || { fail "~/.zshrc not found"; return 1; }

    # Vi mode
    remove_marker_block "$file" "$MARKER_BEGIN_ZSH_VI" "$MARKER_END_ZSH_VI"
    local vi_block
    read -r -d '' vi_block <<'VI' || true
# >>> claude-code-vi-mode >>>
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
function _vi_mode_indicator() {
    case $KEYMAP in
        vicmd) echo -n '%F{red}[N]%f ' ;;
        *) echo -n '%F{green}[I]%f ' ;;
    esac
}
PROMPT='$(_vi_mode_indicator)'"$PROMPT"
# <<< claude-code-vi-mode <<<
VI

    if grep -qF 'source $ZSH/oh-my-zsh.sh' "$file"; then
        insert_after "$file" 'source $ZSH/oh-my-zsh.sh' "$vi_block"
        info "zsh: vi-mode inserted"
    else
        printf '\n%s\n' "$vi_block" >> "$file"
        warn "zsh: oh-my-zsh.sh source not found, appended vi-mode"
    fi

    # Claude Code shortcuts
    remove_marker_block "$file" "$MARKER_BEGIN_ZSH_CC" "$MARKER_END_ZSH_CC"
    grep -qF '# --- Claude Code ---' "$file" 2>/dev/null && sed -i '' '/^# --- Claude Code ---$/,/^}$/d' "$file"

    local cc_block
    read -r -d '' cc_block <<'CC' || true
# >>> claude-code-shortcuts >>>
alias cc='claude'
alias ccc='claude --continue'
alias ccr='claude --resume'
ccw() { tmux new-window -c "$(pwd)" "claude $*" }
ccl() {
    tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_command} #{pane_current_path}' \
        | grep -i claude
}
# <<< claude-code-shortcuts <<<
CC

    if grep -qF '# --- tmux window auto-rename ---' "$file"; then
        insert_before "$file" '# --- tmux window auto-rename ---' "$cc_block"
        info "zsh: shortcuts inserted"
    else
        printf '\n%s\n' "$cc_block" >> "$file"
        warn "zsh: tmux auto-rename section not found, appended shortcuts"
    fi
}

# ==================== NOTIFICATION ====================
install_notify_script() {
    echo; echo "--- notifications ---"

    local src="$PLATFORM_DIR/claude-notify.sh"
    local dst="$HOME/.claude/claude-notify.sh"

    [ -f "$src" ] || { fail "claude-notify.sh not found in $PLATFORM_DIR"; return 1; }
    mkdir -p "$HOME/.claude"
    cp "$src" "$dst" && chmod +x "$dst"
    info "installed $dst"

    # Ghostty config
    local gc="$HOME/.config/ghostty/config"
    if [ -f "$gc" ]; then
        grep -qF 'desktop-notifications' "$gc" || echo 'desktop-notifications = true' >> "$gc"
        grep -qF 'bell-features' "$gc" || echo 'bell-features = system,attention,title' >> "$gc"
        info "Ghostty config ensured"
    else
        warn "Ghostty config not found at $gc"
    fi

    # OMC integration
    local omc_cfg="$HOME/.claude/.omc-config.json"
    if [ -f "$omc_cfg" ] && command -v python3 &>/dev/null; then
        python3 - "$omc_cfg" "$dst" <<'PYEOF'
import json, sys
cfg_path, notify_path = sys.argv[1], sys.argv[2]
with open(cfg_path) as f: data = json.load(f)
integ = {
    "id": "macos-notify", "type": "cli", "preset": None, "enabled": True,
    "config": {"command": notify_path, "args": ["{{projectDisplay}}: {{reason}}"], "timeout": 5000},
    "events": ["session-end", "ask-user-question"]
}
ci = data.setdefault("customIntegrations", {"enabled": True, "integrations": []})
ci["enabled"] = True
items = ci.setdefault("integrations", [])
for i, it in enumerate(items):
    if it.get("id") == "macos-notify":
        items[i] = integ; break
else:
    items.append(integ)
with open(cfg_path, "w") as f: json.dump(data, f, indent=2); f.write("\n")
print("  [OK] OMC integration registered")
PYEOF
    fi
}

# ==================== CLEANUP ====================
cleanup() {
    echo; echo "--- cleanup ---"
    local kb="$HOME/.claude/keybindings.json"
    [ -f "$kb" ] && rm "$kb" && info "deleted $kb" || info "keybindings.json absent (correct)"
}

# ==================== VERIFY ====================
verify() {
    echo; echo "--- verify ---"
    local errors=0
    if tmux list-sessions &>/dev/null; then
        local pt; pt=$(tmux show-options -gv allow-passthrough 2>/dev/null)
        [ "$pt" = "on" ] && info "tmux allow-passthrough on" || { fail "tmux allow-passthrough: $pt"; ((errors++)); }
        local vb; vb=$(tmux show-options -gv visual-bell 2>/dev/null)
        [ "$vb" = "off" ] && info "tmux visual-bell off" || { fail "tmux visual-bell: $vb"; ((errors++)); }
    else
        warn "tmux not running, skipping runtime checks"
    fi
    [ -x "$HOME/.claude/claude-notify.sh" ] && info "claude-notify.sh installed" || { fail "claude-notify.sh missing"; ((errors++)); }
    grep -qF "$MARKER_BEGIN_ZSH_VI" "$HOME/.zshrc" && info "zsh vi-mode present" || { fail "zsh vi-mode missing"; ((errors++)); }
    grep -qF "$MARKER_BEGIN_ZSH_CC" "$HOME/.zshrc" && info "zsh shortcuts present" || { fail "zsh shortcuts missing"; ((errors++)); }

    [ "$errors" -eq 0 ] && echo && info "macOS setup: all checks passed" || fail "$errors check(s) failed"
}

main() {
    patch_tmux
    patch_zshrc
    install_notify_script
    cleanup
    verify
}

main "$@"
