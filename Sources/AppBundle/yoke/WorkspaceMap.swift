import AppKit
import PrivateApi
import SwiftUI

struct WindowInfo {
    let frame: CGRect
    let isFocused: Bool
    let windowId: UInt32
    let isFloating: Bool
}

@MainActor
class WorkspaceMap: ObservableObject {
    static let shared = WorkspaceMap()
    @Published var windows: [WindowInfo] = []
    @Published var screenSize: CGSize = CGSize(width: 1920, height: 1080)
    @Published var activeWorkspace: String = ""
    @Published var occupiedWorkspaces: Set<String> = []

    func refreshAll() {
        activeWorkspace = focus.workspace.name
        occupiedWorkspaces = Set(
            Workspace.all
                .filter { !$0.isEffectivelyEmpty }
                .map { $0.name }
        )

        guard let screen = NSScreen.main else { return }
        screenSize = screen.frame.size

        // Get window IDs on current workspace from the tree
        let currentWorkspace = focus.workspace
        let focusedWin = focus.windowOrNil
        let allWindows = currentWorkspace.allLeafWindowsRecursive
        let wsWindowIds = Set(allWindows.map { $0.windowId })
        let floatingIds = Set(allWindows.filter { $0.isFloating }.map { $0.windowId })
        let focusedId = focusedWin?.windowId ?? 0

        // Get frames from CGWindowList (fast, no async)
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }

        var result: [WindowInfo] = []
        for w in windowList {
            guard let bounds = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"],
                  let width = bounds["Width"], let height = bounds["Height"],
                  let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                  width > 50, height > 50
            else { continue }

            let wid = w[kCGWindowNumber as String] as? UInt32 ?? 0
            guard wsWindowIds.contains(wid) else { continue }

            let frame = CGRect(x: x, y: y, width: width, height: height)
            result.append(WindowInfo(frame: frame, isFocused: wid == focusedId, windowId: wid, isFloating: floatingIds.contains(wid)))
        }
        windows = result
    }
}
