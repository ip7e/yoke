import AppKit
import Common
import SwiftUI

// MARK: - Active skin

@MainActor let activeSkin: any YokeSkin = TESkin()

// MARK: - Public entry point

@MainActor
public func initYoke() {
    let content = activeSkin.makeView(keys: KeyState.shared)
    YokePanel.shared.show(content: content)
    WorkspaceMap.shared.refreshAll()
    installYokeEventTap()

    // Poll for state changes (backup — events will be primary later)
    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
        Task { @MainActor in
            WorkspaceMap.shared.refreshAll()
            YokePanel.shared.updateBorder()
        }
    }
}

// MARK: - Execute aerospace command directly (no CLI, no socket)

@MainActor
func yokeExec(_ cmdString: String) {
    Task { @MainActor in
        let parsed = parseCommand(cmdString)
        if case .cmd(let command) = parsed {
            _ = try? await [command].runCmdSeq(.defaultEnv, .emptyStdin)
            updateTrayText()
            WorkspaceMap.shared.refreshAll()
            YokePanel.shared.updateBorder()
        }
    }
}

// MARK: - Focus border around active window

@MainActor var borderWindow: NSWindow?

@MainActor
func focusedWindowFrame() -> NSRect? {
    guard let window = focus.windowOrNil,
          let rect = window.lastAppliedLayoutPhysicalRect else {
        return nil
    }
    // Convert from top-left origin to AppKit bottom-left origin
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

// MARK: - Key bindings

struct YokeBinding {
    let command: String
    let label: String
}

struct KeyCombo: Hashable {
    let keyCode: UInt16
    let shift: Bool
    let alt: Bool

    init(_ keyCode: UInt16, shift: Bool = false, alt: Bool = false) {
        self.keyCode = keyCode
        self.shift = shift
        self.alt = alt
    }
}

// Key codes
let kW: UInt16 = 13, kA: UInt16 = 0, kS: UInt16 = 1, kD: UInt16 = 2
let kQ: UInt16 = 12, kE: UInt16 = 14
let kT: UInt16 = 17, kY: UInt16 = 16, kF: UInt16 = 3
let kH: UInt16 = 4
let kEsc: UInt16 = 53, kEnter: UInt16 = 36
let k1: UInt16 = 18, k2: UInt16 = 19, k3: UInt16 = 20
let k4: UInt16 = 21, k5: UInt16 = 23, k6: UInt16 = 22
let k7: UInt16 = 26, k8: UInt16 = 28, k9: UInt16 = 25

let yokeBindings: [KeyCombo: YokeBinding] = [
    // Focus
    KeyCombo(kW):                    YokeBinding(command: "focus up", label: "W"),
    KeyCombo(kA):                    YokeBinding(command: "focus left", label: "A"),
    KeyCombo(kS):                    YokeBinding(command: "focus down", label: "S"),
    KeyCombo(kD):                    YokeBinding(command: "focus right", label: "D"),
    // Move
    KeyCombo(kW, alt: true):         YokeBinding(command: "move up", label: "⌥W"),
    KeyCombo(kA, alt: true):         YokeBinding(command: "move left", label: "⌥A"),
    KeyCombo(kS, alt: true):         YokeBinding(command: "move down", label: "⌥S"),
    KeyCombo(kD, alt: true):         YokeBinding(command: "move right", label: "⌥D"),
    // Resize
    KeyCombo(kQ):                    YokeBinding(command: "resize smart -150", label: "Q"),
    KeyCombo(kE):                    YokeBinding(command: "resize smart +150", label: "E"),
    KeyCombo(kQ, shift: true):       YokeBinding(command: "resize smart -50", label: "⇧Q"),
    KeyCombo(kE, shift: true):       YokeBinding(command: "resize smart +50", label: "⇧E"),
    // Layout
    KeyCombo(kT):                    YokeBinding(command: "layout tiles horizontal vertical", label: "T"),
    KeyCombo(kY):                    YokeBinding(command: "layout accordion horizontal vertical", label: "Y"),
    KeyCombo(kF):                    YokeBinding(command: "layout floating tiling", label: "F"),
    // Merge
    KeyCombo(kW, shift: true):       YokeBinding(command: "join-with up", label: "⇧W"),
    KeyCombo(kA, shift: true):       YokeBinding(command: "join-with left", label: "⇧A"),
    KeyCombo(kS, shift: true):       YokeBinding(command: "join-with down", label: "⇧S"),
    KeyCombo(kD, shift: true):       YokeBinding(command: "join-with right", label: "⇧D"),
    // Workspaces
    KeyCombo(k1):                    YokeBinding(command: "workspace 1", label: "1"),
    KeyCombo(k2):                    YokeBinding(command: "workspace 2", label: "2"),
    KeyCombo(k3):                    YokeBinding(command: "workspace 3", label: "3"),
    KeyCombo(k4):                    YokeBinding(command: "workspace 4", label: "4"),
    KeyCombo(k5):                    YokeBinding(command: "workspace 5", label: "5"),
    KeyCombo(k6):                    YokeBinding(command: "workspace 6", label: "6"),
    KeyCombo(k7):                    YokeBinding(command: "workspace 7", label: "7"),
    KeyCombo(k8):                    YokeBinding(command: "workspace 8", label: "8"),
    KeyCombo(k9):                    YokeBinding(command: "workspace 9", label: "9"),
    // Move to workspace
    KeyCombo(k1, alt: true):         YokeBinding(command: "move-node-to-workspace 1", label: "⌥1"),
    KeyCombo(k2, alt: true):         YokeBinding(command: "move-node-to-workspace 2", label: "⌥2"),
    KeyCombo(k3, alt: true):         YokeBinding(command: "move-node-to-workspace 3", label: "⌥3"),
    KeyCombo(k4, alt: true):         YokeBinding(command: "move-node-to-workspace 4", label: "⌥4"),
    KeyCombo(k5, alt: true):         YokeBinding(command: "move-node-to-workspace 5", label: "⌥5"),
    KeyCombo(k6, alt: true):         YokeBinding(command: "move-node-to-workspace 6", label: "⌥6"),
    KeyCombo(k7, alt: true):         YokeBinding(command: "move-node-to-workspace 7", label: "⌥7"),
    KeyCombo(k8, alt: true):         YokeBinding(command: "move-node-to-workspace 8", label: "⌥8"),
    KeyCombo(k9, alt: true):         YokeBinding(command: "move-node-to-workspace 9", label: "⌥9"),
    KeyCombo(k1, shift: true):       YokeBinding(command: "move-node-to-workspace 1", label: "⇧1"),
    KeyCombo(k2, shift: true):       YokeBinding(command: "move-node-to-workspace 2", label: "⇧2"),
    KeyCombo(k3, shift: true):       YokeBinding(command: "move-node-to-workspace 3", label: "⇧3"),
    KeyCombo(k4, shift: true):       YokeBinding(command: "move-node-to-workspace 4", label: "⇧4"),
    KeyCombo(k5, shift: true):       YokeBinding(command: "move-node-to-workspace 5", label: "⇧5"),
    KeyCombo(k6, shift: true):       YokeBinding(command: "move-node-to-workspace 6", label: "⇧6"),
    KeyCombo(k7, shift: true):       YokeBinding(command: "move-node-to-workspace 7", label: "⇧7"),
    KeyCombo(k8, shift: true):       YokeBinding(command: "move-node-to-workspace 8", label: "⇧8"),
    KeyCombo(k9, shift: true):       YokeBinding(command: "move-node-to-workspace 9", label: "⇧9"),
]

// MARK: - Key handling

@MainActor
func yokeHandleKeyDown(_ keyCode: UInt16, flags: CGEventFlags) -> Bool {
    // Help pages
    if keyCode == kH {
        let next = KeyState.shared.helpPage + 1
        KeyState.shared.helpPage = next > 5 ? 0 : next
        KeyState.shared.press("?")
        return true
    }

    let shift = flags.contains(.maskShift)
    let alt = flags.contains(.maskAlternate)
    let combo = KeyCombo(keyCode, shift: shift, alt: alt)

    guard let binding = yokeBindings[combo] else {
        // Block unregistered keys, flash error
        KeyState.shared.errorFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            KeyState.shared.errorFlash = false
        }
        return true
    }

    // Dismiss help on any other key
    if KeyState.shared.helpPage > 0 { KeyState.shared.helpPage = 0 }
    KeyState.shared.press(binding.label)

    // Execute command directly
    yokeExec(binding.command)

    return true
}

