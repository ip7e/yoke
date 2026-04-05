import AppKit
import SwiftUI

// MARK: - Feature groups that get unlocked during onboarding

enum YokeFeature: String, Codable, CaseIterable {
    case dpad       // WASD focus
    case move       // Alt+WASD move
    case merge      // Shift+WASD merge
    case resize     // Q/E resize
    case workspaces // 1-9 workspace switching
    case sendTo     // Alt+1-9 move to workspace
    case float      // F float toggle
    case layout     // R layout cycle
    case help       // H help
}

// MARK: - Onboarding state

@MainActor
class OnboardingState: ObservableObject {
    static let shared = OnboardingState()

    /// Current step. 0 = not started, -1 = complete, 1+ = in progress
    @Published var step: Int = 0

    /// Which feature groups are currently enabled
    @Published var enabledFeatures: Set<YokeFeature> = []

    /// Message to show on the screen during onboarding
    @Published var screenMessage: String = ""

    /// Sub-message (smaller text below main)
    @Published var screenHint: String = ""

    /// Boot progress 0.0 → 1.0 over ~8 seconds. Skin derives all visuals from this.
    @Published var bootProgress: CGFloat = -1 // -1 = not booting

    /// Cmd-esc training: how many times user has pressed it (step 3)
    @Published var cmdEscCount: Int = 0
    /// Whether to show the progress dots (after typewriter finishes)
    @Published var showDots: Bool = false

    /// Whether device looks powered off
    var isPoweredOff: Bool { step == 1 && bootProgress < 0 }
    var isBooting: Bool { bootProgress >= 0 && bootProgress <= 1 }

    var isComplete: Bool { step == -1 }
    var isActive: Bool { step > 0 }

    private static let persistPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/yoke/onboarding.json")

    // MARK: - Persistence

    struct SavedState: Codable {
        var completed: Bool
    }

    func load() {
        guard FileManager.default.fileExists(atPath: Self.persistPath.path) else {
            yokeLog("onboarding: no saved state, first run")
            return
        }
        do {
            let data = try Data(contentsOf: Self.persistPath)
            let saved = try JSONDecoder().decode(SavedState.self, from: data)
            if saved.completed {
                step = -1
                enabledFeatures = Set(YokeFeature.allCases)
                yokeLog("onboarding: already completed")
            }
        } catch {
            yokeLog("onboarding: load error \(error)")
        }
    }

    func markComplete() {
        step = -1
        enabledFeatures = Set(YokeFeature.allCases)
        save()
        yokeLog("onboarding: marked complete")
    }

    private func save() {
        do {
            let dir = Self.persistPath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(SavedState(completed: isComplete))
            try data.write(to: Self.persistPath)
        } catch {
            yokeLog("onboarding: save error \(error)")
        }
    }

    // MARK: - Step management

    /// Enable a feature group and advance to a step
    func advanceTo(step newStep: Int, enabling features: [YokeFeature] = [], message: String = "", hint: String = "") {
        for f in features {
            enabledFeatures.insert(f)
        }
        step = newStep
        screenMessage = message
        screenHint = hint
    }

    /// Check if a specific feature is currently enabled
    func isEnabled(_ feature: YokeFeature) -> Bool {
        isComplete || enabledFeatures.contains(feature)
    }

    private var bootTimer: Timer?

    /// Start the onboarding flow
    func startOnboarding() {
        advanceTo(step: 1, message: "⌘ ESC", hint: "press to start")
        bootProgress = -1
    }

