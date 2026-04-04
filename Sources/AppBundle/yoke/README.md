# Yoke — Technical Overview

## Architecture

Yoke is a visual layer on top of AeroSpace's window management engine. It has two distinct systems:

**AeroSpace (config-managed):** Handles mode switching and a few core bindings.
- `cmd-esc` → enter yoke mode
- `esc` / `enter` → exit yoke mode
- Config: gaps, normalization, floating defaults (hardcoded inline, no TOML file needed)

**YokeKeys (self-managed):** Owns all gameplay bindings independently.
- 38 HotKey objects in its own dictionary
- Activated/deactivated on mode enter/exit
- Commands run through `yokeRunCommand()` → `runLightSession`
- Not affected by AeroSpace config reload

### Flow

```
App launches → initYoke()
  → YokeKeys.setup() — registers 38 hotkeys (paused)
  → installYokeBlockTap() — CGEventTap for blocking unregistered keys
  → if first launch: show onboarding

Cmd+Esc pressed
  → AeroSpace switches to yoke mode
  → afterAction: YokePanel.show() + YokeKeys.activate()
    → enables block tap, shows border, starts UI timer

User presses WASD/Q/E/F/R/1-9/H
  → YokeKeys HotKey fires (independent of aerospace config)
  → yokeRunCommand("focus right") → runLightSession → command executes
  → keyUpHandler releases the button animation

User presses unregistered key
  → block tap swallows it → error flash on screen

Esc/Enter pressed
  → AeroSpace switches to main mode
  → afterAction: YokeKeys.deactivate() + YokePanel.hide()

Window changes (app activated, space changed, etc.)
  → AeroSpace GlobalObserver → refreshSession
  → yokeRefreshUI() updates minimap + border
```

## Files

```
Sources/AppBundle/yoke/
├── Skin.swift           YokeSkin protocol + BorderConfig
├── KeyState.swift       pressed keys, modifiers, help page state
├── WorkspaceMap.swift   live window positions via CGWindowList
├── YokeKeys.swift       independent HotKey manager (38 bindings)
├── YokePanel.swift      NSPanel wrapper: show/hide, passive mode
├── YokeHUD.swift        init, config bindings (3 only), block tap, border
├── OnboardingState.swift  onboarding flow, typewriter, boot sequence
├── TESkin.swift         TE OP-1 skin (active)
└── NESSkin.swift        NES controller skin (inactive)
```

## Integration with AeroSpace

Minimal — only these touch points:

- `initYoke()` — called from YokeApp init
- `yokeOnConfigReloaded()` — re-injects 3 config bindings after reload
- `yokeAfterBinding(_:)` — runs afterActions for the 3 config bindings
- `yokeRefreshUI()` — called from `runRefreshSessionBlocking` when panel visible
- `yokeRunCommand()` — wraps `parseCommand` + `runLightSession` for safe execution
- `focus` / `Workspace` / `MacWindow` — read-only access for minimap and border

## Onboarding

Steps: boot sequence → cmd-esc toggle → open 3 windows → WASD → resize → float → modifiers → help (H press graduates)

State persisted to `~/.config/yoke/onboarding.json`. Shift+P skips. "Restart Onboarding" available in menu bar.

## Thread Safety

- `yokeStateQueue` (serial dispatch queue) guards `yokePanelVisible` and `yokeRegisteredKeys`
- CGEventTap callback reads via `yokeIsPanelVisible()` / `yokeCheckRegisteredKey()`
- Main thread writes via `yokeSetPanelVisible()` / `yokeSetRegisteredKeys()`
- NSEvent modifier monitors dispatch to main via `Task { @MainActor in ... }`

## TODO

- [ ] Persist layout across restarts (save/restore window frames, workspaces, floating state — raw AX frames, no aerospace commands)
- [ ] Dark mode skin / auto-detect system appearance
- [ ] Configurable keybindings
- [ ] Window title labels in minimap
- [ ] Multi-monitor support for focus border
- [ ] Exit animation
