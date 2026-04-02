# Claude Code + tmux + zsh Full-Stack Vi Workflow Optimization

> Date: 2026-04-01
> Platform: macOS (Darwin 24.6.0) | Terminal: Ghostty | Shell: zsh + oh-my-zsh
> Goal: Comprehensive optimization of tmux + zsh + Claude Code with full vi-mode integration

## Context

Current setup has basic tmux + zsh + Claude Code working, but with these gaps:
- Claude Code notifications don't pass through tmux (Ghostty never receives them)
- No convenient way to manage multiple Claude Code sessions in tmux
- zsh not in vi mode (user is a heavy vi-mode user across all layers)
- Claude Code vim mode not persisted (requires `/vim` each session)
- Clipboard not fully unified (mouse drag select doesn't go to system clipboard)
- Claude Code output flickers during fast rendering in tmux

## Changes

### 1. ~/.tmux.conf

#### 1.1 Claude Code Integration (new lines)

```tmux
# Allow Claude Code notifications to pass through tmux to Ghostty
set -g allow-passthrough on

# Allow Claude Code to set terminal title
set -g set-titles on
set -g set-titles-string '#S:#I #W — #{pane_current_path}'
```

**Why:** `allow-passthrough` is OFF by default. Without it, tmux blocks OSC escape sequences that Claude Code uses for desktop notifications. Ghostty natively supports these notifications with no extra config.

#### 1.2 Claude Code Launcher Keybindings (new lines)

```tmux
# Launch Claude Code in new window
bind C new-window -c "#{pane_current_path}" "claude"

# Launch Claude Code in vertical split
bind S split-window -h -c "#{pane_current_path}" "claude"

# Launch Claude Code in popup (for quick questions)
bind P display-popup -w 80% -h 80% -d "#{pane_current_path}" "claude"
```

**Why:** Frequent Claude Code users need fast ways to spin up instances. `prefix + C` (uppercase) doesn't conflict with `prefix + c` (new window with shell). Popup is ideal for quick one-off questions without disrupting layout.

#### 1.3 Clipboard Unification (new line)

```tmux
# Mouse drag select -> system clipboard (macOS)
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"
```

**Why:** Existing config has vi copy-mode `y` -> `pbcopy` and tmux-yank plugin, but mouse drag select doesn't automatically go to system clipboard. This binding completes the chain: vi `y`, mouse drag, and tmux-yank all write to macOS clipboard. `Cmd+V` paste is handled by Ghostty natively.

#### 1.4 No Changes to Existing Config

These items were considered but are already correct:
- `escape-time 0` (already set, good for vi mode)
- `mode-keys vi` (already set)
- `mouse on` (already set)
- vi copy-mode `v`/`y` bindings (already set)
- `@yank_selection 'clipboard'` (already set)
- Escape to exit copy-mode (already default in vi copy-mode)

### 2. ~/.zshrc

#### 2.1 Vi Mode (new section, after oh-my-zsh source)

```zsh
# --- Vi Mode ---
bindkey -v
export KEYTIMEOUT=1

# Cursor shape: block for normal, beam for insert
function zle-keymap-select() {
    case $KEYMAP in
        vicmd) echo -ne '\e[2 q' ;;      # block
        viins|main) echo -ne '\e[6 q' ;; # beam
    esac
}
function zle-line-init() { echo -ne '\e[6 q' }  # start in insert mode with beam
zle -N zle-keymap-select
zle -N zle-line-init

# Vi mode indicator in prompt
function _vi_mode_indicator() {
    case $KEYMAP in
        vicmd) echo -n '%F{red}[N]%f ' ;;
        *) echo -n '%F{green}[I]%f ' ;;
    esac
}
# Prepend vi mode to existing robbyrussell prompt
PROMPT='$(_vi_mode_indicator)'"$PROMPT"
```

**Why:** User is a full-stack vi user. `KEYTIMEOUT=1` reduces the 400ms default delay when pressing Escape to switch modes. Cursor shape change provides visual feedback without looking at the prompt. Mode indicator `[N]`/`[I]` prepended to existing robbyrussell theme.

#### 2.2 Claude Code Shortcuts (new section)

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

**Why:** Reduces keystrokes for the most common Claude Code operations. `ccl` shows which tmux panes have Claude Code running, useful when managing multiple instances.

### 3. ~/.claude/settings.json

#### 3.1 Environment Variable (add to existing `env` object)

```json
"CLAUDE_CODE_NO_FLICKER": "1"
```

**Why:** Enables fullscreen rendering mode. This is the only effective measure for reducing output flicker in tmux. tmux-side settings (redraw-time, monitor-activity, status-interval) do NOT help with Claude Code's internal rendering.

#### 3.2 Editor Mode (add to top level)

```json
"editorMode": "vim"
```

**Why:** Persists vim keybindings in Claude Code's input. Without this, user needs to run `/vim` every session.

### 4. Delete ~/.claude/keybindings.json

Remove the file created earlier in this session. All keybindings it contained are Claude Code's built-in defaults:

- `Ctrl+J` — newline (most reliable in tmux)
- `Ctrl+G` — external editor (opens $EDITOR/nvim)
- `Ctrl+R` — history search
- `Alt+P` — model picker
- `Alt+T` — thinking toggle
- `Alt+O` — fast mode
- `Escape` x2 — rewind

No custom keybindings needed.

### 5. Notifications

No action required. The chain is:
1. Claude Code sends OSC notification
2. `allow-passthrough on` lets it through tmux
3. Ghostty receives it and shows macOS notification

## Not Included

- **tmux pane resize keybindings (H/J/K/L)** — User declined; `prefix + z` zoom toggle is sufficient
- **Claude Code input/output split resize** — Not supported by Claude Code; mitigated by `NO_FLICKER`, `Ctrl+G` (edit in nvim), `Ctrl+L` (clear screen)
- **tmux anti-flicker settings** — `redraw-time` is not a valid tmux option; `monitor-activity off` is already default; `status-interval` change doesn't affect Claude Code rendering
- **keybindings.json customization** — All desired keybindings are already Claude Code defaults

## Files Modified

| File | Action |
|------|--------|
| `~/.tmux.conf` | Edit (add 3 sections) |
| `~/.zshrc` | Edit (add 2 sections) |
| `~/.claude/settings.json` | Edit (add 2 fields) |
| `~/.claude/keybindings.json` | Delete |
