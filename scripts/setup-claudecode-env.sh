#!/usr/bin/env bash
#
# setup-claudecode-env.sh — Claude Code + tmux + zsh full-stack vi optimization
#
# Idempotent: safe to run multiple times. Uses marker blocks so re-runs
# replace previous patches instead of duplicating them.
#
# Prerequisites: macOS, Ghostty, tmux, zsh + oh-my-zsh, Claude Code installed
#
# Usage:
#   chmod +x scripts/setup-claudecode-env.sh
#   ./scripts/setup-claudecode-env.sh
#
set -euo pipefail

# --- Marker constants ---
MARKER_BEGIN_TMUX='# >>> claude-code-optimization >>>'
MARKER_END_TMUX='# <<< claude-code-optimization <<<'
MARKER_BEGIN_ZSH_VI='# >>> claude-code-vi-mode >>>'
MARKER_END_ZSH_VI='# <<< claude-code-vi-mode <<<'
MARKER_BEGIN_ZSH_CC='# >>> claude-code-shortcuts >>>'
MARKER_END_ZSH_CC='# <<< claude-code-shortcuts <<<'

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; }

# --- Helper: remove marker block from file ---
remove_marker_block() {
    local file=$1 marker_begin=$2 marker_end=$3
    if grep -qF "$marker_begin" "$file" 2>/dev/null; then
        sed -i '' "/$marker_begin/,/$marker_end/d" "$file"
    fi
}

# --- Helper: insert text before a pattern in file ---
# Usage: insert_before <file> <pattern> <text>
insert_before() {
    local file=$1 pattern=$2 text=$3
    local blockfile outfile
    blockfile=$(mktemp)
    outfile=$(mktemp)
    printf '%s\n' "$text" > "$blockfile"
    PAT="$pattern" awk -v bf="$blockfile" '
        index($0, ENVIRON["PAT"]) > 0 {
            while ((getline line < bf) > 0) print line
            print ""
        }
        { print }
    ' "$file" > "$outfile" && mv "$outfile" "$file"
    rm -f "$blockfile"
}

# --- Helper: insert text after a pattern in file ---
# Usage: insert_after <file> <pattern> <text>
insert_after() {
    local file=$1 pattern=$2 text=$3
    local blockfile outfile
    blockfile=$(mktemp)
    outfile=$(mktemp)
    printf '%s\n' "$text" > "$blockfile"
    PAT="$pattern" awk -v bf="$blockfile" '
        { print }
        index($0, ENVIRON["PAT"]) > 0 {
            print ""
            while ((getline line < bf) > 0) print line
        }
    ' "$file" > "$outfile" && mv "$outfile" "$file"
    rm -f "$blockfile"
}

# =====================================================================
# 1. TMUX CONFIG
# =====================================================================
patch_tmux() {
    local file="$HOME/.tmux.conf"
    echo ""
    echo "=== Patching ~/.tmux.conf ==="

    if [ ! -f "$file" ]; then
        fail "~/.tmux.conf not found, skipping"
        return 1
    fi

    # Remove previous marker block
    remove_marker_block "$file" "$MARKER_BEGIN_TMUX" "$MARKER_END_TMUX"

    # Also remove legacy non-marker Claude Code section (from earlier manual edits)
    if grep -qF '# --- Claude Code Integration ---' "$file"; then
        sed -i '' '/^# --- Claude Code Integration ---$/,/^$/d' "$file"
    fi

    # Build the patch block
    local block
    read -r -d '' block << 'TMUX_BLOCK' || true
# >>> claude-code-optimization >>>

# --- Claude Code Integration ---
# Notifications: allow OSC passthrough so Claude Code notifications reach Ghostty
set -g allow-passthrough on
# Terminal title: allow Claude Code to set window title
set -g set-titles on
set -g set-titles-string '#S:#I #W — #{pane_current_path}'

# --- Claude Code Launchers ---
# prefix + C  : new window with Claude Code
# prefix + S  : vertical split with Claude Code
# prefix + P  : popup (80x80%) for quick questions
bind C new-window -c "#{pane_current_path}" "claude"
bind S split-window -h -c "#{pane_current_path}" "claude"
bind P display-popup -w 80% -h 80% -d "#{pane_current_path}" "claude"

# --- Clipboard Unification ---
# Mouse drag select -> system clipboard (macOS pbcopy)
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"

# <<< claude-code-optimization <<<
TMUX_BLOCK

    # Insert before the Plugins section
    if grep -qF '# --- Plugins' "$file"; then
        insert_before "$file" '# --- Plugins' "$block"
        info "tmux: Claude Code block inserted before Plugins section"
    else
        # Fallback: append before tpm init
        echo "" >> "$file"
        echo "$block" >> "$file"
        warn "tmux: Plugins section not found, appended to end"
    fi

    # Reload tmux if running
    if [ -n "${TMUX:-}" ] || tmux list-sessions &>/dev/null; then
        tmux source-file "$file" 2>/dev/null && info "tmux: config reloaded" || warn "tmux: reload failed (reload manually with prefix + r)"
    fi
}

