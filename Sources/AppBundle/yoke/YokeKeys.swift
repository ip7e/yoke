import AppKit
import HotKey

// MARK: - Yoke's own hotkey manager (independent of aerospace's config system)

@MainActor
class YokeKeys {
    static let shared = YokeKeys()
    private var hotkeys: [String: HotKey] = [:]
    private(set) var isActive = false

    /// Register all yoke hotkeys (start paused). Call once at init.
    func setup() {
        yokeLog("YokeKeys: setup")

        // Focus — WASD
        bind(.w, cmd: "focus up", label: "W")
        bind(.a, cmd: "focus left", label: "A")
        bind(.s, cmd: "focus down", label: "S")
        bind(.d, cmd: "focus right", label: "D")

        // Move — Alt+WASD
        bind(.w, .option, cmd: "move up", label: "⌥W")
        bind(.a, .option, cmd: "move left", label: "⌥A")
        bind(.s, .option, cmd: "move down", label: "⌥S")
        bind(.d, .option, cmd: "move right", label: "⌥D")

        // Merge — Shift+WASD
        bind(.w, .shift, cmd: "join-with up", label: "⇧W")
        bind(.a, .shift, cmd: "join-with left", label: "⇧A")
        bind(.s, .shift, cmd: "join-with down", label: "⇧S")
        bind(.d, .shift, cmd: "join-with right", label: "⇧D")

        // Resize — Q/E, Shift+Q/E for fine
        bindResize(.q, amount: -150, label: "Q")
        bindResize(.e, amount: 150, label: "E")
        bindResize(.q, .shift, amount: -50, label: "⇧Q")
        bindResize(.e, .shift, amount: 50, label: "⇧E")

        // Float toggle — F
        bindCustom(.f, label: "F") {
            yokeRunCommand("layout floating tiling")
            if let window = focus.windowOrNil, window.isFloating {
                centerFocusedWindow()
            }
            yokeRefreshUI()
            OnboardingState.shared.recordFloatPress()
        }

        // Layout — R (tiles ↔ accordion)
        bindCustom(.r, label: "R") {
            if let window = focus.windowOrNil, !window.isFloating {
                yokeRunCommand("layout tiles accordion")
            }
            yokeRefreshUI()
        }

        // Layout — Shift+R (horizontal ↔ vertical)
        bindCustom(.r, .shift, label: "⇧R") {
            if let window = focus.windowOrNil, !window.isFloating {
                yokeRunCommand("layout horizontal vertical")
            }
            yokeRefreshUI()
        }

        // Workspaces — 1-9
        let numKeys: [Key] = [.one, .two, .three, .four, .five, .six, .seven, .eight, .nine]
        for (i, key) in numKeys.enumerated() {
            let n = i + 1
            bind(key, cmd: "workspace \(n)", label: "\(n)")
            bind(key, .option, cmd: "move-node-to-workspace \(n)", label: "⌥\(n)")
        }

        // Update — U (open release page when update available)
        bindCustom(.u, label: "U") {
            if UpdateChecker.shared.availableVersion != nil {
                UpdateChecker.shared.openReleasePage()
            }
        }

        // Help — H
        bindCustom(.h, label: "H", dismissHelp: false) {
            OnboardingState.shared.helpPressedDuringOnboarding()
            let next = KeyState.shared.helpPage + 1
            KeyState.shared.helpPage = next > 6 ? 0 : next
            KeyState.shared.creditsStartTick = -1 // reset credits scroll
        }

        // Space — onboarding advance (no-op when onboarded)
        bindCustom(.space, label: "SPC", dismissHelp: false) {
            let ob = OnboardingState.shared
            if ob.isActive && (ob.step != 7 || ob.floatReady) {
                ob.advanceOnboarding()
            }
        }

        // Register all key combos with the block tap
        yokeSetRegisteredKeys(registeredCombos)

        yokeLog("YokeKeys: registered \(hotkeys.count) hotkeys")
    }

