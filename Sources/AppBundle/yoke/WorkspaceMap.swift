import AppKit
import SwiftUI

struct WindowInfo {
    let frame: CGRect
    let isFocused: Bool
}

@MainActor
class WorkspaceMap: ObservableObject {
    static let shared = WorkspaceMap()
    @Published var windows: [WindowInfo] = []
    @Published var screenSize: CGSize = CGSize(width: 1920, height: 1080)
    @Published var activeWorkspace: String = ""
    @Published var occupiedWorkspaces: Set<String> = []

    func refreshAll() {
        // Direct AeroSpace API — no process spawning
        activeWorkspace = focus.workspace.name
        occupiedWorkspaces = Set(
            Workspace.all
                .filter { !$0.isEffectivelyEmpty }
                .map { $0.name }
        )

        guard let screen = NSScreen.main else { return }
        screenSize = screen.frame.size

        let focusedWin = focus.windowOrNil
        let currentWorkspace = focus.workspace

        var result: [WindowInfo] = []
        for window in currentWorkspace.allLeafWindowsRecursive {
            if let rect = window.lastAppliedLayoutPhysicalRect {
                let frame = CGRect(
                    x: CGFloat(rect.topLeftX),
                    y: CGFloat(rect.topLeftY),
                    width: CGFloat(rect.width),
                    height: CGFloat(rect.height)
                )
                result.append(WindowInfo(
                    frame: frame,
                    isFocused: window == focusedWin
                ))
            }
        }
        windows = result
    }
}