# =====================================================================
# 2. ZSH CONFIG
# =====================================================================
patch_zshrc() {
    local file="$HOME/.zshrc"
    echo ""
    echo "=== Patching ~/.zshrc ==="

    if [ ! -f "$file" ]; then
        fail "~/.zshrc not found, skipping"
        return 1
    fi

    # --- 2a. Vi Mode block ---
    remove_marker_block "$file" "$MARKER_BEGIN_ZSH_VI" "$MARKER_END_ZSH_VI"

    local vi_block
    read -r -d '' vi_block << 'VI_BLOCK' || true
# >>> claude-code-vi-mode >>>

# --- Vi Mode ---
bindkey -v
export KEYTIMEOUT=1

# Cursor shape: block for normal, beam for insert
function zle-keymap-select() {
    case $KEYMAP in
        vicmd) echo -ne '\e[2 q' ;;
        viins|main) echo -ne '\e[6 q' ;;
    esac
}
function zle-line-init() { echo -ne '\e[6 q' }
zle -N zle-keymap-select
zle -N zle-line-init

# Vi mode indicator prepended to prompt
function _vi_mode_indicator() {
    case $KEYMAP in
        vicmd) echo -n '%F{red}[N]%f ' ;;
        *) echo -n '%F{green}[I]%f ' ;;
    esac
}
PROMPT='$(_vi_mode_indicator)'"$PROMPT"

# <<< claude-code-vi-mode <<<
VI_BLOCK

    # Insert after "source $ZSH/oh-my-zsh.sh"
    if grep -qF 'source $ZSH/oh-my-zsh.sh' "$file"; then
        insert_after "$file" 'source $ZSH/oh-my-zsh.sh' "$vi_block"
        info "zsh: vi-mode block inserted after oh-my-zsh source"
    else
        echo "" >> "$file"
        echo "$vi_block" >> "$file"
        warn "zsh: oh-my-zsh source not found, appended vi-mode to end"
    fi

    # --- 2b. Claude Code shortcuts block ---
    remove_marker_block "$file" "$MARKER_BEGIN_ZSH_CC" "$MARKER_END_ZSH_CC"

    # Also remove legacy non-marker Claude Code section
    if grep -qF '# --- Claude Code ---' "$file"; then
        # Find and remove the old block (from alias cc to the closing brace of ccw)
        sed -i '' '/^# --- Claude Code ---$/,/^}$/d' "$file"
        # Clean up any leftover blank lines
        sed -i '' '/^# 在新 tmux 窗口中启动/d' "$file"
    fi

    local cc_block
    read -r -d '' cc_block << 'CC_BLOCK' || true
# >>> claude-code-shortcuts >>>

# --- Claude Code ---
alias cc='claude'
alias ccc='claude --continue'
alias ccr='claude --resume'

# Launch Claude Code in new tmux window (current directory)
ccw() { tmux new-window -c "$(pwd)" "claude $*" }

# List all running Claude Code instances across tmux
ccl() {
    tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_command} #{pane_current_path}' \
        | grep -i claude
}

# <<< claude-code-shortcuts <<<
CC_BLOCK

    # Insert before tmux auto-rename section
    if grep -qF '# --- tmux window auto-rename ---' "$file"; then
        insert_before "$file" '# --- tmux window auto-rename ---' "$cc_block"
        info "zsh: Claude Code shortcuts inserted before tmux auto-rename"
    else
        echo "" >> "$file"
        echo "$cc_block" >> "$file"
        warn "zsh: tmux auto-rename section not found, appended shortcuts to end"
    fi
}

# =====================================================================
# 3. CLAUDE CODE SETTINGS
# =====================================================================
patch_claude_settings() {
    local file="$HOME/.claude/settings.json"
    echo ""
    echo "=== Patching ~/.claude/settings.json ==="

    if [ ! -f "$file" ]; then
        warn "~/.claude/settings.json not found, creating minimal config"
        mkdir -p "$HOME/.claude"
        cat > "$file" << 'SETTINGS_EOF'
{
  "env": {
    "CLAUDE_CODE_NO_FLICKER": "1"
  },
  "editorMode": "vim"
}
SETTINGS_EOF
        info "claude: created settings.json with NO_FLICKER + vim mode"
        return
    fi

    # Use python3 to merge fields (available on macOS)
    python3 << 'PYEOF'
import json, sys

path = f"{__import__('os').environ['HOME']}/.claude/settings.json"
with open(path) as f:
    data = json.load(f)

changed = False

# Ensure env.CLAUDE_CODE_NO_FLICKER
if "env" not in data:
    data["env"] = {}
if data["env"].get("CLAUDE_CODE_NO_FLICKER") != "1":
    data["env"]["CLAUDE_CODE_NO_FLICKER"] = "1"
    changed = True

# Ensure editorMode = vim
if data.get("editorMode") != "vim":
    data["editorMode"] = "vim"
    changed = True

if changed:
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print("  [OK] claude: merged NO_FLICKER + editorMode=vim")
else:
    print("  [OK] claude: settings already up to date")
PYEOF
}

