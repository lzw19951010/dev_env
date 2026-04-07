#!/bin/bash
#
# claude-notify.sh — Cross-platform notification for Claude Code
#
# Supports two environments:
#   1. Remote server (SSH + tmux + Ghostty): OSC 9 via tmux DCS passthrough
#   2. Local Mac (Ghostty, no tmux): OSC 9 directly to terminal
#   3. Local Mac (tmux + Ghostty): OSC 9 via tmux DCS passthrough
#   4. Fallback: terminal-notifier (macOS) or notify-send (Linux)
#
# How it works:
#   OSC 9 is a terminal escape sequence for desktop notifications.
#   Ghostty natively handles OSC 9 — even when the connection is:
#     Local Ghostty → SSH → remote tmux → DCS passthrough → OSC 9
#   The escape sequence travels back through the SSH tunnel to Ghostty.
#
# Prerequisites:
#   - Ghostty: desktop-notifications = true
#   - tmux (if used): allow-passthrough on
#
# Usage:
#   claude-notify.sh [message]
#
# Integration with Claude Code notifications hook:
#   Add to ~/.claude/settings.json:
#   "hooks": {
#     "Notification": [{
#       "type": "command",
#       "command": "/path/to/claude-notify.sh '{{message}}'"
#     }]
#   }
#

MESSAGE="${1:-Claude Code task complete}"

# --- Find a writable TTY ---
# Claude Code spawns subprocesses without a TTY, so we walk up the
# process tree to find the parent shell's TTY (the tmux pane).
find_tty() {
    # Method 1: walk up process tree
    local pid=$$
    for _ in {1..10}; do
        local ppid
        ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        [ -z "$ppid" ] || [ "$ppid" = "1" ] || [ "$ppid" = "0" ] && break
        local tty
        tty=$(ps -o tty= -p "$ppid" 2>/dev/null | tr -d ' ')
        if [ -n "$tty" ] && [ "$tty" != "??" ] && [ "$tty" != "?" ] && [ "$tty" != "-" ]; then
            echo "/dev/$tty"
            return 0
        fi
        pid=$ppid
    done

    # Method 2: find claude process TTY
    local claude_tty
    claude_tty=$(ps -eo pid,tty,comm 2>/dev/null | grep -E "claude$" | grep -v "??" | head -1 | awk '{print $2}')
    if [ -n "$claude_tty" ]; then
        echo "/dev/$claude_tty"
        return 0
    fi

    return 1
}

# --- Detect environment and send notification ---
send_notification() {
    local tty_device
    tty_device=$(find_tty)

    # If we have a TTY, use OSC 9 (works on both local and remote Ghostty)
    if [ -n "$tty_device" ]; then
        if [ -n "$TMUX" ]; then
            # Inside tmux: wrap OSC 9 in DCS passthrough
            # This works for both local tmux and remote tmux over SSH
            printf '\ePtmux;\e\e]9;%s\a\e\\' "$MESSAGE" > "$tty_device" 2>/dev/null
        else
            # Direct terminal (no tmux): send OSC 9 directly
            printf '\e]9;%s\a' "$MESSAGE" > "$tty_device" 2>/dev/null
        fi
        return 0
    fi

    # Fallback: platform-native notification tools
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS: try terminal-notifier, then osascript
        if command -v terminal-notifier &>/dev/null; then
            terminal-notifier -title "Claude Code" -message "$MESSAGE" -sound Glass 2>/dev/null
        else
            osascript -e "display notification \"$MESSAGE\" with title \"Claude Code\" sound name \"Glass\"" 2>/dev/null
        fi
    else
        # Linux: try notify-send
        if command -v notify-send &>/dev/null; then
            notify-send "Claude Code" "$MESSAGE" 2>/dev/null
        fi
    fi
}

send_notification
