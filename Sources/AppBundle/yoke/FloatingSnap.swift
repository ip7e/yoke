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
    enum Direction { case left, right, up, down, center }

    private var edge: Edge = .none
    private var hFraction: HFraction = .half
    private var vertical: Vertical = .full
    private var centered: Bool = false
    private var centerWide: Bool = true
    private var trackedWindowId: UInt32?

    private init() {}

    // MARK: - Public API

    func snap(_ dir: Direction) {
        guard let (macWin, windowId) = floatingWindow() else { return }
        if trackedWindowId != windowId {
            edge = .none; hFraction = .half; vertical = .full
            centered = false; centerWide = true
        }
        trackedWindowId = windowId

        switch dir {
        case .left:  centered = false; snapHorizontal(to: .left)
        case .right: centered = false; snapHorizontal(to: .right)
        case .up:    centered = false; snapVertical(to: .top)
        case .down:  centered = false; snapVertical(to: .bottom)
        case .center: snapCenter()
        }

        if centered {
            applyCenterFrame(macWin)
        } else {
            applyEdgeFrame(macWin)
        }
    }

    func reset() {
        edge = .none; hFraction = .half; vertical = .full
        centered = false; centerWide = true; trackedWindowId = nil
    }

    // MARK: - State transitions

    private func snapHorizontal(to target: Edge) {
        if edge == target {
            if vertical != .full {
                vertical = .full
            } else {
                hFraction = hFraction == .half ? .third : .half
            }
        } else {
            if edge == .none { hFraction = .half }
            edge = target
        }
    }

    private func snapVertical(to target: Vertical) {
        if vertical == target {
            edge = .none; hFraction = .full
        } else {
            if edge == .none { hFraction = .full }
        }
        vertical = target
    }

    private func snapCenter() {
        if centered {
            centerWide.toggle()
        } else {
            centered = true; centerWide = true
        }
        edge = .none; vertical = .full; hFraction = .full
    }

    // MARK: - Frame application

    private func floatingWindow() -> (MacWindow, UInt32)? {
        guard let window = focus.windowOrNil, window.isFloating,
              let macWin = window as? MacWindow else { return nil }
        return (macWin, window.windowId)
    }

    private func applyEdgeFrame(_ macWin: MacWindow) {
        let s = focus.workspace.workspaceMonitor.visibleRect

        let w = s.width * hFraction.rawValue
        let h: CGFloat = vertical == .full ? s.height : s.height / 2
        let x = edge == .right ? s.topLeftX + s.width - w : s.topLeftX
        let y = vertical == .bottom ? s.topLeftY + s.height / 2 : s.topLeftY

        macWin.setAxFrame(CGPoint(x: x, y: y), CGSize(width: w, height: h))
    }

    private func applyCenterFrame(_ macWin: MacWindow) {
        let s = focus.workspace.workspaceMonitor.visibleRect

        if centerWide {
            // Full width, full height
            macWin.setAxFrame(
                CGPoint(x: s.topLeftX, y: s.topLeftY),
                CGSize(width: s.width, height: s.height)
            )
        } else {
            // Compact: 70% width, 80% height, centered
            let w = s.width * 0.7
            let h = s.height * 0.8
            let x = s.topLeftX + (s.width - w) / 2
            let y = s.topLeftY + (s.height - h) / 2
            macWin.setAxFrame(CGPoint(x: x, y: y), CGSize(width: w, height: h))
        }
    }
}