@MainActor
func yokeHandleKeyUp(_ keyCode: UInt16, flags: CGEventFlags) -> Bool {
    if keyCode == kH {
        KeyState.shared.release("?")
        return true
    }

    let shift = flags.contains(.maskShift)
    let alt = flags.contains(.maskAlternate)
    let combo = KeyCombo(keyCode, shift: shift, alt: alt)

    guard let binding = yokeBindings[combo] else {
        return true
    }

    KeyState.shared.release(binding.label)
    return true
}

// MARK: - CGEvent tap

func installYokeEventTap() {
    let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: { _, type, event, _ -> Unmanaged<CGEvent>? in
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags

            if type == .flagsChanged {
                Task { @MainActor in
                    KeyState.shared.updateModifiers(flags)
                }
                return Unmanaged.passUnretained(event)
            }

            if type == .keyDown {
                var handled = false
                // Must dispatch to main for @MainActor access
                DispatchQueue.main.sync {
                    handled = yokeHandleKeyDown(keyCode, flags: flags)
                }
                if handled { return nil }
            } else if type == .keyUp {
                var handled = false
                DispatchQueue.main.sync {
                    handled = yokeHandleKeyUp(keyCode, flags: flags)
                }
                if handled { return nil }
            }
            return Unmanaged.passUnretained(event)
        },
        userInfo: nil
    ) else {
        return
    }

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
}
