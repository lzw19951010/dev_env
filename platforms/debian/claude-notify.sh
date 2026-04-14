#!/bin/bash
# claude-notify.sh (Debian/Linux) — Cross-terminal notification
#
# 优先级：
#   1. 如果在 tmux 里，通过 DCS passthrough 发 OSC 9（Ghostty SSH 用户能看到桌面通知）
#   2. 裸终端：直接 OSC 9（Ghostty/WezTerm/Kitty 等支持）
#   3. 最后退回 notify-send（本地 Linux 桌面）
#
# 前置：tmux 需要 'set -g allow-passthrough on'
#
# Usage: claude-notify.sh [message]

set -uo pipefail

MESSAGE="${1:-Claude Code notification}"

find_tty() {
    local pid=$$
    for _ in 1 2 3 4 5; do
        local tty
        tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ -n "$tty" ] && [ "$tty" != "?" ]; then
            echo "/dev/$tty"
            return 0
        fi
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        [ -z "$pid" ] || [ "$pid" = "1" ] && break
    done
    return 1
}

# 如果在 tmux 内 或者 stdout 是 tty：OSC 9 路径
if [ -n "${TMUX:-}" ]; then
    tty=$(find_tty) || tty=""
    if [ -n "$tty" ] && [ -w "$tty" ]; then
        # tmux DCS passthrough：\ePtmux;\e<escape-seq>\e\\
        printf '\ePtmux;\e\e]9;%s\a\e\\' "$MESSAGE" > "$tty"
        exit 0
    fi
elif [ -t 1 ]; then
    printf '\e]9;%s\a' "$MESSAGE"
    exit 0
fi

# Fallback: local desktop
if command -v notify-send &>/dev/null; then
    notify-send "Claude Code" "$MESSAGE"
    exit 0
fi

# 最后退路：写 stderr
echo "[claude-notify] $MESSAGE" >&2
