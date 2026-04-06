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
