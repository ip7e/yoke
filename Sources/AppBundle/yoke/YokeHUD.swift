import AppKit
import Common
import HotKey
import SwiftUI

// MARK: - Active skin

nonisolated(unsafe) let activeSkin: any YokeSkin = TESkin()

// MARK: - Public entry point

@MainActor
public func initYoke() {
    yokeLog("initYoke: starting")
    UpdateChecker.shared.checkIfNeeded()
    OnboardingState.shared.load()
    if !OnboardingState.shared.isComplete {
        OnboardingState.shared.startOnboarding()
    }
    let content = activeSkin.makeView(keys: KeyState.shared)
    YokePanel.shared.prepare(content: content)

    // Register yoke's own hotkeys (start paused, independent of aerospace's config)
    YokeKeys.shared.setup()

    // Install the block tap (blocks unregistered keys when yoke is visible)
    if let (tap, source) = installYokeBlockTap() {
        YokePanel.shared.blockTap = tap
        YokePanel.shared.blockTapSource = source
        yokeLog("block tap installed")
    }

    // First launch: show panel passively (no yoke mode, no key blocking)
    if !OnboardingState.shared.isComplete {
        yokeLog("scheduling passive show via timer")
        Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
            DispatchQueue.main.async {
                yokeLog("firing passive show")
                YokePanel.shared.showPassive()
            }
        }
        // Space to start, Shift+P to skip onboarding
        let pKeyCode: UInt16 = 35
        let spaceKeyCode: UInt16 = 49
        func handleOnboardingKey(_ event: NSEvent) {
            if event.keyCode == spaceKeyCode && OnboardingState.shared.step == 1 {
                DispatchQueue.main.async { OnboardingState.shared.runBootSequence() }
            } else if event.keyCode == pKeyCode && event.modifierFlags.contains(.shift) {
                DispatchQueue.main.async { OnboardingState.shared.skipOnboarding() }
            }
        }
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { handleOnboardingKey($0) }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { handleOnboardingKey($0); return $0 }
    } else {
        yokeLog("onboarding complete, skipping passive show")
    }

    yokeLog("initYoke: done")
}

func yokeLog(_ msg: String) {
    let line = "[YOKE] \(msg)\n"
    guard let data = line.data(using: .utf8) else { return }
    let path = "/tmp/yoke.log"
    if !FileManager.default.fileExists(atPath: path) {
        FileManager.default.createFile(atPath: path, contents: nil)
    }
    guard let logFile = FileHandle(forWritingAtPath: path) else { return }
    logFile.seekToEndOfFile()
    logFile.write(data)
    logFile.closeFile()
}

// MARK: - Re-inject after config reload

@MainActor private var yokeModifierMonitorsInstalled = false
@MainActor private var yokeGlobalFlagsMonitor: Any?
@MainActor private var yokeLocalFlagsMonitor: Any?

@MainActor
public func yokeOnConfigReloaded() {
    yokeLog("config reloaded — re-injecting yoke bindings")
    injectYokeBindingsIntoConfig()

    // Install modifier monitors once (remove old ones first to avoid leaks)
    if let m = yokeGlobalFlagsMonitor { NSEvent.removeMonitor(m) }
    if let m = yokeLocalFlagsMonitor { NSEvent.removeMonitor(m) }
    yokeGlobalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
        Task { @MainActor in
            let alt = event.modifierFlags.contains(.option)
            let shift = event.modifierFlags.contains(.shift)
            if alt != KeyState.shared.altHeld { KeyState.shared.altHeld = alt }
            if shift != KeyState.shared.shiftHeld { KeyState.shared.shiftHeld = shift }
        }
    }
    yokeLocalFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
        Task { @MainActor in
            let alt = event.modifierFlags.contains(.option)
            let shift = event.modifierFlags.contains(.shift)
            if alt != KeyState.shared.altHeld { KeyState.shared.altHeld = alt }
            if shift != KeyState.shared.shiftHeld { KeyState.shared.shiftHeld = shift }
        }
        return event
    }
    yokeModifierMonitorsInstalled = true

    // Don't call activateMode here — reloadConfig() already calls it after us
    yokeLog("injected bindings, waiting for activateMode from reloadConfig")
}

// MARK: - Mode switching helpers

@MainActor
func yokeSwitchToMode(_ mode: String, _ then: (@MainActor () -> Void)? = nil) {
    if case .cmd(let c) = parseCommand("mode \(mode)") {
        Task {
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            try? await runLightSession(.hotkeyBinding, token) {
                _ = try await c.run(.defaultEnv, CmdIo(stdin: .emptyStdin))
            }
            then?()
        }
    }
}

// MARK: - Inject Yoke key bindings into AeroSpace's mode system

