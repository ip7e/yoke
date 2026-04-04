# Yoke — Embedded AeroSpace HUD

A floating gamepad-style HUD embedded directly into [AeroSpace](https://github.com/nikitabobko/AeroSpace). Press `Cmd+Esc` to enter **yoke mode** — an overlay appears with your window layout and available shortcuts. Press `Esc` or `Enter` to exit.

> **Status: WIP** — This is a fork of AeroSpace with yoke baked in. The standalone version lives at https://github.com/ip7e/yoke

## How It Works

Unlike the standalone version (which ran as a separate process with its own CGEventTap), the embedded yoke:

1. **Injects bindings at runtime** — `initYoke()` programmatically adds ~49 HotKey bindings to AeroSpace's config on startup. No manual `[mode.yoke.binding]` section needed in `aerospace.toml`.
2. **Uses AeroSpace's native HotKey system** — keys are handled by the same system that handles all other AeroSpace shortcuts. No external event tap for registered keys.
3. **Blocks unregistered keys** — a lightweight `CGEventTap` (tail-append, enabled only when yoke is visible) swallows any key NOT in the binding set and flashes an error on the HUD.
4. **Survives config reloads** — `yokeOnConfigReloaded()` re-injects all bindings after AeroSpace reloads its config.
5. **Saves/restores layouts** — window positions, workspaces, and floating state are saved to `~/.config/yoke/layout.json` on yoke hide and restored on startup.

### Flow

```
AeroSpace launches
  → initYoke()
    → YokePanel.prepare() — creates NSPanel (non-activating, floating, never steals focus)
    → injectYokeBindingsIntoConfig() — adds cmd-esc + 49 yoke-mode bindings
    → installYokeBlockTap() — CGEventTap for blocking unregistered keys
    → NSEvent.flagsChanged monitor — tracks alt/shift for UI indicators
    → restoreLayout() — reads ~/.config/yoke/layout.json, restores windows

User presses Cmd+Esc
  → AeroSpace HotKey fires "mode yoke"
  → afterAction: YokePanel.show()
    → positions panel at bottom center
    → enables block tap
    → starts 0.5s poll timer (workspace map + focus border refresh)

User presses WASD/Q/E/T/Y/F/etc
  → AeroSpace HotKey fires the aerospace command (focus/move/resize/layout)
  → afterAction: KeyState.press(label), showFocusBorder(), WorkspaceMap.refreshAll()

User presses unregistered key (e.g. X)
  → block tap swallows it (returns nil)
  → KeyState.errorFlash = true (shows "ERR WRONG KEY" on screen)

User presses Esc or Enter
  → AeroSpace HotKey fires "mode main"
  → afterAction: saveLayout(), YokePanel.hide()
    → disables block tap
    → removes focus border
    → stops poll timer
```

## Files

```
Sources/AppBundle/yoke/
├── Skin.swift          Protocol: YokeSkin + BorderConfig (20 lines)
├── KeyState.swift      ObservableObject: pressed keys, alt/shift, error flash (29 lines)
├── WorkspaceMap.swift   ObservableObject: live window positions via CGWindowList (56 lines)
├── YokeLayout.swift    Save/restore window layouts to JSON (169 lines)
├── YokePanel.swift     NSPanel wrapper: show/hide, positioning, block tap management (77 lines)
├── YokeHUD.swift       Core: binding injection, event tap, config reload hook (386 lines)
├── TESkin.swift        Teenage Engineering OP-1 skin — active by default (619 lines)
└── NESSkin.swift       NES controller skin — retro alternative (417 lines)
```

### Integration points with AeroSpace core

- **`initYoke()`** — called from `initAppBundle()` during startup
- **`yokeOnConfigReloaded()`** — called from AeroSpace's config reload path to re-inject bindings
- **`yokeAfterBinding(_:)`** — called after each HotKey fires, to run UI callbacks
- **`parseCommand()`** — used to create aerospace Command objects for binding injection
- **`activateMode()`** — used to re-register HotKeys after injection
- **`focus.windowOrNil` / `focus.workspace`** — used by WorkspaceMap for window tracking
- **`Workspace.all` / `.allLeafWindowsRecursive`** — used for layout save/restore

## Key Bindings

| Key | Action |
|-----|--------|
| **Cmd+Esc** | Enter yoke mode (from main mode) |
| `W` / `A` / `S` / `D` | Focus up / left / down / right |
| `Alt+W/A/S/D` | Move window up / left / down / right |
| `Shift+W/A/S/D` | Merge (join-with) up / left / down / right |
| `Q` / `E` | Resize shrink (-150) / grow (+150) |
| `Shift+Q` / `Shift+E` | Fine resize (-50 / +50) |
| `T` | Layout: tiles |
| `Y` | Layout: accordion |
| `F` | Layout: toggle floating/tiling |
| `1`-`9` | Switch to workspace |
| `Alt+1`-`9` | Move window to workspace |
| `Shift+1`-`9` | Move window to workspace (alternate) |
| `H` | Cycle help pages |
| `Esc` / `Enter` | Exit yoke mode |

### Modifier indicators

- **Alt held** — green LED on d-pad knob, green screen tint. Indicates move mode (Alt+WASD) or workspace move (Alt+1-9).
- **Shift held** — orange LED on d-pad knob, orange screen tint, +/- buttons light up. Indicates merge mode (Shift+WASD) or fine resize (Shift+Q/E).

## Skins

Yoke uses a `YokeSkin` protocol so visual themes are swappable:

```swift
protocol YokeSkin {
    var borderConfig: BorderConfig { get }
    func makeView(keys: KeyState) -> AnyView
}
```

### TESkin (Teenage Engineering OP-1 Field)

The default. Modular grid layout inspired by the OP-1 synthesizer:
- Cream/warm gray panels with neumorphic shadows
- D-pad with rotating knob (shows alt/shift LEDs)
- Screen module with live workspace minimap, scanline effect, and tape animation
- Workspace bar showing occupied/active workspaces
- Help pages accessible via H key

### NESSkin (NES Controller)

Retro alternative styled after the Nintendo/Dendy controller:
- Cream body with dark charcoal panel
- Black cross d-pad
- Red round action buttons
- Dark rubber select/start pills

Set the active skin in `YokeHUD.swift`:
```swift
let activeSkin: any YokeSkin = TESkin() // or NESSkin()
```

## Layout Save/Restore

On every yoke hide, the current window layout is saved to `~/.config/yoke/layout.json`:

```json
{
  "timestamp": "2026-04-03T...",
  "windows": [
    {
      "windowId": 1234,
      "appBundleId": "com.apple.Safari",
      "appName": "Safari",
      "workspace": "1",
      "isFloating": false,
      "x": 0, "y": 0, "width": 960, "height": 1080
    }
  ]
}
```

On startup (after 2s delay), windows are restored:
- **Exact ID match** — same session, windows haven't changed
- **App bundle ID fallback** — across restarts, matched by app
- **Floating/tiling state** — restored via `layout floating`/`layout tiling` commands
- **Position/size** — floating windows get exact frame restored via AX API
- **New windows** — not in snapshot, stay in default state
- **Missing windows** — silently skipped

## What's Done

- [x] Embedded yoke directly into AeroSpace (no separate process)
- [x] HotKey-based key handling (uses AeroSpace's native system)
- [x] CGEventTap for blocking unregistered keys + error feedback
- [x] Config reload survival (re-injects bindings)
- [x] Two skins: TESkin (OP-1) and NESSkin (NES controller)
- [x] Live workspace minimap with scanline effect
- [x] Workspace indicators (1-9 bar)
- [x] Workspace switching (number keys) + move-to-workspace (Alt/Shift+number)
- [x] Modifier LED indicators (alt/shift)
- [x] Screen tint on modifier hold
- [x] +/- buttons light up when shift is held (fine resize indicator)
- [x] Help system (H key, 5 pages)
- [x] Error feedback (wrong key flash)
- [x] Focus border around active window
- [x] Button press animations
- [x] Entrance animation (bounce from bottom)
- [x] Layout save/restore (JSON persistence)
- [x] Stable window colors in minimap (by window ID, not array index)

## TODO / Future

- [ ] Refactor into proper Swift package structure (separate Yoke package?)
- [ ] Dark mode skin / auto-detect system appearance
- [ ] Configurable keybindings (read from config file instead of hardcoded)
- [ ] Visual scaling effect when entering yoke mode (CGS private APIs didn't work cross-process)
- [ ] Dim overlay for inactive windows (CGSSetWindowAlpha didn't work cross-process)
- [ ] Window title labels in the minimap
- [ ] Drag-to-reorder windows via the minimap
- [ ] Multi-monitor support for focus border
- [ ] Flatten/split-container shortcuts
- [ ] Animation when exiting yoke mode
- [ ] Persist layout across restarts (save/restore window frames, workspaces, floating state to JSON — no aerospace commands, just raw AX frames)
- [ ] Publish as a standalone AeroSpace plugin once plugin API exists

## Notes

- **Accessibility permissions required** — the block tap (`CGEventTap`) and focus border (`AXUIElement`) both need accessibility access.
- **Private API** — `_AXUIElementGetWindow` is used to get `CGWindowID` from an accessibility element. Could break on future macOS updates.
- **Thread safety** — `yokeRegisteredKeys` and `yokePanelVisible` are `nonisolated(unsafe)` for access from the CGEventTap callback. The registered keys set is only written at startup (before the tap fires), so this is safe in practice.
