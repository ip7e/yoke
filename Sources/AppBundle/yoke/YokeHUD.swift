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
    let content = activeSkin.makeView(keys: KeyState.shared)
    YokePanel.shared.prepare(content: content)
    injectYokeBindings()

    // Install the block tap (blocks unregistered keys when yoke is visible)
    if let tap = installYokeBlockTap() {
        YokePanel.shared.blockTap = tap
        yokeLog("block tap installed")
    }

    // Restore saved layout after a delay (let aerospace discover windows first)
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(2))
        await restoreLayout()
    }
    yokeLog("initYoke: done, yoke mode has \(config.modes["yoke"]?.bindings.count ?? 0) bindings")
}

func yokeLog(_ msg: String) {
    let line = "[YOKE] \(msg)\n"
    if let data = line.data(using: .utf8) {
        let logFile = FileHandle(forWritingAtPath: "/tmp/yoke.log") ?? {
            FileManager.default.createFile(atPath: "/tmp/yoke.log", contents: nil)
            return FileHandle(forWritingAtPath: "/tmp/yoke.log")!
        }()
        logFile.seekToEndOfFile()
        logFile.write(data)
        logFile.closeFile()
    }
}

// MARK: - Re-inject after config reload

@MainActor
public func yokeOnConfigReloaded() {
    yokeLog("config reloaded — re-injecting yoke bindings")
    injectYokeBindingsIntoConfig()
}

// MARK: - Inject Yoke key bindings into AeroSpace's mode system

@MainActor
func injectYokeBindings() {
    injectYokeBindingsIntoConfig()

    // Track modifier keys (alt/shift) for UI indicators
    NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
        Task { @MainActor in
            let alt = event.modifierFlags.contains(.option)
            let shift = event.modifierFlags.contains(.shift)
            if alt != KeyState.shared.altHeld { KeyState.shared.altHeld = alt }
            if shift != KeyState.shared.shiftHeld { KeyState.shared.shiftHeld = shift }
        }
    }
    NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
        Task { @MainActor in
            let alt = event.modifierFlags.contains(.option)
            let shift = event.modifierFlags.contains(.shift)
            if alt != KeyState.shared.altHeld { KeyState.shared.altHeld = alt }
            if shift != KeyState.shared.shiftHeld { KeyState.shared.shiftHeld = shift }
        }
        return event
    }

    // Activate mode to register hotkeys (initAppBundle already activated main mode,
    // but our bindings weren't there yet)
    Task { @MainActor in
        try? await activateMode(activeMode)
        yokeLog("activated mode after injection: \(activeMode ?? "nil")")
    }
}

