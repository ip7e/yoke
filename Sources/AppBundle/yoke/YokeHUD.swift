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
            WorkspaceMap.shared.refreshAll()
            showFocusBorder()
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

    // Focus
    yoke(.w, cmd: "focus up", label: "W")
    yoke(.a, cmd: "focus left", label: "A")
    yoke(.s, cmd: "focus down", label: "S")
    yoke(.d, cmd: "focus right", label: "D")

    // Move
    yoke(.w, .option, cmd: "move up", label: "⌥W")
    yoke(.a, .option, cmd: "move left", label: "⌥A")
    yoke(.s, .option, cmd: "move down", label: "⌥S")
    yoke(.d, .option, cmd: "move right", label: "⌥D")

    // Resize
    yoke(.q, cmd: "resize smart -150", label: "Q")
    yoke(.e, cmd: "resize smart +150", label: "E")
    yoke(.q, .shift, cmd: "resize smart -50", label: "⇧Q")
    yoke(.e, .shift, cmd: "resize smart +50", label: "⇧E")

    // Layout
    yoke(.t, cmd: "layout tiles horizontal vertical", label: "T")
    yoke(.y, cmd: "layout accordion horizontal vertical", label: "Y")
    yoke(.f, cmd: "layout floating tiling", label: "F")

    // Merge
    yoke(.w, .shift, cmd: "join-with up", label: "⇧W")
    yoke(.a, .shift, cmd: "join-with left", label: "⇧A")
    yoke(.s, .shift, cmd: "join-with down", label: "⇧S")
    yoke(.d, .shift, cmd: "join-with right", label: "⇧D")

    // Workspaces
    let numKeys: [Key] = [.one, .two, .three, .four, .five, .six, .seven, .eight, .nine]
    for (i, key) in numKeys.enumerated() {
        let n = i + 1
        yoke(key, cmd: "workspace \(n)", label: "\(n)")
        yoke(key, .option, cmd: "move-node-to-workspace \(n)", label: "⌥\(n)")
        yoke(key, .shift, cmd: "move-node-to-workspace \(n)", label: "⇧\(n)")
    }

    // Help (no aerospace command, just UI)
    addBinding(toMode: "yoke", key: .h, modifiers: [], commands: nil) {
        let next = KeyState.shared.helpPage + 1
        KeyState.shared.helpPage = next > 5 ? 0 : next
        KeyState.shared.press("?")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            KeyState.shared.release("?")
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

    config.modes[mode, default: .zero].bindings[binding.descriptionWithKeyCode] = binding
}

// Store after-action closures keyed by notation
@MainActor var yokeAfterActions: [String: @MainActor () -> Void] = [:]

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
    guard let window = focus.windowOrNil,
          let rect = window.lastAppliedLayoutPhysicalRect else {
        return nil
    }
    guard let mainScreen = NSScreen.screens.first else { return nil }
    let screenHeight = mainScreen.frame.height
    let flippedY = screenHeight - CGFloat(rect.topLeftY) - CGFloat(rect.height)
    return NSRect(
        x: CGFloat(rect.topLeftX),
        y: flippedY,
        width: CGFloat(rect.width),
        height: CGFloat(rect.height)
    )
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
        win.level = .floating
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
