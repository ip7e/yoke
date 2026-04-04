# Yoke

A gamepad-style HUD for tiling windows on macOS. Press `Cmd+Esc` to summon a floating controller overlay — navigate, resize, and organize windows with simple shortcuts.

Built as a fork of [AeroSpace](https://github.com/nikitabobko/AeroSpace) by Nikita Bobko. Design inspired by [Teenage Engineering](https://teenage.engineering/).

> **Status: WIP** — Experimental, expect rough edges.

## Why a Fork?

AeroSpace is a powerful, keyboard-driven tiling window manager with no UI — it's designed for power users who configure everything via TOML files and memorize keybindings. Yoke takes the opposite approach.

This fork is a **strongly opinionated** reimagining of how window management should work:

**AeroSpace philosophy:** No UI. Config files. Terminal commands. Full flexibility.

**Yoke philosophy:** Visual first. Zero config. Learn by seeing. Opinionated defaults.

### What Yoke overrides

- **All new windows open floating.** AeroSpace normally tiles everything immediately. Yoke lets windows float freely until you decide to tile them with `F`. Your desktop feels like normal macOS until you choose otherwise.

- **No config file needed.** AeroSpace relies on `aerospace.toml` for everything. Yoke embeds all settings inline — gaps, layouts, key mappings. Install and go.

- **Fixed workspace model (1-9).** AeroSpace supports arbitrary named workspaces. Yoke locks it to 9 numbered workspaces — simple, predictable, fits on the status bar.

- **Visual feedback for everything.** AeroSpace is silent — you press a key and things happen. Yoke shows you a live minimap, highlights the focused window with a border, lights up LEDs for modifier states, and animates button presses on the controller.

- **Guided onboarding.** AeroSpace expects you to read docs. Yoke walks you through the basics with a step-by-step interactive tutorial on first launch.

- **Single shortcut entry point.** AeroSpace binds dozens of global shortcuts across modes. Yoke uses one: `Cmd+Esc`. Everything else happens inside yoke mode — your global shortcut space stays clean.

- **Menu bar stripped down.** No version info, no sponsor links, no config editor. Just workspaces, restart onboarding, and quit.

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
