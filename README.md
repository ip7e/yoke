# Yoke

A gamepad-style HUD for tiling windows on macOS. Press `Cmd+Esc` to summon a floating controller overlay — navigate, resize, and organize windows with simple shortcuts.

Built as a fork of [AeroSpace](https://github.com/nikitabobko/AeroSpace) by Nikita Bobko. Design inspired by [Teenage Engineering](https://teenage.engineering/).

> **Status: WIP** — Experimental, expect rough edges.

## Why a Fork?

AeroSpace is a great tiling window manager — no UI, TOML config, vim-style `hjkl` shortcuts. It's built for people who already know what tiling is and want full control.

Yoke is the opposite. It's opinionated, visual, and doesn't ask you to configure anything.

### What's different

- **Floating by default.** New windows open floating. Your desktop feels like normal macOS. You tile when you want to.

- **No config file.** Managed by the app. Customization is TODO.

- **Different shortcuts.** AeroSpace uses vim-style `hjkl`. Yoke uses WASD, `Cmd+Esc` to enter yoke mode, Q/E to resize, F to float. Feels more like a game controller.

- **9 workspaces only.**

- **Visual feedback.** Minimap, focus border, modifier LEDs.

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
brew tap ip7e/yoke
brew install --cask yoke
```

Or download the latest `.app` from [Releases](https://github.com/ip7e/yoke/releases).

**Requirements:**
- macOS 13+ (Ventura)
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
