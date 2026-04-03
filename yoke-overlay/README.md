# Yoke — visual overlay for AeroSpace

A floating gamepad-style HUD that appears when you enter **yoke mode** in AeroSpace. It shows available shortcuts at a glance and auto-dismisses when you leave the mode.

## How it works

1. Press `Cmd+Esc` to enter yoke mode — the overlay appears at the bottom center of the screen
2. Use keyboard shortcuts to control windows — aerospace handles all keybindings
3. Press `Esc` or `Enter` to exit — the overlay auto-quits

Yoke is a passive, non-activating NSPanel. It never steals focus from your windows. AeroSpace remains in full control of keybindings.

## Yoke mode keybindings

### Focus (WASD) — stays in yoke mode
| Key | Action |
|-----|--------|
| W | focus up |
| A | focus left |
| S | focus down |
| D | focus right |

### Move (Alt+WASD) — stays in yoke mode
| Key | Action |
|-----|--------|
| Alt+W | move up |
| Alt+A | move left |
| Alt+S | move down |
| Alt+D | move right |

### Resize (Q/E) — stays in yoke mode
| Key | Action |
|-----|--------|
| Q | shrink (-150) |
| E | grow (+150) |
| Shift+Q | fine shrink (-50) |
| Shift+E | fine grow (+50) |

### Layout — exits yoke mode
| Key | Action |
|-----|--------|
| T | tiles |
| Y | accordion |
| F | toggle floating |

### Merge (Shift+WASD) — exits yoke mode
| Key | Action |
|-----|--------|
| Shift+W | join-with up |
| Shift+A | join-with left |
| Shift+S | join-with down |
| Shift+D | join-with right |

## Setup

### 1. Aerospace config

Add to `~/.config/aerospace/aerospace.toml`:

```toml
# In [mode.main.binding]
cmd-esc = ['mode yoke', 'exec-and-forget /path/to/yoke-overlay/yoke']

# New mode
[mode.yoke.binding]
esc = 'mode main'
enter = 'mode main'

w = 'focus up'
a = 'focus left'
s = 'focus down'
d = 'focus right'

alt-w = 'move up'
alt-a = 'move left'
alt-s = 'move down'
alt-d = 'move right'

q = 'resize smart -150'
e = 'resize smart +150'
shift-q = 'resize smart -50'
shift-e = 'resize smart +50'

t = ['layout tiles horizontal vertical', 'mode main']
y = ['layout accordion horizontal vertical', 'mode main']
f = ['layout floating tiling', 'mode main']

shift-w = ['join-with up', 'mode main']
shift-a = ['join-with left', 'mode main']
shift-s = ['join-with down', 'mode main']
shift-d = ['join-with right', 'mode main']
```

### 2. Build

```bash
swiftc yoke-overlay/main.swift -o yoke-overlay/yoke -framework AppKit -framework SwiftUI
```

### 3. Reload

```bash
aerospace reload-config
```

## Design

- Light theme with 3D button styling (top-lit gradients, bottom shadow edges)
- Horizontal layout: d-pad on left, action buttons on right
- Compact — sits at the bottom of the screen, out of the way
- Kills previous instances on launch to prevent duplicates
- Polls `aerospace list-modes --current` every 300ms to detect mode exit

## Architecture

```
Cmd+Esc
  → aerospace enters yoke mode
  → aerospace launches yoke binary via exec-and-forget
  → yoke appears as floating overlay
  → user presses keys (handled by aerospace, not yoke)
  → on Esc/Enter, aerospace exits yoke mode
  → yoke detects mode change via polling, auto-terminates
```
