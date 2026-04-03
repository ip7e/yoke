import SwiftUI

// MARK: - Hover helper

struct HoverView<Content: View>: View {
    @State private var hovered = false
    let content: (Bool) -> Content

    var body: some View {
        content(hovered)
            .onHover { hovered = $0 }
    }
}

// MARK: - Teenage Engineering Skin (OP-1 Field)

struct TESkin: YokeSkin {
    var borderConfig: BorderConfig {
        BorderConfig(
            color: (r: 0.20, g: 0.80, b: 0.90, a: 0.7),
            glowColor: (r: 0.20, g: 0.80, b: 0.90, a: 0.35),
            glowRadius: 14,
            strokeWidth: 4,
            padding: -8,
            cornerRadius: 14
        )
    }

    func makeView(keys: KeyState) -> AnyView {
        AnyView(TEView(keys: keys))
    }
}

// MARK: - Figma-exact colors

private struct TE {
    // Body: Figma gradient rgb(226,226,226) → rgb(176,176,176)
    static let bodyLight = Color(white: 0.886)
    static let bodyDark  = Color(white: 0.690)
    // Body border: Figma #BFBFBF
    static let bodyBorder = Color(white: 0.749)
    // Shelf: Figma #15191D
    static let shelf = Color(red: 0.082, green: 0.098, blue: 0.114)
    // Panel: Figma #F6F3F2
    static let panel = Color(red: 0.965, green: 0.953, blue: 0.949)
    // Shadow: Figma rgba(178,168,165,0.5)
    static let shadowWarm = Color(red: 0.698, green: 0.659, blue: 0.647)
    // Icon: Figma #3C444A
    static let icon = Color(red: 0.235, green: 0.267, blue: 0.290)
    // Cap
    static let capDark = Color(red: 0.10, green: 0.10, blue: 0.16)
}

// MARK: - Grid constants

private let unit: CGFloat = 40
private let gap: CGFloat = 3
private let u1 = unit              // 40
private let u2 = unit * 2 + gap   // 83
private let u3 = unit * 3 + gap * 2 // 126

// MARK: - OP-1 View

// MARK: - Tape animation state

@MainActor
private class TapeState: ObservableObject {
    static let shared = TapeState()
    @Published var angle: Double = 0
    @Published var ticks: Int = 0
    var timer: Timer?

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.angle += 3
                self?.ticks += 1
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

private struct TEView: View {
    @ObservedObject var keys: KeyState
    @ObservedObject var tape = TapeState.shared
    @ObservedObject var workspace = WorkspaceMap.shared

    var actionName: String {
        switch keys.pressedKey {
        case "W": return "FOCUS ↑"
        case "A": return "FOCUS ←"
        case "S": return "FOCUS ↓"
        case "D": return "FOCUS →"
        case "Q": return "SIZE −"
        case "E": return "SIZE +"
        case "⌥W": return "MOVE ↑"
        case "⌥A": return "MOVE ←"
        case "⌥S": return "MOVE ↓"
        case "⌥D": return "MOVE →"
        case "⇧W": return "MRG ↑"
        case "⇧A": return "MRG ←"
        case "⇧S": return "MRG ↓"
        case "⇧D": return "MRG →"
        case "⇧Q": return "SIZE −"
        case "⇧E": return "SIZE +"
        case "T": return "TILES"
        case "Y": return "ACCORD"
        case "F": return "FLOAT"
        case "1", "2", "3", "4", "5", "6", "7", "8", "9":
            return "WS \(keys.pressedKey!)"
        case "⌥1", "⌥2", "⌥3", "⌥4", "⌥5", "⌥6", "⌥7", "⌥8", "⌥9",
             "⇧1", "⇧2", "⇧3", "⇧4", "⇧5", "⇧6", "⇧7", "⇧8", "⇧9":
            let n = keys.pressedKey!.dropFirst()
            return "→ WS \(n)"
        default: return "READY"
        }
    }