@MainActor
func injectYokeBindingsIntoConfig() {
    // cmd-esc in main mode → enter yoke mode + show HUD
    addBinding(toMode: mainModeId, key: .escape, modifiers: .command, commands: "mode yoke") {
        yokeLog("cmd-esc triggered! showing yoke")
        YokePanel.shared.show()
    }

    // Yoke mode bindings
    func yoke(_ key: Key, _ mods: NSEvent.ModifierFlags = [], cmd: String, label: String) {
        addBinding(toMode: "yoke", key: key, modifiers: mods, commands: cmd) {
            if KeyState.shared.helpPage > 0 { KeyState.shared.helpPage = 0 }
            KeyState.shared.press(label)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                KeyState.shared.release(label)
            }
            yokeRefreshUI()
        }
    }

    func yokeExit(_ key: Key) {
        addBinding(toMode: "yoke", key: key, modifiers: [], commands: "mode main") {
            YokePanel.shared.hide()
        }
    }

    // Exit
    yokeExit(.escape)
    yokeExit(.return)

    // Focus — WASD
    yoke(.w, cmd: "focus up", label: "W")
    yoke(.a, cmd: "focus left", label: "A")
    yoke(.s, cmd: "focus down", label: "S")
    yoke(.d, cmd: "focus right", label: "D")

    // Move — Alt+WASD
    yoke(.w, .option, cmd: "move up", label: "⌥W")
    yoke(.a, .option, cmd: "move left", label: "⌥A")
    yoke(.s, .option, cmd: "move down", label: "⌥S")
    yoke(.d, .option, cmd: "move right", label: "⌥D")

    // Merge — Shift+WASD
    yoke(.w, .shift, cmd: "join-with up", label: "⇧W")
    yoke(.a, .shift, cmd: "join-with left", label: "⇧A")
    yoke(.s, .shift, cmd: "join-with down", label: "⇧S")
    yoke(.d, .shift, cmd: "join-with right", label: "⇧D")

    // Resize — Q/E (Shift for fine). Floating: diagonal expand/collapse from center.
    func yokeResize(_ key: Key, mods: NSEvent.ModifierFlags = [], amount: CGFloat, label: String) {
        addBinding(toMode: "yoke", key: key, modifiers: mods, commands: nil) {
            if KeyState.shared.helpPage > 0 { KeyState.shared.helpPage = 0 }
            KeyState.shared.press(label)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                KeyState.shared.release(label)
            }
            if let window = focus.windowOrNil {
                if window.isFloating {
                    resizeFloatingWindow(by: amount)
                } else {
                    let dir = amount > 0 ? "+" : ""
                    if case .cmd(let cmd) = parseCommand("resize smart \(dir)\(Int(amount))") {
                        let env = CmdEnv(windowId: window.windowId, workspaceName: nil)
                        Task { _ = try? await cmd.run(env, CmdIo(stdin: .emptyStdin)) }
                    }
                }
            }
            yokeRefreshUI()
        }
    }

    yokeResize(.q, amount: -150, label: "Q")
    yokeResize(.e, amount: 150, label: "E")
    yokeResize(.q, mods: .shift, amount: -50, label: "⇧Q")
    yokeResize(.e, mods: .shift, amount: 50, label: "⇧E")

    // Float toggle — F (auto-centers on float)
    addBinding(toMode: "yoke", key: .f, modifiers: [], commands: "layout floating tiling") {
        if KeyState.shared.helpPage > 0 { KeyState.shared.helpPage = 0 }
        KeyState.shared.press("F")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            KeyState.shared.release("F")
        }
        if let window = focus.windowOrNil, window.isFloating {
            centerFocusedWindow()
        }
        yokeRefreshUI()
    }

    // Layout — R (tiles ↔ accordion), Shift+R (horizontal ↔ vertical). No-op when floating.
    addBinding(toMode: "yoke", key: .r, modifiers: [], commands: nil) {
        if KeyState.shared.helpPage > 0 { KeyState.shared.helpPage = 0 }
        KeyState.shared.press("R")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            KeyState.shared.release("R")
        }
        if let window = focus.windowOrNil, !window.isFloating {
            if case .cmd(let cmd) = parseCommand("layout tiles accordion") {
                let env = CmdEnv(windowId: window.windowId, workspaceName: nil)
                Task { _ = try? await cmd.run(env, CmdIo(stdin: .emptyStdin)) }
            }
        }
        yokeRefreshUI()
    }
    addBinding(toMode: "yoke", key: .r, modifiers: .shift, commands: nil) {
        if KeyState.shared.helpPage > 0 { KeyState.shared.helpPage = 0 }
        KeyState.shared.press("⇧R")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            KeyState.shared.release("⇧R")
        }
        if let window = focus.windowOrNil, !window.isFloating {
            if case .cmd(let cmd) = parseCommand("layout horizontal vertical") {
                let env = CmdEnv(windowId: window.windowId, workspaceName: nil)
                Task { _ = try? await cmd.run(env, CmdIo(stdin: .emptyStdin)) }
            }
        }
        yokeRefreshUI()
    }

    // Workspaces — 1-9 (Alt to move window)
    let numKeys: [Key] = [.one, .two, .three, .four, .five, .six, .seven, .eight, .nine]
    for (i, key) in numKeys.enumerated() {
        let n = i + 1
        yoke(key, cmd: "workspace \(n)", label: "\(n)")
        yoke(key, .option, cmd: "move-node-to-workspace \(n)", label: "⌥\(n)")
    }

    // Help — H
    addBinding(toMode: "yoke", key: .h, modifiers: [], commands: nil) {
        let next = KeyState.shared.helpPage + 1
        KeyState.shared.helpPage = next > 6 ? 0 : next
        KeyState.shared.press("H")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            KeyState.shared.release("H")
        }
    }

    yokeLog("injected \(config.modes["yoke"]?.bindings.count ?? 0) yoke bindings, main has \(config.modes[mainModeId]?.bindings.count ?? 0)")
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

    // Store the after-action
    yokeAfterActions[keyNotation] = afterAction

    // Register for the block tap (so it knows to let this key through)
    if mode == "yoke" {
        registerYokeKey(key, modifiers)
    }

    config.modes[mode, default: .zero].bindings[binding.descriptionWithKeyCode] = binding
}

// Store after-action closures keyed by notation
@MainActor var yokeAfterActions: [String: @MainActor () -> Void] = [:]

// MARK: - Registered key combos for the block tap (thread-safe, no MainActor)

struct YokeKeyCombo: Hashable {
    let keyCode: UInt16
    let shift: Bool
    let alt: Bool
    let cmd: Bool
}

// Set of all registered yoke key combos — accessed from event tap callback
nonisolated(unsafe) var yokeRegisteredKeys = Set<YokeKeyCombo>()

@MainActor
func registerYokeKey(_ key: Key, _ modifiers: NSEvent.ModifierFlags) {
    yokeRegisteredKeys.insert(YokeKeyCombo(
        keyCode: UInt16(key.carbonKeyCode),
        shift: modifiers.contains(.shift),
        alt: modifiers.contains(.option),
        cmd: modifiers.contains(.command)
    ))
}

// MARK: - Event tap to block unregistered keys in yoke mode

nonisolated func installYokeBlockTap() -> CFMachPort? {
    let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .tailAppendEventTap, // after HotKey handlers
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: { _, type, event, _ -> Unmanaged<CGEvent>? in
            // Only block when yoke is visible (check without MainActor)
            guard yokePanelVisible else {
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
            if yokeRegisteredKeys.contains(combo) {
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

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: false) // start disabled
    return tap
}

// Thread-safe visibility flag for the event tap callback
nonisolated(unsafe) var yokePanelVisible = false

// MARK: - UI refresh after any yoke action

@MainActor
func yokeRefreshUI() {
    WorkspaceMap.shared.refreshAll()
    showFocusBorder()
    KeyState.shared.focusedIsFloating = focus.windowOrNil?.isFloating ?? false
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

        // Expand/collapse from center: grow each edge by amount/2
        let dx = amount / 2
        let dy = amount / 2
        let newW = max(200, width + amount)
        let newH = max(200, height + amount)
        let newX = x - dx
        let newY = y - dy

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
