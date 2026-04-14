#!/usr/bin/env bash
#
# setup.sh — dev_env 统一安装入口
#
# 1. 检测平台（macos / debian / wsl / windows）
# 2. 应用共享的 Claude Code 配置（claude/ 目录）
# 3. 分发给平台特定的 platforms/<PLATFORM>/setup.sh
#
# 幂等：可重复运行。使用 marker 块替换旧补丁而非重复追加。
#
# 用法：
#   bash scripts/setup.sh            # 自动检测平台
#   bash scripts/setup.sh macos      # 强制使用某平台（调试用）

set -euo pipefail

# ========== 颜色 & 日志 ==========
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; }
section() { echo; echo -e "${BOLD}=== $1 ===${NC}"; }

# ========== 路径 ==========
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SHARED="$REPO_ROOT/claude"
PLATFORMS_DIR="$REPO_ROOT/platforms"
CLAUDE_DIR="$HOME/.claude"

# ========== 平台检测 ==========
detect_platform() {
    if [ $# -ge 1 ] && [ -n "$1" ]; then
        echo "$1"
        return
    fi
    case "$(uname -s)" in
        Darwin)
            echo "macos" ;;
        Linux)
            if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "debian"
            fi ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows" ;;
        *)
            echo "unknown" ;;
    esac
}

# ========== 共享：CLAUDE.md 注入个人规则块 ==========
patch_claude_md() {
    section "Claude: inject personal-rules block"

    local src="$CLAUDE_SHARED/personal-rules.md"
    local dst="$CLAUDE_DIR/CLAUDE.md"

    if [ ! -f "$src" ]; then
        warn "personal-rules.md not found, skipping"
        return
    fi

    mkdir -p "$CLAUDE_DIR"
    touch "$dst"

    # 删除旧块（如存在）
    if grep -qF 'PERSONAL-RULES:START' "$dst"; then
        # BSD sed (macOS) 和 GNU sed (Linux) 都支持 -i '' on BSD / -i on GNU
        # 用 portable 形式：备份到 tmp 再 mv 回来
        local tmp
        tmp=$(mktemp)
        awk '
            /PERSONAL-RULES:START/ { inside=1; next }
            /PERSONAL-RULES:END/   { inside=0; next }
            !inside { print }
        ' "$dst" > "$tmp"
        mv "$tmp" "$dst"
    fi

    # 追加新块
    {
        echo ""
        cat "$src"
    } >> "$dst"

    info "injected personal-rules block into $dst"
}

# ========== 共享：settings.json 合并基线 ==========
patch_claude_settings() {
    section "Claude: merge settings.base.json → ~/.claude/settings.json"

    local base="$CLAUDE_SHARED/settings.base.json"
    if [ ! -f "$base" ]; then
        warn "settings.base.json not found, skipping"
        return
    fi

    mkdir -p "$CLAUDE_DIR"

    python3 - "$base" "$CLAUDE_DIR/settings.json" <<'PYEOF'
import json, sys, os
base_path, dst_path = sys.argv[1], sys.argv[2]

with open(base_path) as f:
    base = json.load(f)

if os.path.exists(dst_path):
    with open(dst_path) as f:
        cur = json.load(f)
else:
    cur = {}

def merge(a, b):
    """浅合并：a 中已存在的值不覆盖；dict 嵌套递归；list 仅在 a 中缺失时注入。"""
    for k, v in b.items():
        if k not in a:
            a[k] = v
        elif isinstance(a[k], dict) and isinstance(v, dict):
            merge(a[k], v)
    return a

merge(cur, base)

with open(dst_path, "w") as f:
    json.dump(cur, f, indent=2)
    f.write("\n")
print(f"  [OK] merged keys: {sorted(base.keys())}")
PYEOF
}

