#!/bin/bash
# Claude Code 账号切换工具 (Linux)
# 凭证存储在 ~/.claude/.credentials.json
# 切换时自动更新 HUD 的 organizationTag，让状态栏显示当前账号

set -euo pipefail

CRED_FILE="$HOME/.claude/.credentials.json"
SETTINGS_FILE="$HOME/.claude/settings.json"
PROFILE_DIR="$HOME/.claude/profiles"

mkdir -p "$PROFILE_DIR"
chmod 700 "$PROFILE_DIR"

usage() {
    echo "用法:"
    echo "  $(basename "$0") save <名称>     保存当前登录的凭证为一个 profile"
    echo "  $(basename "$0") use <名称>      切换到指定 profile"
    echo "  $(basename "$0") list            列出所有已保存的 profile"
    echo "  $(basename "$0") delete <名称>   删除指定 profile"
    echo "  $(basename "$0") current         显示当前使用的 profile"
    echo ""
    echo "示例:"
    echo "  # 先登录账号 A (Work)，然后保存"
    echo "  $(basename "$0") save Work"
    echo ""
    echo "  # 登出，登录账号 B (Personal)，再保存"
    echo "  $(basename "$0") save Personal"
    echo ""
    echo "  # 之后随时切换（HUD 会自动更新显示当前账号）"
    echo "  $(basename "$0") use Work"
    echo "  $(basename "$0") use Personal"
}

get_account_info() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "unknown"
        return
    fi
    python3 -c "
import json, sys
with open('$file') as f:
    d = json.load(f)
oauth = d.get('claudeAiOauth', {})
sub = oauth.get('subscriptionType', 'unknown')
tier = oauth.get('rateLimitTier', 'unknown')
print(f'{sub}/{tier}')
" 2>/dev/null || echo "unknown"
}

# 更新 settings.json 中的 omcHud.organizationTag
update_hud_org_tag() {
    local name="$1"
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo "警告: settings.json 不存在，跳过 HUD 更新"
        return
    fi
    python3 -c "
import json, sys

name = sys.argv[1]
with open('$SETTINGS_FILE') as f:
    settings = json.load(f)

if 'omcHud' not in settings:
    settings['omcHud'] = {}
settings['omcHud']['organizationTag'] = name

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')
" "$name" 2>/dev/null && echo "HUD 已更新: [$name]" || echo "警告: HUD 更新失败"
}

# 清除 usage-api 缓存（切换账号后旧缓存无效）
clear_usage_cache() {
    local cache_file="$HOME/.claude/plugins/oh-my-claudecode/.usage-cache.json"
    if [ -f "$cache_file" ]; then
        rm -f "$cache_file"
    fi
}

save_profile() {
    local name="$1"
    local file="$PROFILE_DIR/$name.json"

    if [ ! -f "$CRED_FILE" ]; then
        echo "错误: 没有找到凭证文件 ($CRED_FILE)，请先登录 Claude Code"
        exit 1
    fi

    cp "$CRED_FILE" "$file"
    chmod 600 "$file"

    # 记录当前 profile
    echo "$name" > "$PROFILE_DIR/.current"

    local info
    info=$(get_account_info "$file")
    echo "已保存 profile: $name ($info)"

    # 同步 HUD 显示
    update_hud_org_tag "$name"
}

use_profile() {
    local name="$1"
    local file="$PROFILE_DIR/$name.json"

    if [ ! -f "$file" ]; then
        echo "错误: profile '$name' 不存在"
        echo "可用的 profile:"
        list_profiles
        exit 1
    fi

    cp "$file" "$CRED_FILE"
    chmod 600 "$CRED_FILE"

    # 记录当前 profile
    echo "$name" > "$PROFILE_DIR/.current"

    # 清除旧的 usage 缓存
    clear_usage_cache

    # 同步 HUD 显示
    update_hud_org_tag "$name"

    local info
    info=$(get_account_info "$file")
    echo "已切换到: $name ($info)"
    echo "提示: 需要重启 Claude Code 会话才能使用新凭证"
}

list_profiles() {
    local current=""
    if [ -f "$PROFILE_DIR/.current" ]; then
        current=$(cat "$PROFILE_DIR/.current")
    fi

    local found=0
    for f in "$PROFILE_DIR"/*.json; do
        [ -f "$f" ] || continue
        local name
        name=$(basename "$f" .json)
        local info
        info=$(get_account_info "$f")
        if [ "$name" = "$current" ]; then
            echo "  * $name ($info)  <- 当前"
        else
            echo "    $name ($info)"
        fi
        found=1
    done

    if [ "$found" -eq 0 ]; then
        echo "  (没有已保存的 profile)"
    fi
}

delete_profile() {
    local name="$1"
    local file="$PROFILE_DIR/$name.json"

    if [ ! -f "$file" ]; then
        echo "错误: profile '$name' 不存在"
        exit 1
    fi

    rm "$file"
    echo "已删除 profile: $name"

    # 如果删除的是当前 profile，清除 current 标记
    if [ -f "$PROFILE_DIR/.current" ]; then
        local current
        current=$(cat "$PROFILE_DIR/.current")
        if [ "$current" = "$name" ]; then
            rm "$PROFILE_DIR/.current"
        fi
    fi
}

show_current() {
    if [ -f "$PROFILE_DIR/.current" ]; then
        local name
        name=$(cat "$PROFILE_DIR/.current")
        local file="$PROFILE_DIR/$name.json"
        if [ -f "$file" ]; then
            local info
            info=$(get_account_info "$file")
            echo "当前 profile: $name ($info)"
            return
        fi
    fi
    echo "当前没有记录使用哪个 profile"
}

# 主逻辑
if [ $# -lt 1 ]; then
    usage
    exit 1
fi

case "$1" in
    save)
        [ $# -lt 2 ] && { echo "错误: 请指定 profile 名称"; exit 1; }
        save_profile "$2"
        ;;
    use)
        [ $# -lt 2 ] && { echo "错误: 请指定 profile 名称"; exit 1; }
        use_profile "$2"
        ;;
    list)
        list_profiles
        ;;
    delete)
        [ $# -lt 2 ] && { echo "错误: 请指定 profile 名称"; exit 1; }
        delete_profile "$2"
        ;;
    current)
        show_current
        ;;
    *)
        usage
        exit 1
        ;;
esac
