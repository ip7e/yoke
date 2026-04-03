import AppKit
import SwiftUI

// MARK: - Aerospace mode polling

func currentMode() -> String {
    let task = Process()
    let pipe = Pipe()
    task.launchPath = "/usr/bin/env"
    task.arguments = ["aerospace", "list-modes", "--current"]
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice
    do { try task.run() } catch { return "" }
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

// MARK: - Shortcut labels

let shortcuts: [String: String] = [
    "focus up": "W", "focus left": "A", "focus down": "S", "focus right": "D",
    "layout tiles": "T", "layout accordion": "Y", "layout float": "F",
    "join-with left": "⇧A", "join-with right": "⇧D",
]

// MARK: - Joystick View

struct YokeView: View {
    var body: some View {
        HStack(spacing: 14) {
            dpad()

            HStack(spacing: 5) {
                actionBtn("−", "shrk", shortcut: "Q")
                actionBtn("+", "grow", shortcut: "E")
                actionBtn("⧉", "tiles", shortcut: "T")
                actionBtn("≡", "acrd", shortcut: "Y")
                actionBtn("⬡", "float", shortcut: "F")
                actionBtn("⟨", "mrg", shortcut: "⇧A")
                actionBtn("⟩", "mrg", shortcut: "⇧D")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.94), Color(white: 0.86)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                )
        )
        .padding(12)
    }

    // MARK: - D-Pad

    func dpad() -> some View {
        let sz: CGFloat = 22

        return ZStack {
            dpadBtn("chevron.up", shortcut: "W", size: sz)
                .offset(y: -sz)
            dpadBtn("chevron.down", shortcut: "S", size: sz)
                .offset(y: sz)
            dpadBtn("chevron.left", shortcut: "A", size: sz)
                .offset(x: -sz)
            dpadBtn("chevron.right", shortcut: "D", size: sz)
                .offset(x: sz)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.78), Color(white: 0.72)],
                        center: .center, startRadius: 0, endRadius: sz * 0.3
                    )
                )
                .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                .frame(width: sz * 0.55, height: sz * 0.55)
        }
        .frame(width: sz * 3.2, height: sz * 3.2)
    }

    func dpadBtn(_ icon: String, shortcut: String, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.95), Color(white: 0.82)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 0.5)
                )
                .frame(width: size, height: size)
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(Color(white: 0.35))
                Text(shortcut)
                    .font(.system(size: 5, weight: .medium))
                    .foregroundColor(Color(white: 0.5))
            }
        }
    }

    // MARK: - Action buttons

    func actionBtn(_ icon: String, _ label: String, shortcut: String) -> some View {
        VStack(spacing: 2) {
            Text(icon)
                .font(.system(size: 13))
            Text(label)
                .font(.system(size: 7, weight: .semibold, design: .monospaced))
            Text(shortcut)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(Color(white: 0.55))
        }
        .foregroundColor(Color(white: 0.3))
        .frame(width: 44, height: 62)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.68))
                    .offset(y: 2.5)
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.97), Color(white: 0.85)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.8), Color.white.opacity(0.1)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
        )
    }
}

// MARK: - Floating panel

class YokePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - App delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: YokePanel!
    var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let content = NSHostingView(rootView: YokeView())
        content.setFrameSize(content.fittingSize)

        panel = YokePanel(
            contentRect: NSRect(x: 0, y: 0, width: content.fittingSize.width, height: content.fittingSize.height),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.contentView = content
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - content.fittingSize.width / 2
            let y = screenFrame.minY + 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()

        // Auto-quit when leaving yoke mode
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            if currentMode() != "yoke" {
                NSApp.terminate(nil)
            }
        }
    }
}

// MARK: - Main

// Kill any existing yoke instance
let pid = ProcessInfo.processInfo.processIdentifier
let killTask = Process()
killTask.launchPath = "/bin/sh"
killTask.arguments = ["-c", "pgrep -f yoke-overlay/yoke | grep -v \(pid) | xargs kill 2>/dev/null"]
try? killTask.run()
killTask.waitUntilExit()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
