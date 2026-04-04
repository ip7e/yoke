# Yoke

A gamepad-style HUD for tiling windows on macOS. Press `Cmd+Esc` to summon a floating controller overlay — navigate, resize, and organize windows with simple shortcuts.

Built as a fork of [AeroSpace](https://github.com/nikitabobko/AeroSpace) by Nikita Bobko. Design inspired by [Teenage Engineering](https://teenage.engineering/).

> **Status: WIP** — Experimental, expect rough edges.

## What It Does

- Tiling window manager with a visual gamepad overlay
- WASD to move focus between windows
- Q/E to resize, F to float/tile, 1-9 for workspaces
- Focus border around the active window
- Live minimap showing your window layout
- Guided onboarding for first-time users
- No config files needed — works out of the box

## Install

```bash
# Build from source (requires Xcode + Swift)
swift build -c release

# The binary is at .build/release/YokeApp
# Or build the .app bundle:
mkdir -p Yoke.app/Contents/MacOS
cp .build/release/YokeApp Yoke.app/Contents/MacOS/Yoke
# (see Sources/AppBundle/yoke/README.md for Info.plist)
```

**Requirements:**
- macOS 14+
- Accessibility permission (prompted on first launch)

## Shortcuts

| Key | Action |
|-----|--------|
| `Cmd+Esc` | Toggle Yoke |
| `W/A/S/D` | Focus up/left/down/right |
| `Alt+WASD` | Move window |
| `Shift+WASD` | Merge windows |
| `Q/E` | Resize (Shift for fine) |
| `F` | Toggle float/tile |
| `R` | Cycle layout (Shift for orientation) |
| `1-9` | Switch workspace |
| `Alt+1-9` | Send window to workspace |
| `H` | Help pages |
| `Esc / Enter` | Exit Yoke |

## Architecture

See [Sources/AppBundle/yoke/README.md](Sources/AppBundle/yoke/README.md) for technical details.

## Credits

- [AeroSpace](https://github.com/nikitabobko/AeroSpace) by Nikita Bobko — the tiling window manager this is built on
- [Teenage Engineering](https://teenage.engineering/) — design inspiration for the OP-1 style skin