    /// Run the boot-up animation: drives bootProgress from 0→1 over 5 seconds.
    /// The skin reads bootProgress and derives all visuals from it.
    func runBootSequence() {
        guard step == 1 else { return }
        yokeLog("onboarding: boot sequence start")

        let duration: CGFloat = 8.0
        let startTime = CACurrentMediaTime()
        bootProgress = 0

        bootTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let elapsed = CGFloat(CACurrentMediaTime() - startTime)
                let p = min(elapsed / duration, 1.0)
                self.bootProgress = p

                if p >= 1.0 {
                    self.bootTimer?.invalidate()
                    self.bootTimer = nil
                    self.bootProgress = 1.0
                    // Brief YOKE display, then blank, then start onboarding
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.bootProgress = -1
                        self.step = 3
                        self.screenMessage = ""
                        self.screenHint = ""
                        // Blank screen for a beat
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.startCmdEscStep()
                        }
                    }
                }
            }
        }
    }

    /// Typewriter progress: how many characters to show
    @Published var typewriterChars: Int = 0
    private var typewriterText: String = ""
    private var typewriterCompletion: (@MainActor () -> Void)?
    private(set) var isTyping: Bool = false

    /// Start typing text character by character with natural rhythm
    func typewrite(_ text: String, then: @escaping @MainActor () -> Void = {}) {
        typewriterText = text
        typewriterChars = 0
        isTyping = true
        typewriterCompletion = then
        let chars = Array(text)
        var idx = 0

        func scheduleNext() {
            let ch = chars[idx]
            let base: Double
            if ch == "." || ch == "!" { base = 0.12 }
            else if ch == "," { base = 0.08 }
            else if ch == "\n" { base = 0.10 }
            else { base = 0.035 }
            let jitter = Double.random(in: -0.015...0.025)
            let delay = max(0.02, base + jitter)

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.isTyping else { return }
                idx += 1
                typewriterChars = idx
                if idx >= chars.count {
                    self.isTyping = false
                    self.typewriterCompletion?()
                    self.typewriterCompletion = nil
                } else {
                    scheduleNext()
                }
            }
        }

        if !chars.isEmpty { scheduleNext() }
    }

    /// Skip to end of current typewriter animation
    func finishTyping() {
        guard isTyping else { return }
        isTyping = false
        typewriterChars = typewriterText.count
        typewriterCompletion?()
        typewriterCompletion = nil
    }

    /// The currently visible portion of typewriter text
    var typewriterVisible: String {
        String(typewriterText.prefix(typewriterChars))
    }

    /// Whether we're waiting for user to reopen yoke after hide
    @Published var waitingForReopen: Bool = false

    /// Step 3: teach cmd-esc toggle
    func startCmdEscStep() {
        showDots = false
        waitingForReopen = false
        advanceTo(step: 3, message: "", hint: "")
        typewrite("⌘ ESC toggles YOKE.\ntry it — close and reopen.")
    }

    /// Called when user presses cmd-esc during step 3
    func handleCmdEscToggle() {
        guard step == 3 else { return }
        if YokePanel.shared.isVisible && !waitingForReopen {
            // First press: close
            YokePanel.shared.hidePassive()
            waitingForReopen = true
        } else if waitingForReopen {
            // Second press: reopen — they learned it
            waitingForReopen = false
            YokePanel.shared.showPassive()
            typewrite("nice!\nhit SPACE to continue.") { [self] in
                installKeyMonitor { [self] code in
                    if code == 49 && self.step == 3 {
                        self.removeKeyMonitors()
                        self.startWindowCheck()
                    }
                }
            }
        }
    }

    /// Step 4: ensure 3+ windows, then teach WASD
    @Published var windowDots: Int = 0

    func startWindowCheck() {
        showDots = false
        let count = min(WorkspaceMap.shared.windows.count, 3)
        windowDots = count

        if count >= 3 {
            // Already have enough windows, go straight to WASD
            startWasdStep()
        } else {
            advanceTo(step: 4, message: "", hint: "")
            typewrite("open at least 3 windows\nto continue.") { [self] in
                showDots = true
            }
        }
    }

    /// Called from poll timer to update window count during step 4
    func updateWindowCount(_ count: Int) {
        guard step == 4, showDots else { return }
        let capped = min(count, 3)
        if capped != windowDots { windowDots = capped }
        if capped >= 3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                guard step == 4 else { return }
                startWasdStep()
            }
        }
    }

    /// Called when user presses cmd-esc during step 4 (window check)
    func confirmWindowsReady() {
        WorkspaceMap.shared.refreshAll()
        let count = min(WorkspaceMap.shared.windows.count, 3)
        windowDots = count
        if count >= 3 {
            startWasdStep()
        }
    }

    /// Step 5: WASD — enter yoke mode, reveal joystick, teach focus
    func startWasdStep() {
        showDots = false
        advanceTo(step: 5, enabling: [.dpad, .move, .merge], message: "", hint: "")

        // Enter real yoke mode — keys trapped, border shown, WASD works
        yokeSwitchToMode("yoke") {
            YokePanel.shared.hidePassive()
            YokePanel.shared.show()
            YokeKeys.shared.activate()
        }

        typewrite("WASD moves focus\nbetween windows. try it.\nSPACE to continue.")
    }

    /// Step 6: resize — reveal +/- buttons
    func startResizeStep() {
        showDots = false
        advanceTo(step: 6, enabling: [.resize], message: "", hint: "")
        typewrite("Q/E resizes active\nwindow.\nSPACE to continue.") { [self] in
            listenForResize()
        }
    }

    /// Step 7: float — reveal float button, track F presses
    @Published var floatPressCount: Int = 0
    @Published var floatReady: Bool = false

    func startFloatStep() {
        showDots = false
        floatPressCount = 0
        floatReady = false
        advanceTo(step: 7, enabling: [.float], message: "", hint: "")

        // Enter yoke mode if not already
        if !YokeKeys.shared.isActive {
            yokeSwitchToMode("yoke") {
                YokePanel.shared.hidePassive()
                YokePanel.shared.show()
                YokeKeys.shared.activate()
            }
        }

        typewrite("windows are tiled or\nfloating. F toggles.\ntry a few.")
    }

    func recordFloatPress() {
        guard step == 7 else { return }
        floatPressCount += 1
        if floatPressCount >= 3 && !floatReady {
            floatReady = true
            // Append "SPACE to continue" by rewriting
            typewriterText = "windows are tiled or\nfloating. F toggles.\ntry a few.\nSPACE to continue."
            typewriterChars = typewriterText.count
        }
    }

    /// Step 8: ALT/SHIFT + WASD
    func startModifiersStep() {
        showDots = false
        advanceTo(step: 8, enabling: [.workspaces, .sendTo], message: "", hint: "")
        typewrite("ALT + WASD moves windows.\nSHIFT + WASD merges.\nSPACE to continue.")
    }

    /// Step 9: workspaces
    func startWorkspacesStep() {
        showDots = false
        advanceTo(step: 9, enabling: [.workspaces, .sendTo], message: "", hint: "")
        typewrite("1-9 switches workspace.\nALT+1-9 sends window.\nSPACE to continue.")
    }

    /// Step 10: help — reveal everything. First H press completes onboarding and opens help.
    func startHelpStep() {
        showDots = false
        advanceTo(step: 10, enabling: [.layout, .help], message: "", hint: "")
        typewrite("press H for help.\nit has everything else.")
    }

    /// Called when H is pressed — if onboarding step 10, graduate immediately
    func helpPressedDuringOnboarding() {
        guard step == 10, !isComplete else { return }
        markComplete()
        yokeRefreshUI()
        yokeLog("onboarding: graduated via H press")
    }

    private var keyMonitor: Any?
    private var localKeyMonitor: Any?

    private func removeKeyMonitors() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        if let m = localKeyMonitor { NSEvent.removeMonitor(m); localKeyMonitor = nil }
    }

    private func installKeyMonitor(_ handler: @escaping @MainActor (UInt16) -> Void) {
        removeKeyMonitors()
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let code = event.keyCode
            DispatchQueue.main.async { handler(code) }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let code = event.keyCode
            DispatchQueue.main.async { handler(code) }
            return event
        }
    }

    // Key codes
    private let kW: UInt16 = 13, kA: UInt16 = 0, kS: UInt16 = 1, kD: UInt16 = 2
    private let kQ: UInt16 = 12, kE: UInt16 = 14

    /// Step 4: listen for WASD to animate joystick only
    func listenForWasd() {
        installKeyMonitor { [self] code in
            guard step == 4 else { return }
            let map: [UInt16: String] = [kW: "W", kA: "A", kS: "S", kD: "D"]
            guard let label = map[code] else { return }
            KeyState.shared.press(label)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                KeyState.shared.release(label)
            }
        }
    }

    /// Step 5: listen for Q/E to animate buttons + resize window
    func listenForResize() {
        installKeyMonitor { [self] code in
            guard step == 5 else { return }
            let amount: CGFloat
            let label: String
            if code == self.kE { amount = 150; label = "E" }
            else if code == self.kQ { amount = -150; label = "Q" }
            else { return }

            KeyState.shared.press(label)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { KeyState.shared.release(label) }

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
        }
    }

    /// Step 7: listen for any key to close
    func listenForAnyKey() {
        installKeyMonitor { [self] _ in
            guard step == 8 else { return }
            finishOnboarding()
        }
    }

    /// Finish onboarding — mark complete, stay in yoke mode
    func finishOnboarding() {
        removeKeyMonitors()
        markComplete()
        yokeRefreshUI()
    }

    /// Called when user presses cmd-esc during onboarding steps 4+
    func advanceOnboarding() {
        // If still typing, just skip to end — don't advance yet
        if isTyping {
            finishTyping()
            return
        }
        yokeLog("onboarding: advance from step \(step)")
        removeKeyMonitors()
        switch step {
        case 4: confirmWindowsReady()
        case 5: startResizeStep()
        case 6: startFloatStep()
        case 7: startModifiersStep()
        case 8: startHelpStep()
        default: break
        }
    }

    /// Skip entire onboarding — enter yoke mode
    func skipOnboarding() {
        yokeLog("onboarding: skipped")
        isTyping = false
        typewriterCompletion = nil
        bootTimer?.invalidate()
        bootTimer = nil
        bootProgress = -1
        removeKeyMonitors()
        enabledFeatures = Set(YokeFeature.allCases)
        markComplete()
        // Enter yoke mode instead of hiding
        yokeSwitchToMode("yoke") {
            YokePanel.shared.hidePassive()
            YokePanel.shared.show()
            YokeKeys.shared.activate()
        }
    }

    /// Reset onboarding (for testing)
    func reset() {
        removeKeyMonitors()
        step = 0
        enabledFeatures = []
        screenMessage = ""
        screenHint = ""
        try? FileManager.default.removeItem(at: Self.persistPath)
        yokeLog("onboarding: reset")
    }
}
