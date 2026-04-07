#!/bin/bash
# 将本项目的 skills 安装到用户级 OMC skill 目录
# 使用 symlink，项目更新后自动生效
#
# 用法: ./skills/install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.claude/skills"

mkdir -p "$TARGET_DIR"

# 迁移旧的嵌套路径 ~/.claude/skills/omc-learned/* -> ~/.claude/skills/*
# 旧版 install.sh 用 omc-learned/ 子目录，但 Claude Code 只扫描顶层，导致 skill 不被发现
LEGACY_DIR="$HOME/.claude/skills/omc-learned"
if [ -d "$LEGACY_DIR" ]; then
    echo "migrating legacy $LEGACY_DIR -> $TARGET_DIR"
    for legacy in "$LEGACY_DIR"/*; do
        [ -e "$legacy" ] || continue
        name=$(basename "$legacy")
        if [ -e "$TARGET_DIR/$name" ] || [ -L "$TARGET_DIR/$name" ]; then
            rm -f "$legacy"
        else
            mv "$legacy" "$TARGET_DIR/$name"
        fi
    done
    rmdir "$LEGACY_DIR" 2>/dev/null || true
fi

installed=0
skipped=0

for skill_dir in "$SCRIPT_DIR"/*/; do
    [ -f "$skill_dir/SKILL.md" ] || continue
    name=$(basename "$skill_dir")
    target="$TARGET_DIR/$name"

    if [ -L "$target" ]; then
        existing=$(readlink "$target")
        if [ "$existing" = "$skill_dir" ] || [ "$existing" = "${skill_dir%/}" ]; then
            echo "  skip: $name (already linked)"
            ((skipped++))
            continue
        fi
        echo "  update: $name (relink)"
        rm "$target"
    elif [ -d "$target" ]; then
        echo "  backup: $name -> ${target}.bak"
        mv "$target" "${target}.bak"
    fi

    ln -s "${skill_dir%/}" "$target"
    echo "  link: $name -> $target"
    ((installed++))
done

echo ""
echo "Done: $installed installed, $skipped skipped"
echo "Skills are available via /switch-account (or trigger keywords) in Claude Code"