@MainActor
func injectYokeBindingsIntoConfig() {
    // cmd-esc in main mode → enter yoke mode + show HUD (or handle onboarding)
    addBinding(toMode: mainModeId, key: .escape, modifiers: .command, commands: nil) {
        let ob = OnboardingState.shared
        if ob.isComplete {
            yokeSwitchToMode("yoke") {
                YokePanel.shared.show()
                YokeKeys.shared.activate()
            }
        } else if ob.step == 1 {
            ob.runBootSequence()
        } else if ob.isBooting {
            return
        } else if ob.step == 3 {
            ob.handleCmdEscToggle()
        } else if ob.step == 10 {
            // Help step — cmd-esc should just work normally if onboarding done
            if ob.isComplete { /* fall through to normal */ }
        } else if ob.step >= 4 {
            ob.advanceOnboarding()
        } else {
            if !YokePanel.shared.isVisible {
                YokePanel.shared.showPassive()
            }
        }
    }

    // esc/enter in yoke mode → exit yoke mode + hide panel + deactivate keys
    func yokeExit(_ key: Key) {
        addBinding(toMode: "yoke", key: key, modifiers: [], commands: nil) {
            YokeKeys.shared.deactivate()
            YokePanel.shared.hide()
            yokeSwitchToMode("main")
        }
    }
    yokeExit(.escape)
    yokeExit(.return)

    yokeLog("injected 3 config bindings (cmd-esc, esc, enter)")
}

// MARK: - Helper: add a binding to a mode

@MainActor
func addBinding(toMode mode: String, key: Key, modifiers: NSEvent.ModifierFlags, commands cmdStr: String?, afterAction: @escaping @MainActor () -> Void) {
    // Parse the aerospace command(s) if any
    var cmds: [any Command] = []
    if let cmdStr {
        for part in cmdStr.split(separator: ";").map(String.init) {
            if case .cmd(let c) = parseCommand(part.trimmingCharacters(in: .whitespaces)) {
                cmds.append(c)
            }
        }
    }

    let keyNotation = (modifiers.isEmpty ? "" : modifiers.toString() + "-") + key.toString()
    let binding = HotkeyBinding(modifiers, key, cmds, descriptionWithKeyNotation: keyNotation)

    yokeAfterActions[keyNotation] = afterAction
    config.modes[mode, default: .zero].bindings[binding.descriptionWithKeyCode] = binding
}

// Store after-action closures for the 3 config bindings (cmd-esc, esc, enter)
@MainActor var yokeAfterActions: [String: @MainActor () -> Void] = [:]

// MARK: - Registered key combos for the block tap (thread-safe)

struct YokeKeyCombo: Hashable {
    let keyCode: UInt16
    let shift: Bool
    let alt: Bool
    let cmd: Bool
}

nonisolated let yokeStateQueue = DispatchQueue(label: "yoke.state")
nonisolated(unsafe) private var _yokeRegisteredKeys = Set<YokeKeyCombo>()

nonisolated func yokeSetRegisteredKeys(_ keys: Set<YokeKeyCombo>) {
    yokeStateQueue.sync { _yokeRegisteredKeys = keys }
}

nonisolated func yokeCheckRegisteredKey(_ combo: YokeKeyCombo) -> Bool {
    yokeStateQueue.sync { _yokeRegisteredKeys.contains(combo) }
}

// MARK: - Event tap to block unregistered keys in yoke mode

nonisolated func installYokeBlockTap() -> (CFMachPort, CFRunLoopSource)? {
    let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .tailAppendEventTap, // after HotKey handlers
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: { _, type, event, _ -> Unmanaged<CGEvent>? in
            // Only block when yoke is visible (check without MainActor)
            guard yokeIsPanelVisible() else {
                return Unmanaged.passUnretained(event)
            }

            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            let combo = YokeKeyCombo(
                keyCode: keyCode,
                shift: flags.contains(.maskShift),
                alt: flags.contains(.maskAlternate),
                cmd: flags.contains(.maskCommand)
            )

            // If this key is registered, let it through (HotKey already handled it)
            if yokeCheckRegisteredKey(combo) {
                return Unmanaged.passUnretained(event)
            }

            // Also allow modifier-only changes and esc/enter (already handled by HotKey)
            let escCode: UInt16 = 53
            let enterCode: UInt16 = 36
            if keyCode == escCode || keyCode == enterCode {
                return Unmanaged.passUnretained(event)
            }

            // Block unregistered key + flash error
            if type == .keyDown {
                DispatchQueue.main.async {
                    KeyState.shared.errorFlash = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    KeyState.shared.errorFlash = false
                }
            }
            return nil // swallow
        },
        userInfo: nil
    ) else {
        return nil
    }

    guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
        return nil
    }
    // Don't add to run loop yet — show() will add it
    CGEvent.tapEnable(tap: tap, enable: false) // start disabled
    return (tap, runLoopSource)
}

// Thread-safe visibility flag for the event tap callback
nonisolated(unsafe) private var _yokePanelVisible = false

nonisolated func yokeSetPanelVisible(_ value: Bool) {
    yokeStateQueue.sync { _yokePanelVisible = value }
}

nonisolated func yokeIsPanelVisible() -> Bool {
    yokeStateQueue.sync { _yokePanelVisible }
}

// MARK: - UI refresh after any yoke action

@MainActor
func yokeRefreshUI() {
    WorkspaceMap.shared.refreshAll()
    // No border during early onboarding steps
    if OnboardingState.shared.isComplete || OnboardingState.shared.step >= 5 {
        showFocusBorder()
    }
    KeyState.shared.focusedIsFloating = focus.windowOrNil?.isFloating ?? false
    OnboardingState.shared.updateWindowCount(WorkspaceMap.shared.windows.count)
}

