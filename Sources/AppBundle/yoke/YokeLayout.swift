import AppKit
import Foundation

// MARK: - Layout snapshot

struct WindowSnapshot: Codable {
    let windowId: UInt32
    let appBundleId: String
    let appName: String
    let windowTitle: String
    let workspace: String
    let isFloating: Bool
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct LayoutSnapshot: Codable {
    let timestamp: Date
    let windows: [WindowSnapshot]
}

// MARK: - Save / Restore

private let layoutPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/yoke/layout.json")

@MainActor
func saveLayout() {
    var snapshots: [WindowSnapshot] = []

    for workspace in Workspace.all {
        for window in workspace.allLeafWindowsRecursive {
            guard let macWin = window as? MacWindow else { continue }

            let appBundleId = macWin.app.rawAppBundleId ?? ""
            let appName = macWin.app.name ?? ""
            let isFloating = window.isFloating

            // Get frame from CGWindowList (sync, no async needed)
            var frame = CGRect.zero
            if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] {
                for w in windowList {
                    guard let wid = w[kCGWindowNumber as String] as? UInt32,
                          wid == window.windowId,
                          let bounds = w[kCGWindowBounds as String] as? [String: CGFloat],
                          let wx = bounds["X"], let wy = bounds["Y"],
                          let ww = bounds["Width"], let wh = bounds["Height"]
                    else { continue }
                    frame = CGRect(x: wx, y: wy, width: ww, height: wh)
                    break
                }
            }

            snapshots.append(WindowSnapshot(
                windowId: window.windowId,
                appBundleId: appBundleId,
                appName: appName,
                windowTitle: "",
                workspace: workspace.name,
                isFloating: isFloating,
                x: frame.origin.x,
                y: frame.origin.y,
                width: frame.size.width,
                height: frame.size.height
            ))
        }
    }

    let snapshot = LayoutSnapshot(timestamp: Date(), windows: snapshots)

    do {
        let dir = layoutPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: layoutPath)
        yokeLog("saved layout: \(snapshots.count) windows")
    } catch {
        yokeLog("save layout error: \(error)")
    }
}

@MainActor
func restoreLayout() async {
    guard FileManager.default.fileExists(atPath: layoutPath.path) else {
        yokeLog("no saved layout found")
        return
    }

    let snapshot: LayoutSnapshot
    do {
        let data = try Data(contentsOf: layoutPath)
        snapshot = try JSONDecoder().decode(LayoutSnapshot.self, from: data)
    } catch {
        yokeLog("restore layout error: \(error)")
        return
    }

    yokeLog("restoring layout: \(snapshot.windows.count) saved windows")

    // Build lookup of current windows by ID and by app+title
    var currentWindowsById: [UInt32: Window] = [:]
    var currentWindowsByApp: [String: [Window]] = [:]

    for workspace in Workspace.all {
        for window in workspace.allLeafWindowsRecursive {
            currentWindowsById[window.windowId] = window
            let key = (window as? MacWindow)?.app.rawAppBundleId ?? ""
            currentWindowsByApp[key, default: []].append(window)
        }
    }

    var matched = 0
    var usedWindowIds = Set<UInt32>()

    for saved in snapshot.windows {
        // Try exact ID match first
        var window = currentWindowsById[saved.windowId]

        // Fall back to app bundle ID match (for cross-session restore)
        if window == nil {
            if let candidates = currentWindowsByApp[saved.appBundleId] {
                window = candidates.first { !usedWindowIds.contains($0.windowId) }
            }
        }

        guard let window else { continue }
        usedWindowIds.insert(window.windowId)

        let env = CmdEnv(windowId: window.windowId, workspaceName: nil)

        // Move to correct workspace
        let targetWs = Workspace.get(byName: saved.workspace)
        if window.nodeWorkspace != targetWs {
            if case .cmd(let cmd) = parseCommand("move-node-to-workspace \(saved.workspace)") {
                _ = try? await cmd.run(env, CmdIo(stdin: .emptyStdin))
            }
        }

        // Restore floating/tiling state
        let currentlyFloating = window.isFloating
        if saved.isFloating && !currentlyFloating {
            if case .cmd(let cmd) = parseCommand("layout floating") {
                _ = try? await cmd.run(env, CmdIo(stdin: .emptyStdin))
            }
        } else if !saved.isFloating && currentlyFloating {
            if case .cmd(let cmd) = parseCommand("layout tiling") {
                _ = try? await cmd.run(env, CmdIo(stdin: .emptyStdin))
            }
        }

        // Restore position/size for floating windows
        if saved.isFloating, saved.width > 0, saved.height > 0,
           let macWin = window as? MacWindow {
            let point = CGPoint(x: saved.x, y: saved.y)
            let size = CGSize(width: saved.width, height: saved.height)
            macWin.setAxFrame(point, size)
        }

        matched += 1
    }

    // Refresh layout after all changes
    refreshModel()
    updateTrayText()

    yokeLog("restored \(matched) of \(snapshot.windows.count) saved windows")
}
