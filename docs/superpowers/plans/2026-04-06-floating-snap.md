# Floating Window Snap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a floating window is focused, Alt+WASD snaps it to screen halves, thirds, and quarters instead of running the tiled `move` command.

**Architecture:** A new `FloatingSnap` singleton tracks the current snap state (edge, width fraction, vertical half). YokeKeys detects floating windows in Alt+WASD handlers and delegates to FloatingSnap instead of `yokeRunCommand("move ...")`. FloatingSnap calculates the target frame from the monitor's `visibleRect` and applies it via `macWin.setAxFrame()`.

**Tech Stack:** Swift, AeroSpace's `Monitor.visibleRect` (Rect struct), `MacWindow.setAxFrame()`.

---

### File Structure

| File | Responsibility |
|------|---------------|
| Create: `Sources/AppBundle/yoke/FloatingSnap.swift` | Snap state tracking + frame calculation + apply |
| Modify: `Sources/AppBundle/yoke/YokeKeys.swift:22-26` | Alt+WASD: floating → snap, tiled → move |

---

### Task 1: Create FloatingSnap with state tracking and frame calculation

**Files:**
- Create: `Sources/AppBundle/yoke/FloatingSnap.swift`

- [ ] **Step 1: Create the FloatingSnap class with state and snap methods**

```swift
import AppKit
import Common

@MainActor
class FloatingSnap {
    static let shared = FloatingSnap()

    enum Edge { case left, right, none }
    enum Vertical { case top, bottom, full }
    enum HFraction: CGFloat {
        case half = 0.5
        case third = 0.3333
        case full = 1.0
    }

    private var edge: Edge = .none
    private var hFraction: HFraction = .half
    private var vertical: Vertical = .full
    private var trackedWindowId: UInt32?

    private init() {}

    // MARK: - Public snap actions

    func snapLeft() {
        guard let (macWin, windowId) = floatingWindow() else { return }
        resetIfWindowChanged(windowId)

        if edge == .left {
            // Cycle: 1/2 → 1/3
            if hFraction == .half { hFraction = .third }
        } else {
            edge = .left
            hFraction = .half
        }
        vertical = .full
        trackedWindowId = windowId
        applyFrame(macWin)
    }

    func snapRight() {
        guard let (macWin, windowId) = floatingWindow() else { return }
        resetIfWindowChanged(windowId)

        if edge == .right {
            if hFraction == .half { hFraction = .third }
        } else {
            edge = .right
            hFraction = .half
        }
        vertical = .full
        trackedWindowId = windowId
        applyFrame(macWin)
    }

    func snapUp() {
        guard let (macWin, windowId) = floatingWindow() else { return }
        resetIfWindowChanged(windowId)

        if edge == .none && vertical != .top {
            // No horizontal snap yet → full-width top half
            edge = .none
            hFraction = .full
        }
        vertical = .top
        trackedWindowId = windowId
        applyFrame(macWin)
    }

    func snapDown() {
        guard let (macWin, windowId) = floatingWindow() else { return }
        resetIfWindowChanged(windowId)

        if edge == .none && vertical != .bottom {
            edge = .none
            hFraction = .full
        }
        vertical = .bottom
        trackedWindowId = windowId
        applyFrame(macWin)
    }

    func reset() {
        edge = .none
        hFraction = .half
        vertical = .full
        trackedWindowId = nil
    }

    // MARK: - Private helpers

    private func floatingWindow() -> (MacWindow, UInt32)? {
        guard let window = focus.windowOrNil, window.isFloating,
              let macWin = window as? MacWindow else { return nil }
        return (macWin, window.windowId)
    }

    private func resetIfWindowChanged(_ windowId: UInt32) {
        if trackedWindowId != windowId {
            edge = .none
            hFraction = .half
            vertical = .full
        }
    }

    private func applyFrame(_ macWin: MacWindow) {
        let screen = focus.workspace.workspaceMonitor.visibleRect

        let snapW = screen.width * hFraction.rawValue
        let snapH: CGFloat = vertical == .full ? screen.height : screen.height / 2

        let snapX: CGFloat
        switch edge {
        case .left, .none: snapX = screen.topLeftX
        case .right: snapX = screen.topLeftX + screen.width - snapW
        }

        let snapY: CGFloat
        switch vertical {
        case .top, .full: snapY = screen.topLeftY
        case .bottom: snapY = screen.topLeftY + screen.height / 2
        }

        macWin.setAxFrame(CGPoint(x: snapX, y: snapY), CGSize(width: snapW, height: snapH))
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
swift build 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/AppBundle/yoke/FloatingSnap.swift
git commit -m "feature: add FloatingSnap state machine for floating window snapping"
```

