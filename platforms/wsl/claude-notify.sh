#!/bin/bash
# claude-notify.sh (WSL) — Cross Windows/Linux notification
#
# 尝试顺序：
#   1. tmux 内且回 Ghostty/WT：OSC 9 via DCS passthrough
#   2. wsl-notify-send.exe（若安装）
#   3. WSLg 下的 notify-send（Win11 原生）
#   4. powershell.exe 弹 MessageBox（最后退路）
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

# 1. tmux + OSC 9
if [ -n "${TMUX:-}" ]; then
    tty=$(find_tty) || tty=""
    if [ -n "$tty" ] && [ -w "$tty" ]; then
        printf '\ePtmux;\e\e]9;%s\a\e\\' "$MESSAGE" > "$tty"
        exit 0
    fi
fi

# 2. wsl-notify-send (https://github.com/stuartleeks/wsl-notify-send)
if command -v wsl-notify-send.exe &>/dev/null; then
    wsl-notify-send.exe --category "Claude Code" "$MESSAGE"
    exit 0
fi

# 3. WSLg notify-send
if command -v notify-send &>/dev/null && [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
    notify-send "Claude Code" "$MESSAGE"
    exit 0
fi

# 4. PowerShell toast (BurntToast 模块若安装) 或 MessageBox 退路
if command -v powershell.exe &>/dev/null; then
    # BurntToast is the clean path; fall back to a bare msg box
    powershell.exe -NoProfile -Command "
        if (Get-Module -ListAvailable -Name BurntToast) {
            Import-Module BurntToast
            New-BurntToastNotification -Text 'Claude Code', '$MESSAGE'
        } else {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show('$MESSAGE', 'Claude Code') | Out-Null
        }
    " 2>/dev/null
    exit 0
fi

echo "[claude-notify] $MESSAGE" >&2