    var body: some View {
        ZStack {
            // ── Gray metallic body ──
            // Figma: gradient 110° from #E2E2E2 → #B0B0B0
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [TE.bodyLight, TE.bodyDark],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

            // Figma: border 2px #BFBFBF
            RoundedRectangle(cornerRadius: 10)
                .stroke(TE.bodyBorder, lineWidth: 1)

            // Figma body inner shadows: inset 2px 2px 1px white 60%, inset -2px -2px 1px black 40%
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.white, lineWidth: 1.5)
                .blur(radius: 0.5)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .offset(x: 0.5, y: 0.5)
                .opacity(0.4)

            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.black, lineWidth: 1)
                .blur(radius: 0.5)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .offset(x: -0.5, y: -0.5)
                .opacity(0.2)

            // ── Dark shelf ── Figma: #15191D, rounded 8px
            // body padding = 6, shelf inset from body = gap(3) → shelf padding = 6 + 3 = 9
            RoundedRectangle(cornerRadius: 5)
                .fill(TE.shelf)
                .padding(6)

            // ── Module grid ──
            HStack(spacing: gap) {
                knobModule()
                    .frame(width: u2, height: u2)

                screenModule()
                    .frame(width: u3, height: u2)

                VStack(spacing: gap) {
                    btnSquare("+", shortcut: "E", label: "E", modifierLit: keys.shiftHeld)
                    btnSquare("−", shortcut: "Q", label: "Q", modifierLit: keys.shiftHeld)
                }
                .frame(width: u1)

                btnPanel("⬡", shortcut: "F", label: "FLOAT")
                btnPanel("⧉", shortcut: "R", label: "LYOUT", modifierLit: keys.shiftHeld)

                btnPanel("?", shortcut: "H", label: "HELP")
            }
            // gap from shelf edge to modules = same as gap between modules
            .padding(6 + gap)
        }
        .frame(height: u2 + (6 + gap) * 2)
        .padding(6)
        .onAppear { tape.start() }
    }

    func helpLine(_ key: String, _ desc: String) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 1, green: 0.42, blue: 0).opacity(0.85))
                .frame(width: 48, alignment: .trailing)
            Text(desc)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.50))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
    }

    func helpLineNarrow(_ key: String, _ desc: String) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 1, green: 0.42, blue: 0).opacity(0.85))
                .frame(width: 28, alignment: .trailing)
            Text(desc)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.50))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
    }

    /// OP-1 style: KEY  LABEL  hint
    func helpOp1(_ key: String, _ label: String, _ hint: String) -> some View {
        HStack(spacing: 0) {
            Text(key)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 32, alignment: .trailing)
            Text(" ")
                .frame(width: 4)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 1, green: 0.42, blue: 0).opacity(0.9))
                .frame(width: 40, alignment: .leading)
            Text(hint)
                .font(.system(size: 6, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Panel base (Figma: #F6F3F2, rounded 5, inset shadows)

    func panelBase() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(TE.panel)

            // Figma: inset 0 1.5px 1px white top
            VStack {
                Color.white.frame(height: 1).blur(radius: 0.3)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .opacity(0.5)

            // Figma: inset 0 -1.5px 0.5px rgba(178,168,165,0.5) bottom
            VStack {
                Spacer()
                TE.shadowWarm.frame(height: 0.5).blur(radius: 0.2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .opacity(0.35)
        }
    }

    // MARK: - Knob Module (2×2)

    func knobModule() -> some View {
        let bodySz: CGFloat = u2 * 0.56
        let holeSz: CGFloat = u2 * 0.60
        let capBSz: CGFloat = u2 * 0.33
        let capSz: CGFloat  = u2 * 0.26

        let dx: CGFloat = keys.pressedKey == "D" ? 2 : keys.pressedKey == "A" ? -2 : 0
        let dy: CGFloat = keys.pressedKey == "S" ? 2 : keys.pressedKey == "W" ? -2 : 0
        let tilted = dx != 0 || dy != 0

        return ZStack {
            panelBase()

            // Hole ring
            Circle()
                .stroke(Color(white: 0.62).opacity(0.4), lineWidth: 0.8)
                .frame(width: holeSz, height: holeSz)

            // Knob body — shadow shifts with tilt (tall stick, light from top-left)
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(white: 0.97), location: 0.0),
                            .init(color: Color(white: 0.91), location: 0.75),
                            .init(color: Color(white: 0.85), location: 1.0),
                        ],
                        center: .init(x: 0.45, y: 0.42),
                        startRadius: 0, endRadius: bodySz * 0.52
                    )
                )
                .frame(width: bodySz, height: bodySz)

            // Stick shadow — far light source from top-left, always diagonal bottom-right
            // Tilt changes length, not direction
            let stickHeight: CGFloat = tilted ? 20 : 14
            let shAngle = Angle.degrees(40) // fixed diagonal

            Ellipse()
                .fill(Color.black.opacity(0.50))
                .frame(width: stickHeight * 1.3, height: capSz * 0.55)
                .rotationEffect(shAngle)
                .offset(x: 12 + dx * 0.5, y: 12 + dy * 0.5)
                .blur(radius: 6)

            // Cap shadow
            Ellipse()
                .fill(Color.black.opacity(0.10))
                .frame(width: capBSz * 0.8, height: capBSz * 0.45)
                .offset(x: 0.5 + dx * 0.15, y: capBSz * 0.3 + dy * 0.15)
                .blur(radius: 1.5)

            // Cap base
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.90), Color(white: 0.80)],
                        center: .init(x: 0.42, y: 0.38),
                        startRadius: 0, endRadius: capBSz * 0.48
                    )
                )
                .frame(width: capBSz, height: capBSz)
                .offset(x: dx * 0.1, y: dy * 0.1)

            // Color cap (dark navy)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.14, green: 0.14, blue: 0.20), TE.capDark],
                        center: .init(x: 0.42, y: 0.36),
                        startRadius: 0, endRadius: capSz * 0.48
                    )
                )
                .frame(width: capSz, height: capSz)
                .offset(x: dx, y: dy)

            // Highlight
            Ellipse()
                .fill(Color.white.opacity(tilted ? 0.03 : 0.14))
                .frame(width: capSz * 0.5, height: capSz * 0.22)
                .offset(x: dx - 0.5, y: dy - capSz * 0.12)

            // LED: top-right = green (move/alt)
            let ledSz: CGFloat = 3.5
            let ledOff: CGFloat = u2 / 2 - 7
            ZStack {
                if keys.altHeld {
                    Circle().fill(Color.green.opacity(0.4)).frame(width: ledSz + 4, height: ledSz + 4).blur(radius: 3)
                }
                Circle().fill(keys.altHeld ? Color.green : Color(white: 0.28)).frame(width: ledSz, height: ledSz)
            }
            .offset(x: ledOff, y: -ledOff)

            // LED: bottom-right = orange (merge/shift)
            ZStack {
                if keys.shiftHeld {
                    Circle().fill(Color(red: 1, green: 0.42, blue: 0).opacity(0.4)).frame(width: ledSz + 4, height: ledSz + 4).blur(radius: 3)
                }
                Circle().fill(keys.shiftHeld ? Color(red: 1, green: 0.42, blue: 0) : Color(white: 0.28)).frame(width: ledSz, height: ledSz)
            }
            .offset(x: ledOff, y: ledOff)
        }
        .animation(.easeOut(duration: 0.08), value: keys.pressedKey)
    }

    // MARK: - Screen Module (3×2)

    func screenModule() -> some View {
        ZStack {
            // Screen background — tints when modifier active
            let modColor: Color? = keys.altHeld ? .green : keys.shiftHeld ? Color(red: 1, green: 0.42, blue: 0) : nil

            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: modColor != nil
                            ? [modColor!.opacity(0.35), modColor!.opacity(0.25)]
                            : [Color(white: 0.22), Color(white: 0.05)],
                        startPoint: modColor != nil ? .top : .topLeading,
                        endPoint: modColor != nil ? .bottom : .bottomTrailing
                    )
                )

            // Inner border tints too
            RoundedRectangle(cornerRadius: 4)
                .stroke(modColor?.opacity(0.4) ?? Color(white: 0.25), lineWidth: 1)

            // Screen content
            if keys.helpPage > 0 {
                VStack(spacing: 0) {
                    // Page header
                    HStack {
                        Text("HELP \(keys.helpPage)/5")
                            .font(.system(size: 6, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Text("H next")
                            .font(.system(size: 5, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)

                    Spacer()

                    Group {
                        if keys.helpPage == 1 {
                            // Navigate
                            VStack(spacing: 3) {
                                helpLine("WASD", "FOCUS")
                                helpLine("⌥ WASD", "MOVE")
                                helpLine("⇧ WASD", "MERGE")
                            }
                        } else if keys.helpPage == 2 {
                            // Workspace
                            VStack(spacing: 2) {
                                helpLine("1-9", "WORKSPACE")
                                helpLine("⌥ 1-9", "SEND TO")
                                Text("WORKSPACE")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.50))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 60)
                            }
                        } else if keys.helpPage == 3 {
                            // Resize
                            VStack(spacing: 3) {
                                helpLine("E/Q", "RESIZE")
                                helpLine("⇧ E/Q", "FINE RESIZE")
                            }
                        } else if keys.helpPage == 4 {
                            // Layout
                            VStack(spacing: 3) {
                                helpLineNarrow("F", "FLOAT ON/OFF")
                                helpLineNarrow("R", "TILE / STACK")
                                helpLineNarrow("⇧ R", "ORIENTATION")
                            }
                        } else if keys.helpPage == 5 {
                            // Meta
                            VStack(spacing: 3) {
                                helpLine("⌘ ESC", "OPEN YOKE")
                                helpLine("ESC ↵", "CLOSE YOKE")
                                helpLine("H", "HELP")
                            }
                        } else {
                            VStack(spacing: 4) {
                                Text("YOKE")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("made by Ika")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("www.ika.im")
                                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                                    .foregroundColor(Color(red: 1, green: 0.42, blue: 0).opacity(0.7))
                            }
                        }
                    }

                    Spacer()
                }
            }

            if keys.helpPage == 0 {
            // Retro workspace map
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let pad: CGFloat = 5
                let mapPad: CGFloat = 12
                let bottomPad: CGFloat = 10 // reserved for workspace bar
                let scr = workspace.screenSize
                let mapW = w - pad * 2
                let mapH = h - pad * 2 - mapPad - bottomPad
                let scale = min(mapW / max(scr.width, 1), mapH / max(scr.height, 1))
                let offX = pad + (mapW - scr.width * scale) / 2
                let offY = pad + mapPad + (mapH - scr.height * scale) / 2

                // 8-bit palette for windows
                let palette: [Color] = [
                    Color(red: 0.20, green: 0.80, blue: 0.90), // cyan
                    Color(red: 1.00, green: 0.85, blue: 0.15), // yellow
                    Color(red: 0.20, green: 0.85, blue: 0.30), // green
                    Color(red: 1.00, green: 0.45, blue: 0.20), // orange
                    Color(red: 0.70, green: 0.40, blue: 1.00), // purple
                    Color(red: 1.00, green: 0.30, blue: 0.40), // red
                    Color(red: 0.30, green: 0.60, blue: 1.00), // blue
                    Color(red: 1.00, green: 0.55, blue: 0.70), // pink
                ]

                Canvas { ctx, size in
                    // ── Header — shows mode when modifier held, otherwise YOKE + WIN ──
                    if keys.altHeld || keys.shiftHeld {
                        let mLabel = keys.altHeld ? "MOVE" : "MERGE"
                        let mColor = keys.altHeld ? Color.green : Color(red: 1, green: 0.42, blue: 0)
                        ctx.draw(
                            Text("▸ \(mLabel)").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundColor(mColor.opacity(0.85)),
                            at: CGPoint(x: w / 2, y: pad + 5)
                        )
                    } else {
                        ctx.draw(
                            Text("YOKE").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.5)),
                            at: CGPoint(x: pad + 14, y: pad + 5)
                        )
                        let n = workspace.windows.count
                        ctx.draw(
                            Text("\(n) WIN").font(.system(size: 6, weight: .medium, design: .monospaced)).foregroundColor(.white.opacity(0.3)),
                            at: CGPoint(x: w - pad - 14, y: pad + 5)
                        )
                    }

                    // ── Map area (between header and workspace bar) ──
                    if keys.errorFlash {
                        // Error: centered text, no windows
                        let mapMidY = offY + (h - pad - bottomPad - 4 - offY) / 2
                        ctx.draw(
                            Text("ERR WRONG KEY").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.red.opacity(0.8)),
                            at: CGPoint(x: w / 2, y: mapMidY)
                        )
                    } else {
                        // ── Screen outline ──
                        let screenRect = CGRect(x: offX, y: offY, width: scr.width * scale, height: scr.height * scale)
                        ctx.stroke(Path(roundedRect: screenRect, cornerSize: CGSize(width: 1, height: 1)), with: .color(.white.opacity(0.08)), lineWidth: 0.5)

                        // ── Window blocks (inset for gaps) ──
                        let inset: CGFloat = 1.5
                        for (i, win) in workspace.windows.enumerated() {
                            let bx = offX + win.frame.origin.x * scale + inset
                            let by = offY + win.frame.origin.y * scale + inset
                            let bw = max(win.frame.width * scale - inset * 2, 3)
                            let bh = max(win.frame.height * scale - inset * 2, 3)
                            let rect = CGRect(x: bx, y: by, width: bw, height: bh)
                            let cr = CGSize(width: 1.5, height: 1.5)
                            let inMode = keys.altHeld || keys.shiftHeld
                            let modeCol: Color = keys.altHeld ? .green : Color(red: 1, green: 0.42, blue: 0)
                            let color = inMode
                                ? (win.isFocused ? modeCol : Color.white)
                                : palette[Int(win.windowId) % palette.count]

                            // Windows
                            ctx.fill(Path(roundedRect: rect, cornerSize: cr), with: .color(color.opacity(win.isFocused ? 0.30 : (inMode ? 0.06 : 0.12))))
                            if win.isFloating {
                                let dash: [CGFloat] = [3, 2]
                                var dashedPath = Path(roundedRect: rect, cornerSize: cr)
                                ctx.stroke(dashedPath, with: .color(color.opacity(win.isFocused ? 0.9 : (inMode ? 0.15 : 0.35))), style: StrokeStyle(lineWidth: win.isFocused ? 1.2 : 0.5, dash: dash))
                            } else {
                                ctx.stroke(Path(roundedRect: rect, cornerSize: cr), with: .color(color.opacity(win.isFocused ? 0.9 : (inMode ? 0.15 : 0.35))), lineWidth: win.isFocused ? 1.2 : 0.5)
                            }

                            if win.isFocused {
                                let scanSpeed = inMode ? 20 : 60
                                let scanY = by + bh * (Double(tape.ticks % scanSpeed) / Double(scanSpeed))
                                var scanLine = Path()
                                scanLine.move(to: CGPoint(x: bx + 1, y: scanY))
                                scanLine.addLine(to: CGPoint(x: bx + bw - 1, y: scanY))
                                ctx.stroke(scanLine, with: .color(color.opacity(0.5)), lineWidth: 0.5)
                            }
                        }

                        // ── Action text ──
                        if keys.pressedKey != nil {
                            ctx.draw(
                                Text("▸ \(actionName)").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.7)),
                                at: CGPoint(x: w / 2, y: h - pad - 8)
                            )
                        }
                    }

                    // ── Workspace status bar ──
                    let wsY = h - pad - 1.5
                    let wsSpacing: CGFloat = 11
                    let wsStart = w / 2 - wsSpacing * 4
                    let modHeld = keys.altHeld
                    for i in 1...9 {
                        let label = "\(i)"
                        let isActive = workspace.activeWorkspace == label
                        let isOccupied = workspace.occupiedWorkspaces.contains(label)
                        let x = wsStart + wsSpacing * CGFloat(i - 1)

                        if isActive {
                            // Active: bright accent
                            ctx.draw(
                                Text(label).font(.system(size: 7, weight: .black, design: .monospaced))
                                    .foregroundColor(Color(red: 0.20, green: 0.80, blue: 0.90)),
                                at: CGPoint(x: x, y: wsY)
                            )
                        } else if modHeld {
                            // Modifier held: orange — "you can move here"
                            ctx.draw(
                                Text(label).font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color.green.opacity(0.7)),
                                at: CGPoint(x: x, y: wsY)
                            )
                        } else if isOccupied {
                            // Occupied: dim white
                            ctx.draw(
                                Text(label).font(.system(size: 7, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.35)),
                                at: CGPoint(x: x, y: wsY)
                            )
                        } else {
                            // Empty: barely visible
                            ctx.draw(
                                Text(label).font(.system(size: 7, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.10)),
                                at: CGPoint(x: x, y: wsY)
                            )
                        }
                    }
                }
            }
            } // end if helpPage == 0

            // Subtle glass highlight (only in normal mode)
            if !keys.altHeld && !keys.shiftHeld && keys.helpPage == 0 {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.06), location: 0.0),
                                .init(color: Color.clear, location: 0.35),
                            ],
                            startPoint: .topLeading, endPoint: .center
                        )
                    )
            }
        }
    }

    // MARK: - Button Panel (1×2 vertical — neumorphic dome in top, label in bottom)

    func btnPanel(_ icon: String, shortcut: String, label: String, modifierLit: Bool = false) -> some View {
        let domeSz: CGFloat = u1 * 0.75
        let pressed = keys.pressedKey == shortcut || keys.pressedKey == "⇧\(shortcut)"
        let lit = shortcut == "H" ? keys.helpPage > 0 : (pressed || modifierLit)

        return HoverView { hovered in ZStack {
            // Module shadow (disappears when pushed)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(pressed ? 0.0 : 0.10))
                .offset(y: pressed ? 0 : 1)
                .blur(radius: pressed ? 0 : 0.8)

            // Entire module — sinks on press
            ZStack {
                panelBase()

                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(TE.panel)
                            .frame(width: domeSz, height: domeSz)
                            .shadow(color: Color.black.opacity(0.18), radius: 3, x: 1.5, y: 1.5)
                            .shadow(color: Color.white.opacity(0.8), radius: 2, x: -1, y: -1)

                        Circle()
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.6), location: 0.0),
                                        .init(color: Color.clear, location: 0.4),
                                        .init(color: Color.black.opacity(0.06), location: 0.8),
                                    ],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .frame(width: domeSz, height: domeSz)

                        Text(hovered ? shortcut : icon)
                            .font(.system(size: hovered ? 9 : 12, weight: hovered ? .bold : .regular, design: hovered ? .monospaced : .default))
                            .foregroundColor(
                                modifierLit && !pressed
                                    ? Color(red: 1.0, green: 0.42, blue: 0.0)
                                    : (lit ? Color(red: 1.0, green: 0.42, blue: 0.0) : TE.icon)
                            )
                            .animation(.easeInOut(duration: 0.1), value: hovered)
                    }
                    .frame(height: u1)

                    Text(label)
                        .font(.system(size: 6, weight: .bold, design: .monospaced))
                        .foregroundColor(TE.icon.opacity(0.35))
                        .frame(height: u1)
                }
            }
            .offset(y: pressed ? 1 : 0)
            .animation(.easeOut(duration: 0.05), value: pressed)
        }
        .frame(width: u1, height: u2)
        }
    }

    // MARK: - Small square button (1×1 — dome + label combined)

    func btnSquare(_ icon: String, shortcut: String, label: String, modifierLit: Bool = false) -> some View {
        let domeSz: CGFloat = u1 * 0.75
        let pressed = keys.pressedKey == shortcut || keys.pressedKey == "⇧\(shortcut)"
        let lit = pressed || modifierLit

        return HoverView { hovered in ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(pressed ? 0.0 : 0.10))
                .offset(y: pressed ? 0 : 1)
                .blur(radius: pressed ? 0 : 0.8)

            ZStack {
                panelBase()

                ZStack {
                    Circle()
                        .fill(TE.panel)
                        .frame(width: domeSz, height: domeSz)
                        .shadow(color: Color.black.opacity(0.18), radius: 3, x: 1.5, y: 1.5)
                        .shadow(color: Color.white.opacity(0.8), radius: 2, x: -1, y: -1)

                    Circle()
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.6), location: 0.0),
                                    .init(color: Color.clear, location: 0.4),
                                    .init(color: Color.black.opacity(0.06), location: 0.8),
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: domeSz, height: domeSz)

                    Text(hovered ? label : icon)
                        .font(.system(size: hovered ? 9 : 12, weight: hovered ? .bold : .regular, design: hovered ? .monospaced : .default))
                        .foregroundColor(
                            modifierLit && !pressed
                                ? Color(red: 1.0, green: 0.42, blue: 0.0)
                                : (lit ? Color(red: 1.0, green: 0.42, blue: 0.0) : TE.icon)
                        )
                        .animation(.easeInOut(duration: 0.1), value: hovered)
                }
            }
            .offset(y: pressed ? 1 : 0)
            .animation(.easeOut(duration: 0.05), value: pressed)
        }
        .frame(width: u1, height: u1)
        }
    }

}