    /// Activate all yoke hotkeys (called when entering yoke mode)
    func activate() {
        guard !isActive else { return }
        isActive = true
        for hk in hotkeys.values { hk.isPaused = false }
        yokeLog("YokeKeys: activated")
    }

    /// Deactivate all yoke hotkeys (called when leaving yoke mode)
    func deactivate() {
        guard isActive else { return }
        isActive = false
        for hk in hotkeys.values { hk.isPaused = true }
        yokeLog("YokeKeys: deactivated")
    }

    // MARK: - Registration helpers

    private var registeredCombos = Set<YokeKeyCombo>()

    private func trackCombo(_ key: Key, _ mods: NSEvent.ModifierFlags) {
        registeredCombos.insert(YokeKeyCombo(
            keyCode: UInt16(key.carbonKeyCode),
            shift: mods.contains(.shift),
            alt: mods.contains(.option),
            cmd: mods.contains(.command)
        ))
    }

    /// Standard binding: run an aerospace command + refresh UI
    private func bind(_ key: Key, _ mods: NSEvent.ModifierFlags = [], cmd: String, label: String) {
        let id = hotkeyId(key, mods)
        trackCombo(key, mods)
        let hk = HotKey(key: key, modifiers: mods)
        hk.keyDownHandler = {
            if KeyState.shared.helpPage > 0 { KeyState.shared.helpPage = 0 }
            KeyState.shared.press(label)
            yokeRunCommand(cmd)
            yokeRefreshUI()
        }
        hk.keyUpHandler = {
            KeyState.shared.release(label)
        }
        hk.isPaused = true
        hotkeys[id] = hk
    }

    /// Resize binding: handles floating (diagonal) vs tiled (smart resize)
    private func bindResize(_ key: Key, _ mods: NSEvent.ModifierFlags = [], amount: CGFloat, label: String) {
        let id = hotkeyId(key, mods)
        trackCombo(key, mods)
        let hk = HotKey(key: key, modifiers: mods)
        hk.keyDownHandler = {
            if KeyState.shared.helpPage > 0 { KeyState.shared.helpPage = 0 }
            KeyState.shared.press(label)
            if let window = focus.windowOrNil {
                if window.isFloating {
                    resizeFloatingWindow(by: amount)
                } else {
                    let dir = amount > 0 ? "+" : ""
                    yokeRunCommand("resize smart \(dir)\(Int(amount))")
                }
            }
            yokeRefreshUI()
        }
        hk.keyUpHandler = {
            KeyState.shared.release(label)
        }
        hk.isPaused = true
        hotkeys[id] = hk
    }

    /// Custom binding: run arbitrary closure
    private func bindCustom(_ key: Key, _ mods: NSEvent.ModifierFlags = [], label: String, dismissHelp: Bool = true, action: @escaping @MainActor () -> Void) {
        let id = hotkeyId(key, mods)
        trackCombo(key, mods)
        let hk = HotKey(key: key, modifiers: mods)
        hk.keyDownHandler = {
            if dismissHelp && KeyState.shared.helpPage > 0 { KeyState.shared.helpPage = 0 }
            KeyState.shared.press(label)
            action()
        }
        hk.keyUpHandler = {
            KeyState.shared.release(label)
        }
        hk.isPaused = true
        hotkeys[id] = hk
    }

    private func hotkeyId(_ key: Key, _ mods: NSEvent.ModifierFlags) -> String {
        let modStr = mods.isEmpty ? "" : mods.toString() + "-"
        return modStr + key.toString()
    }
}

// MARK: - Safe command execution wrapper

@MainActor
func yokeRunCommand(_ cmd: String) {
    if case .cmd(let c) = parseCommand(cmd) {
        Task {
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            try? await runLightSession(.hotkeyBinding, token) {
                _ = try await c.run(.defaultEnv, CmdIo(stdin: .emptyStdin))
            }
            yokeRefreshUI()
        }
    }
}
