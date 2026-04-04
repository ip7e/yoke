import AppKit
import SwiftUI

@MainActor
final class YokePanel {
    static let shared = YokePanel()
    private var panel: NSPanel?
    private(set) var isVisible = false
    private var pollTimer: Timer?
    var blockTap: CFMachPort?
    var blockTapSource: CFRunLoopSource?

    func prepare(content: some View) {
        let hosting = NSHostingView(rootView: content)
        hosting.setFrameSize(hosting.fittingSize)

        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.nonactivatingPanel, .borderless, .hudWindow, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        p.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 3)
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = true
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.contentView = hosting
        panel = p
    }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        guard let panel, !isVisible else { return }
        yokeLog("panel: show")
        isVisible = true

        centerOnScreen()
        panel.orderFrontRegardless()
        yokeSetPanelVisible(true)
        if let source = blockTapSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        if let tap = blockTap { CGEvent.tapEnable(tap: tap, enable: true) }
        TapeState.shared.start()
        yokeRefreshUI()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                yokeRefreshUI()
            }
        }
    }

    /// Show panel as passive overlay — no yoke mode, no key blocking, no borders
    func showPassive() {
        guard let panel, !isVisible else { return }
        yokeLog("panel: showPassive")
        isVisible = true

        centerOnScreen()
        panel.orderFrontRegardless()
        TapeState.shared.start()

        // Light poll for window count updates during onboarding
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                WorkspaceMap.shared.refreshAll()
                OnboardingState.shared.updateWindowCount(WorkspaceMap.shared.windows.count)
            }
        }
    }

    /// Hide without saving layout (for onboarding)
    func hidePassive() {
        guard isVisible else { return }
        yokeLog("panel: hidePassive")
        isVisible = false
        panel?.orderOut(nil)
        TapeState.shared.stop()
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func centerOnScreen() {
        guard let panel else { return }
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let size = panel.frame.size
            let x = screenFrame.midX - size.width / 2
            let y = screenFrame.minY + 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func hide() {
        guard isVisible else { return }
        yokeLog("panel: hide")
        isVisible = false
        yokeSetPanelVisible(false)
        if let tap = blockTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = blockTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        panel?.orderOut(nil)
        removeFocusBorder()
        TapeState.shared.stop()
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
