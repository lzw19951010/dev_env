#!/bin/bash
#
# claude-notify.sh — Ghostty-native notification for Claude Code
#
# Problem: Claude Code runs in a subprocess without TTY access.
#   - terminal-notifier: reliable delivery, but click can't jump back (macOS Sequoia limitation)
#   - osascript display notification: can jump back, but unreliable delivery
#   - Ghostty bell (BEL): can jump back, but tmux intercepts/blocks the BEL character
#
# Solution: Send OSC 9 escape sequence through tmux DCS passthrough directly to Ghostty.
#   Ghostty treats OSC 9 as a native desktop notification — reliable delivery + click to jump back.
#
# Prerequisites:
#   - Ghostty with: desktop-notifications = true
#   - tmux with: allow-passthrough on, visual-bell off
#
# Usage:
#   claude-notify.sh [message]
#
# Integration with OMC (.omc-config.json):
#   "command": "/path/to/claude-notify.sh",
#   "args": ["{{projectDisplay}}: {{reason}}"]
#

MESSAGE="${1:-Claude Code task complete}"

# Find the TTY of the claude process's parent shell
find_claude_tty() {
    # Walk up from current PID to find a parent on a real TTY
    local pid=$$
    for _ in {1..10}; do
        local ppid
        ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        [ -z "$ppid" ] || [ "$ppid" = "1" ] || [ "$ppid" = "0" ] && break
        local tty
        tty=$(ps -o tty= -p "$ppid" 2>/dev/null | tr -d ' ')
        if [ -n "$tty" ] && [ "$tty" != "??" ]; then
            echo "/dev/$tty"
            return 0
        fi
        pid=$ppid
    done

    # Fallback: find claude process and its TTY
    local claude_tty
    claude_tty=$(ps -eo pid,tty,comm | grep -E "claude$" | grep -v "??" | head -1 | awk '{print $2}')
    if [ -n "$claude_tty" ]; then
        echo "/dev/$claude_tty"
        return 0
    fi

    return 1
}

TTY_DEVICE=$(find_claude_tty)
if [ -z "$TTY_DEVICE" ]; then
    # Fallback to terminal-notifier if TTY not found
    if command -v terminal-notifier &>/dev/null; then
        terminal-notifier -title "Claude Code" -message "$MESSAGE" -sound Glass 2>/dev/null
    fi
    exit 0
fi

# Send notification via appropriate method
if [ -n "$TMUX" ]; then
    # tmux: use DCS passthrough + OSC 9 to reach Ghostty
    printf '\ePtmux;\e\e]9;%s\a\e\\' "$MESSAGE" > "$TTY_DEVICE" 2>/dev/null
else
    # No tmux: send OSC 9 directly
    printf '\e]9;%s\a' "$MESSAGE" > "$TTY_DEVICE" 2>/dev/null
fi