# ========== 共享：prefs / commands / skills symlink ==========
install_prefs_commands_skills() {
    section "Claude: link prefs / commands / skills"

    # prefs
    mkdir -p "$CLAUDE_DIR/prefs"
    for f in "$CLAUDE_SHARED"/prefs/*.md; do
        [ -f "$f" ] || continue
        local name; name=$(basename "$f")
        cp "$f" "$CLAUDE_DIR/prefs/$name"
        info "prefs/$name copied"
    done

    # commands
    mkdir -p "$CLAUDE_DIR/commands"
    for f in "$CLAUDE_SHARED"/commands/*.md; do
        [ -f "$f" ] || continue
        local name; name=$(basename "$f")
        cp "$f" "$CLAUDE_DIR/commands/$name"
        info "commands/$name copied"
    done

    # skills — 用项目自带的 install.sh（symlink 方式）
    local skills_installer="$CLAUDE_SHARED/skills/install.sh"
    if [ -x "$skills_installer" ]; then
        (cd "$CLAUDE_SHARED/skills" && bash install.sh) | sed 's/^/  /'
    fi
}

# ========== 共享：插件安装（读 plugins.lock.json） ==========
install_plugins() {
    section "Claude: install plugins from plugins.lock.json"

    local lock="$REPO_ROOT/plugins.lock.json"
    if [ ! -f "$lock" ]; then
        warn "plugins.lock.json not found, skipping"
        return
    fi
    if ! command -v claude &>/dev/null; then
        warn "claude CLI not found, skipping plugin install"
        return
    fi
    if ! command -v python3 &>/dev/null; then
        warn "python3 not found, cannot parse plugins.lock.json"
        return
    fi

    # marketplaces
    while IFS=$'\t' read -r name url; do
        [ -z "$name" ] && continue
        if claude plugins marketplace add "$name" --source git --url "$url" 2>/dev/null; then
            info "marketplace: $name registered"
        elif claude plugins marketplace list 2>/dev/null | grep -qF "$name"; then
            info "marketplace: $name already present"
        else
            warn "marketplace: $name (manual check needed)"
        fi
    done < <(python3 -c "
import json
with open('$lock') as f: d = json.load(f)
for n,u in d.get('marketplaces',{}).items(): print(f'{n}\t{u}')")

    # plugins
    while IFS= read -r pid; do
        [ -z "$pid" ] && continue
        if claude plugins install "$pid" 2>/dev/null; then
            info "plugin: $pid installed"
        elif claude plugins list 2>/dev/null | grep -qF "${pid%@*}"; then
            info "plugin: $pid already installed"
        else
            warn "plugin: $pid (manual install)"
        fi
    done < <(python3 -c "
import json
with open('$lock') as f: d = json.load(f)
for p in d.get('plugins',{}): print(p)")
}

# ========== 平台分发 ==========
dispatch_platform() {
    local platform=$1
    section "Platform: $platform"

    local script="$PLATFORMS_DIR/$platform/setup.sh"
    if [ ! -f "$script" ]; then
        if [ "$platform" = "windows" ]; then
            warn "Windows platform not yet supported — see $PLATFORMS_DIR/windows/README.md"
            return
        fi
        fail "platform script not found: $script"
        return 1
    fi

    # 向下传递环境
    REPO_ROOT="$REPO_ROOT" CLAUDE_DIR="$CLAUDE_DIR" bash "$script"
}

# ========== MAIN ==========
main() {
    local platform
    platform=$(detect_platform "${1:-}")

    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  dev_env setup                                       ║"
    echo "║  platform: $platform"
    echo "╚══════════════════════════════════════════════════════╝"

    if [ "$platform" = "unknown" ]; then
        fail "could not detect platform; pass one explicitly: bash scripts/setup.sh <macos|debian|wsl|windows>"
        exit 1
    fi

    # 共享步骤（所有平台都做）
    patch_claude_md
    patch_claude_settings
    install_prefs_commands_skills
    install_plugins

    # 平台步骤
    dispatch_platform "$platform"

    echo
    info "setup.sh done"
}

main "$@"
