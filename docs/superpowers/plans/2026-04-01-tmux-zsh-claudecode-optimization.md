# tmux + zsh + Claude Code Full-Stack Vi Optimization

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Optimize tmux + zsh + Claude Code integration with full vi-mode, unified clipboard, notifications, and multi-session management.

**Architecture:** Edit 3 config files (~/.tmux.conf, ~/.zshrc, ~/.claude/settings.json), delete 1 file (~/.claude/keybindings.json). All changes are additive sections or single-field additions.

**Tech Stack:** tmux, zsh, Claude Code, Ghostty

---

### Current State

Some changes were already applied in this session:
- `~/.tmux.conf`: allow-passthrough, set-titles already added (lines 16-19)
- `~/.claude/settings.json`: CLAUDE_CODE_NO_FLICKER already added
- `~/.zshrc`: cc/ccc/ccr/ccw already added (lines 154-161), but **ccw has a bug** — uses `#{pane_current_path}` (tmux syntax) instead of `$(pwd)` (shell syntax)
- `~/.claude/keybindings.json`: created erroneously, needs deletion

---

### Task 1: Add tmux Claude Code launcher keybindings

**Files:**
- Modify: `~/.tmux.conf:43` (after reload config binding)

- [ ] **Step 1: Add keybindings after the reload config line**

Insert after line 43 (`bind r source-file ...`):

```tmux
# --- Claude Code Launchers ---
bind C new-window -c "#{pane_current_path}" "claude"
bind S split-window -h -c "#{pane_current_path}" "claude"
bind P display-popup -w 80% -h 80% -d "#{pane_current_path}" "claude"
```

- [ ] **Step 2: Add mouse drag clipboard binding**

Insert after line 40 (`bind -T copy-mode-vi y ...`):

```tmux
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"
```

- [ ] **Step 3: Reload tmux config**

Run: `tmux source-file ~/.tmux.conf`
Expected: No errors

- [ ] **Step 4: Verify keybindings registered**

Run: `tmux list-keys | grep -E 'bind-key.*[CSP].*claude'`
Expected: 3 lines showing the C, S, P bindings

Run: `tmux list-keys | grep MouseDragEnd`
Expected: 1 line showing copy-pipe-and-cancel pbcopy

---

### Task 2: Add editorMode to settings.json

**Files:**
- Modify: `~/.claude/settings.json`

- [ ] **Step 1: Add editorMode field**

Add `"editorMode": "vim"` to the top-level object:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_CODE_NO_FLICKER": "1"
  },
  "permissions": { ... },
  "statusLine": { ... },
  "enabledPlugins": { ... },
  "effortLevel": "high",
  "editorMode": "vim"
}
```

- [ ] **Step 2: Validate JSON**

Run: `python3 -c "import json; json.load(open('$HOME/.claude/settings.json')); print('OK')"`
Expected: `OK`

---

### Task 3: Fix ccw bug and add ccl function in .zshrc

**Files:**
- Modify: `~/.zshrc:154-161` (Claude Code section)

- [ ] **Step 1: Replace the Claude Code section**

Replace lines 154-161 with:

```zsh
# --- Claude Code ---
alias cc='claude'
alias ccc='claude --continue'
alias ccr='claude --resume'

# Launch Claude Code in new tmux window
ccw() { tmux new-window -c "$(pwd)" "claude $*" }

# List all running Claude Code instances
ccl() {
    tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_command} #{pane_current_path}' \
        | grep -i claude
}
```

Bug fix: `#{pane_current_path}` → `$(pwd)`. The former is tmux format syntax, not valid in a zsh function.

---

### Task 4: Add zsh vi mode

**Files:**
- Modify: `~/.zshrc` (insert after `source $ZSH/oh-my-zsh.sh` line 83)

- [ ] **Step 1: Add vi mode section after oh-my-zsh source**

Insert after line 83 (`source $ZSH/oh-my-zsh.sh`):

```zsh
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
```

- [ ] **Step 2: Verify vi mode works**

Run: `source ~/.zshrc` (in a test shell, not this session)
Expected: Prompt shows `[I]` prefix. Press Escape → cursor changes to block, prompt shows `[N]`. Press `i` → back to beam + `[I]`.

---

### Task 5: Delete keybindings.json

**Files:**
- Delete: `~/.claude/keybindings.json`

- [ ] **Step 1: Delete the file**

Run: `rm ~/.claude/keybindings.json`

- [ ] **Step 2: Verify deletion**

Run: `test -f ~/.claude/keybindings.json && echo "STILL EXISTS" || echo "DELETED"`
Expected: `DELETED`

---

### Task 6: Full verification

- [ ] **Step 1: Verify tmux config**

Run:
```bash
tmux show-options -g allow-passthrough
tmux show-options -g set-titles
tmux list-keys | grep -c claude
tmux list-keys | grep MouseDragEnd
```

Expected:
```
allow-passthrough on
set-titles on
3
(one line with pbcopy)
```

- [ ] **Step 2: Verify settings.json**

Run: `python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); print(d.get('editorMode'), d['env'].get('CLAUDE_CODE_NO_FLICKER'))"`
Expected: `vim 1`

- [ ] **Step 3: Verify keybindings.json deleted**

Run: `test -f ~/.claude/keybindings.json && echo "FAIL" || echo "OK"`
Expected: `OK`

- [ ] **Step 4: Verify clipboard chain**

In tmux:
1. Enter copy-mode (`prefix + [`)
2. Select text with `v`, yank with `y` → check `pbpaste` shows the text
3. Mouse drag select text → release → check `pbpaste` shows the text
