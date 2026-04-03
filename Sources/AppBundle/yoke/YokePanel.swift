import AppKit
import SwiftUI

@MainActor
final class YokePanel {
    static let shared = YokePanel()
    private var panel: NSPanel?
    private(set) var isVisible = false
    private var pollTimer: Timer?
    var blockTap: CFMachPort?

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

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let size = panel.frame.size
            let x = screenFrame.midX - size.width / 2
            let y = screenFrame.minY + 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
        yokePanelVisible = true
        if let tap = blockTap { CGEvent.tapEnable(tap: tap, enable: true) }
        yokeRefreshUI()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                yokeRefreshUI()
            }
        }
    }

    func hide() {
        guard isVisible else { return }
        yokeLog("panel: hide")
        saveLayout()
        isVisible = false
        yokePanelVisible = false
        if let tap = blockTap { CGEvent.tapEnable(tap: tap, enable: false) }
        panel?.orderOut(nil)
        removeFocusBorder()
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
