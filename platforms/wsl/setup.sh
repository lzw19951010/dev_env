#!/usr/bin/env bash
#
# platforms/wsl/setup.sh — WSL (Ubuntu/Debian under Windows)
#
# 策略：复用 debian/setup.sh（90% 相同），只替换通知脚本为 WSL 专用（
# 通过 powershell.exe 调 Windows toast 通知）。
#
# 继承 REPO_ROOT, CLAUDE_DIR 由 scripts/setup.sh 注入。

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
DEBIAN_SETUP="$REPO_ROOT/platforms/debian/setup.sh"
WSL_DIR="$REPO_ROOT/platforms/wsl"

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# 1. 复用 Debian 全流程
if [ -f "$DEBIAN_SETUP" ]; then
    echo "=== WSL: delegating to debian/setup.sh ==="
    REPO_ROOT="$REPO_ROOT" bash "$DEBIAN_SETUP"
else
    warn "debian/setup.sh not found; WSL cannot proceed"
    exit 1
fi

# 2. 覆盖通知脚本为 WSL 版（调 powershell.exe）
echo; echo "=== WSL: override claude-notify.sh ==="
if [ -f "$WSL_DIR/claude-notify.sh" ]; then
    cp "$WSL_DIR/claude-notify.sh" "$HOME/.claude/claude-notify.sh"
    chmod +x "$HOME/.claude/claude-notify.sh"
    info "installed WSL notification bridge → ~/.claude/claude-notify.sh"
else
    warn "WSL claude-notify.sh not found at $WSL_DIR"
fi

# 3. 检查 powershell.exe 可用性
if command -v powershell.exe &>/dev/null || [ -x /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe ]; then
    info "powershell.exe accessible (Windows interop works)"
else
    warn "powershell.exe not found; WSL interop may be disabled"
fi

echo; info "WSL setup done"