// MARK: - Floating window helpers

@MainActor
func resizeFloatingWindow(by amount: CGFloat) {
    guard let window = focus.windowOrNil, window.isFloating,
          let macWin = window as? MacWindow else { return }

    // Get current frame via CGWindowList
    guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return }
    for w in windowList {
        guard let wid = w[kCGWindowNumber as String] as? UInt32,
              wid == window.windowId,
              let bounds = w[kCGWindowBounds as String] as? [String: CGFloat],
              let x = bounds["X"], let y = bounds["Y"],
              let width = bounds["Width"], let height = bounds["Height"]
        else { continue }

        // Proportional resize: distribute amount by aspect ratio, clamp to screen
        let screen = focus.workspace.workspaceMonitor.visibleRect
        let total = width + height
        let hAmount = amount * (width / total)
        let vAmount = amount * (height / total)
        let newW = min(screen.width, max(200, width + hAmount))
        let newH = min(screen.height, max(200, height + vAmount))
        let newX = max(screen.topLeftX, x - (newW - width) / 2)
        let newY = max(screen.topLeftY, y - (newH - height) / 2)

        macWin.setAxFrame(CGPoint(x: newX, y: newY), CGSize(width: newW, height: newH))
        return
    }
}

// MARK: - Center floating window

@MainActor
func centerFocusedWindow() {
    guard let window = focus.windowOrNil, window.isFloating,
          let macWin = window as? MacWindow,
          let screen = NSScreen.main else { return }

    let screenFrame = screen.visibleFrame
    let margin: CGFloat = 80

    let w = screenFrame.width - margin * 2
    let h = screenFrame.height - margin * 2
    let x = screenFrame.origin.x + margin
    // AX uses top-left origin
    let screenHeight = screen.frame.height
    let y = screenHeight - screenFrame.origin.y - screenFrame.height + margin

    macWin.setAxFrame(CGPoint(x: x, y: y), CGSize(width: w, height: h))
}

// MARK: - Hook into AeroSpace's hotkey system to run after-actions
// This is called after each binding fires via the mode system

@MainActor
public func yokeAfterBinding(_ binding: String) {
    yokeLog("afterBinding: \(binding)")
    if let action = yokeAfterActions[binding] {
        action()
    }
}

// MARK: - Focus border

@MainActor var borderWindow: NSWindow?

@MainActor
func focusedWindowFrame() -> NSRect? {
    guard let window = focus.windowOrNil else { return nil }
    guard let mainScreen = NSScreen.screens.first else { return nil }
    let screenHeight = mainScreen.frame.height

    // Tiled windows: use layout rect (instant, no API call)
    if let rect = window.lastAppliedLayoutPhysicalRect {
        let flippedY = screenHeight - CGFloat(rect.topLeftY) - CGFloat(rect.height)
        return NSRect(
            x: CGFloat(rect.topLeftX),
            y: flippedY,
            width: CGFloat(rect.width),
            height: CGFloat(rect.height)
        )
    }

    // Floating windows: get from CGWindowList by window ID (fast, sync)
    guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return nil }
    for w in windowList {
        guard let wid = w[kCGWindowNumber as String] as? UInt32,
              wid == window.windowId,
              let bounds = w[kCGWindowBounds as String] as? [String: CGFloat],
              let x = bounds["X"], let y = bounds["Y"],
              let width = bounds["Width"], let height = bounds["Height"]
        else { continue }
        let flippedY = screenHeight - y - height
        return NSRect(x: x, y: flippedY, width: width, height: height)
    }

    return nil
}

class BorderView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cfg = activeSkin.borderConfig
        let inset: CGFloat = 10
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let path = CGPath(roundedRect: rect, cornerWidth: cfg.cornerRadius, cornerHeight: cfg.cornerRadius, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: cfg.glowRadius,
                       color: CGColor(red: cfg.glowColor.r, green: cfg.glowColor.g, blue: cfg.glowColor.b, alpha: cfg.glowColor.a))
        ctx.setStrokeColor(CGColor(red: cfg.color.r, green: cfg.color.g, blue: cfg.color.b, alpha: cfg.color.a))
        ctx.setLineWidth(cfg.strokeWidth)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }
}

@MainActor
func showFocusBorder() {
    guard let frame = focusedWindowFrame() else {
        removeFocusBorder()
        return
    }

    let inset = activeSkin.borderConfig.padding
    let borderFrame = frame.insetBy(dx: inset, dy: inset)

    if let win = borderWindow {
        win.setFrame(borderFrame, display: true)
    } else {
        let win = NSWindow(
            contentRect: borderFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
        win.ignoresMouseEvents = true
        win.hasShadow = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.contentView = BorderView(frame: win.contentView!.bounds)
        win.contentView?.autoresizingMask = [.width, .height]
        win.orderFrontRegardless()
        borderWindow = win
    }
}

@MainActor
func removeFocusBorder() {
    borderWindow?.orderOut(nil)
    borderWindow = nil
}
