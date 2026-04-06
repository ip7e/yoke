# Floating Window Snap — Design Spec

## Goal

When a floating window is focused in Yoke mode, Alt+WASD snaps it to screen regions (halves, thirds, quarters) instead of the tiled `move` command (which doesn't work for floating windows anyway).

## Behavior

### Snap state tracking

A lightweight state tracks the current snap position: `edge` (left/right/none) and `vertical` (top/bottom/full). This state is per-session, not persisted. It resets when:
- The user switches focus to a different window
- The window is un-floated (becomes tiled)
- Yoke mode is exited

### Horizontal snapping (Alt+A / Alt+D)

Alt+A and Alt+D snap to the left or right edge of the screen. Pressing the same direction again cycles the width:

| Press | From | Result |
|-------|------|--------|
| Alt+A | unsnapped | left 1/2, full height |
| Alt+A | left 1/2 | left 1/3, full height |
| Alt+A | left 1/3 | left 1/3 (no further cycle) |
| Alt+D | unsnapped | right 1/2, full height |
| Alt+D | right 1/2 | right 1/3, full height |
| Alt+D | right 1/3 | right 1/3 (no further cycle) |

Pressing a horizontal key **always resets vertical to full height**. This means:
- top-left quarter + Alt+A → left 1/2 full height
- top-left quarter + Alt+D → right 1/2 full height

Pressing the opposite horizontal direction switches edge and resets to 1/2:
- left 1/3 + Alt+D → right 1/2

### Vertical snapping (Alt+W / Alt+S)

Alt+W and Alt+S subdivide the current position into top or bottom half.

| Press | From | Result |
|-------|------|--------|
| Alt+W | unsnapped | top 1/2, full width |
| Alt+S | unsnapped | bottom 1/2, full width |
| Alt+W | left 1/2 | top-left quarter |
| Alt+S | left 1/2 | bottom-left quarter |
| Alt+W | top-left quarter | top-left quarter (no change) |
| Alt+S | top-left quarter | bottom-left quarter |
| Alt+W | right 1/3 | top-right 1/3-width, 1/2-height |

Vertical only has two states: top half and bottom half. No 1/3 vertical.

### Frame calculation

All frames are calculated relative to the monitor's **visible rect** (excludes menu bar and dock).

```
Given: visibleRect = { x, y, w, h }
       edge = left | right | none
       hFraction = 1/2 | 1/3 | 1 (full)
       vertical = top | bottom | full

snapWidth  = w * hFraction
snapHeight = vertical == full ? h : h / 2
snapX      = edge == right ? x + w - snapWidth : x
snapY      = vertical == bottom ? y + h / 2 : y

frame = (snapX, snapY, snapWidth, snapHeight)
```

### Tiled windows — no change

When the focused window is **not** floating, Alt+WASD continues to run the existing `move` command via `yokeRunCommand`. No behavior change for tiled windows.

## Architecture

### New file: `Sources/AppBundle/yoke/FloatingSnap.swift`

A small struct/class that:
- Tracks current snap state (edge, width fraction, vertical position, window ID)
- Exposes `snapLeft()`, `snapRight()`, `snapUp()`, `snapDown()` methods
- Each method updates the state and calls `macWin.setAxFrame(topLeft, size)` using the monitor's visible rect
- Resets state when window ID changes

### Modified file: `Sources/AppBundle/yoke/YokeKeys.swift`

The four `bind(.w/.a/.s/.d, .option, ...)` calls change from:
```swift
bind(.a, .option, cmd: "move left", label: "...")
```
to:
```swift
bindCustom(.a, .option, label: "...") {
    if let window = focus.windowOrNil, window.isFloating {
        FloatingSnap.shared.snapLeft()
    } else {
        yokeRunCommand("move left")
    }
    yokeRefreshUI()
}
```

### Screen geometry

Uses `focus.workspace.workspaceMonitor.visibleRect` for the target monitor's visible area (already in AX-normalized coordinates — top-left origin, y-axis down).