---

### Task 2: Wire Alt+WASD to FloatingSnap for floating windows

**Files:**
- Modify: `Sources/AppBundle/yoke/YokeKeys.swift:22-26`

- [ ] **Step 1: Replace the four Alt+WASD `bind()` calls with `bindCustom()` calls that branch on floating**

Replace lines 22-26 in `YokeKeys.swift`:

```swift
        // Move — Alt+WASD
        bind(.w, .option, cmd: "move up", label: "⌥W")
        bind(.a, .option, cmd: "move left", label: "⌥A")
        bind(.s, .option, cmd: "move down", label: "⌥S")
        bind(.d, .option, cmd: "move right", label: "⌥D")
```

With:

```swift
        // Move (tiled) / Snap (floating) — Alt+WASD
        bindCustom(.w, .option, label: "⌥W") {
            if let window = focus.windowOrNil, window.isFloating {
                FloatingSnap.shared.snapUp()
            } else {
                yokeRunCommand("move up")
            }
            yokeRefreshUI()
        }
        bindCustom(.a, .option, label: "⌥A") {
            if let window = focus.windowOrNil, window.isFloating {
                FloatingSnap.shared.snapLeft()
            } else {
                yokeRunCommand("move left")
            }
            yokeRefreshUI()
        }
        bindCustom(.s, .option, label: "⌥S") {
            if let window = focus.windowOrNil, window.isFloating {
                FloatingSnap.shared.snapDown()
            } else {
                yokeRunCommand("move down")
            }
            yokeRefreshUI()
        }
        bindCustom(.d, .option, label: "⌥D") {
            if let window = focus.windowOrNil, window.isFloating {
                FloatingSnap.shared.snapRight()
            } else {
                yokeRunCommand("move right")
            }
            yokeRefreshUI()
        }
```

- [ ] **Step 2: Build to verify**

```bash
swift build 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 3: Manual test**

```bash
pkill -f Yoke; sleep 0.5; swift build && .build/arm64-apple-macosx/debug/YokeApp &disown
```

Test sequence:
1. Open a window, enter yoke mode (cmd-esc), float it (F)
2. Alt+A → window snaps to left half
3. Alt+A again → window snaps to left third
4. Alt+W → window snaps to top-left quarter (1/3 width, 1/2 height)
5. Alt+S → bottom-left quarter
6. Alt+D → right half (full height, resets vertical)
7. Alt+W → top-right half
8. Un-float (F), Alt+A → normal tiled move behavior

- [ ] **Step 4: Commit**

```bash
git add Sources/AppBundle/yoke/YokeKeys.swift
git commit -m "feature: Alt+WASD snaps floating windows to screen regions"
```

---

### Task 3: Reset snap state on focus change and mode exit

**Files:**
- Modify: `Sources/AppBundle/yoke/YokeHUD.swift` (yokeRefreshUI and deactivate paths)
- Modify: `Sources/AppBundle/yoke/YokeKeys.swift` (deactivate)

- [ ] **Step 1: Reset snap state when focus changes to a different window**

In `Sources/AppBundle/yoke/YokeHUD.swift`, at the top of `yokeRefreshUI()` (around line 289), the function already runs on every action. The snap state auto-resets via `resetIfWindowChanged()` inside each snap method, so no change needed here.

Instead, reset snap state when yoke mode deactivates. In `Sources/AppBundle/yoke/YokeKeys.swift`, in the `deactivate()` method (around line 105), add a reset call:

```swift
    func deactivate() {
        guard isActive else { return }
        isActive = false
        for hk in hotkeys.values { hk.isPaused = true }
        FloatingSnap.shared.reset()
        yokeLog("YokeKeys: deactivated")
    }
```

- [ ] **Step 2: Build and verify**

```bash
swift build 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/AppBundle/yoke/YokeKeys.swift
git commit -m "fix: reset floating snap state on yoke mode exit"
```
