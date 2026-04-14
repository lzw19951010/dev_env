#!/usr/bin/env bash
#
# diagnose.sh — Claude Code environment diagnostic report
#
# Prints a health report for ~/.claude/: versions, plugins, settings,
# skills (including broken symlinks), disk usage. Safe & read-only.
#
# Usage: ./scripts/diagnose.sh [--json]

set -uo pipefail

CLAUDE_DIR="$HOME/.claude"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

section() { echo; echo -e "${BOLD}=== $1 ===${NC}"; }
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
bad()  { echo -e "  ${RED}✗${NC} $1"; }
kv()   { printf "  %-22s %s\n" "$1" "$2"; }

# ----- System -----
section "System"
kv "macOS" "$(sw_vers -productVersion 2>/dev/null || echo n/a)"
kv "Shell" "$SHELL"
kv "Node" "$(node --version 2>/dev/null || echo 'not installed')"
kv "npm"  "$(npm --version 2>/dev/null || echo 'not installed')"
if command -v claude &>/dev/null; then
    kv "claude" "$(claude --version 2>/dev/null | head -1)"
else
    bad "claude CLI not found"
fi
if command -v omc &>/dev/null; then
    kv "omc"  "$(omc --version 2>/dev/null | head -1)"
else
    warn "omc CLI not found (optional)"
fi
if [ -d "$CLAUDE_DIR" ]; then
    kv "~/.claude size" "$(du -sh "$CLAUDE_DIR" 2>/dev/null | awk '{print $1}')"
else
    bad "~/.claude not found"
    exit 1
fi

# ----- Plugins -----
section "Plugins"
if command -v claude &>/dev/null; then
    claude plugins list 2>/dev/null | sed 's/^/  /' || warn "could not list plugins"
else
    warn "skipping (claude not installed)"
fi

# ----- Settings -----
section "Settings"
for f in settings.json settings.local.json .mcp.json .omc-config.json; do
    if [ -f "$CLAUDE_DIR/$f" ]; then
        ok "$f ($(wc -c < "$CLAUDE_DIR/$f" | tr -d ' ') bytes)"
    else
        warn "$f not present"
    fi
done

# Key settings sanity
if [ -f "$CLAUDE_DIR/settings.json" ] && command -v python3 &>/dev/null; then
    python3 - <<'PYEOF'
import json, os
p = os.path.expanduser("~/.claude/settings.json")
d = json.load(open(p))
print(f"  editorMode            {d.get('editorMode', '(unset)')}")
print(f"  effortLevel           {d.get('effortLevel', '(unset)')}")
print(f"  NO_FLICKER            {d.get('env',{}).get('CLAUDE_CODE_NO_FLICKER','(unset)')}")
PYEOF
fi

# ----- Profiles -----
section "Profiles"
if [ -d "$CLAUDE_DIR/profiles" ]; then
    for p in "$CLAUDE_DIR"/profiles/*.json; do
        [ -f "$p" ] && ok "$(basename "$p" .json)"
    done
else
    warn "no profiles/ directory"
fi

# ----- Agents -----
section "Agents"
if [ -d "$CLAUDE_DIR/agents" ]; then
    n=$(find "$CLAUDE_DIR/agents" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
    kv "count" "$n"
else
    warn "no agents/ directory"
fi

# ----- Skills -----
section "Skills"
if [ -d "$CLAUDE_DIR/skills" ]; then
    total=$(find "$CLAUDE_DIR/skills" -maxdepth 1 -mindepth 1 | wc -l | tr -d ' ')
    broken=$(find "$CLAUDE_DIR/skills" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')
    kv "total entries" "$total"
    if [ "$broken" -gt 0 ]; then
        bad "broken symlinks: $broken"
        echo "    (to clean: find ~/.claude/skills/ -maxdepth 1 -type l ! -exec test -e {} \\; -delete)"
    else
        ok "no broken symlinks"
    fi
else
    warn "no skills/ directory"
fi

# ----- Hooks -----
section "Hooks"
if [ -f "$CLAUDE_DIR/settings.json" ] && command -v python3 &>/dev/null; then
    python3 - <<'PYEOF'
import json, os
d = json.load(open(os.path.expanduser("~/.claude/settings.json")))
hooks = d.get("hooks", {})
if not hooks:
    print("  (none configured)")
else:
    for event, rules in hooks.items():
        n = len(rules) if isinstance(rules, list) else 1
        print(f"  {event:20s} {n} rule(s)")
PYEOF
fi

# ----- Commands -----
section "Commands"
if [ -d "$CLAUDE_DIR/commands" ]; then
    for f in "$CLAUDE_DIR"/commands/*.md; do
        [ -f "$f" ] && ok "$(basename "$f" .md)"
    done
else
    warn "no commands/ directory"
fi

# ----- Disk usage Top 10 -----
section "Disk usage (top 10 subdirs of ~/.claude)"
du -sh "$CLAUDE_DIR"/*/ 2>/dev/null | sort -rh | head -10 | sed 's/^/  /'

# ----- Stale backups -----
section "Stale backups"
count=$(find "$CLAUDE_DIR" -maxdepth 1 -name 'CLAUDE.md.backup.*' | wc -l | tr -d ' ')
if [ "$count" -gt 0 ]; then
    warn "$count CLAUDE.md.backup.* files (safe to remove — history is in git)"
else
    ok "no stale CLAUDE.md backups"
fi

echo
echo -e "${BOLD}Report generated at $(date '+%Y-%m-%d %H:%M:%S')${NC}"