# =====================================================================
# 4. CLEANUP
# =====================================================================
cleanup() {
    echo ""
    echo "=== Cleanup ==="

    # Delete keybindings.json if it exists (all bindings are built-in defaults)
    local kb="$HOME/.claude/keybindings.json"
    if [ -f "$kb" ]; then
        rm "$kb"
        info "deleted ~/.claude/keybindings.json (unnecessary, all defaults)"
    else
        info "keybindings.json already absent"
    fi
}

# =====================================================================
# 5. VERIFY
# =====================================================================
verify() {
    echo ""
    echo "=== Verification ==="
    local errors=0

    # tmux
    if tmux list-sessions &>/dev/null; then
        local passthrough
        passthrough=$(tmux show-options -gv allow-passthrough 2>/dev/null)
        if [ "$passthrough" = "on" ]; then
            info "tmux allow-passthrough: on"
        else
            fail "tmux allow-passthrough: $passthrough (expected: on)"
            ((errors++))
        fi

        local titles
        titles=$(tmux show-options -gv set-titles 2>/dev/null)
        if [ "$titles" = "on" ]; then
            info "tmux set-titles: on"
        else
            fail "tmux set-titles: $titles (expected: on)"
            ((errors++))
        fi

        local claude_keys
        claude_keys=$(tmux list-keys 2>/dev/null | grep -c 'claude' || true)
        if [ "$claude_keys" -ge 3 ]; then
            info "tmux Claude Code keybindings: $claude_keys registered"
        else
            fail "tmux Claude Code keybindings: only $claude_keys found (expected >= 3)"
            ((errors++))
        fi

        local mouse_key
        mouse_key=$(tmux list-keys 2>/dev/null | grep -c 'MouseDragEnd.*pbcopy' || true)
        if [ "$mouse_key" -ge 1 ]; then
            info "tmux mouse drag -> clipboard: configured"
        else
            fail "tmux mouse drag -> clipboard: not found"
            ((errors++))
        fi
    else
        warn "tmux not running, skipping runtime verification"
    fi

    # Claude Code settings
    if [ -f "$HOME/.claude/settings.json" ]; then
        local editor_mode flicker
        editor_mode=$(python3 -c "import json; print(json.load(open('$HOME/.claude/settings.json')).get('editorMode',''))")
        flicker=$(python3 -c "import json; print(json.load(open('$HOME/.claude/settings.json')).get('env',{}).get('CLAUDE_CODE_NO_FLICKER',''))")
        if [ "$editor_mode" = "vim" ]; then
            info "claude editorMode: vim"
        else
            fail "claude editorMode: '$editor_mode' (expected: vim)"
            ((errors++))
        fi
        if [ "$flicker" = "1" ]; then
            info "claude NO_FLICKER: 1"
        else
            fail "claude NO_FLICKER: '$flicker' (expected: 1)"
            ((errors++))
        fi
    else
        fail "~/.claude/settings.json not found"
        ((errors++))
    fi

    # keybindings.json should not exist
    if [ -f "$HOME/.claude/keybindings.json" ]; then
        fail "~/.claude/keybindings.json still exists"
        ((errors++))
    else
        info "keybindings.json: absent (correct)"
    fi

    # zshrc markers
    if grep -qF "$MARKER_BEGIN_ZSH_VI" "$HOME/.zshrc"; then
        info "zsh vi-mode block: present"
    else
        fail "zsh vi-mode block: missing"
        ((errors++))
    fi
    if grep -qF "$MARKER_BEGIN_ZSH_CC" "$HOME/.zshrc"; then
        info "zsh Claude Code shortcuts: present"
    else
        fail "zsh Claude Code shortcuts: missing"
        ((errors++))
    fi

    echo ""
    if [ "$errors" -eq 0 ]; then
        echo -e "${GREEN}All checks passed!${NC}"
        echo ""
        echo "Quick reference:"
        echo "  tmux prefix + C   → new window with Claude Code"
        echo "  tmux prefix + S   → vertical split with Claude Code"
        echo "  tmux prefix + P   → popup Claude Code"
        echo "  tmux prefix + z   → toggle pane fullscreen"
        echo "  cc / ccc / ccr    → claude / --continue / --resume"
        echo "  ccw               → Claude Code in new tmux window"
        echo "  ccl               → list Claude Code instances"
        echo "  Ctrl+J            → newline in Claude Code"
        echo "  Ctrl+G            → edit prompt in nvim"
        echo "  Alt+P / Alt+T     → switch model / toggle thinking"
        echo ""
        echo "Note: run '/terminal-setup' inside Claude Code once to enable Shift+Enter."
    else
        echo -e "${RED}$errors check(s) failed. Review output above.${NC}"
    fi
}

# =====================================================================
# MAIN
# =====================================================================
main() {
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  Claude Code + tmux + zsh Full-Stack Vi Setup       ║"
    echo "╚══════════════════════════════════════════════════════╝"

    patch_tmux
    patch_zshrc
    patch_claude_settings
    cleanup
    verify
}

main "$@"
