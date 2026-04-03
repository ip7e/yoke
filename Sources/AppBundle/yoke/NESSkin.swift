import SwiftUI

// MARK: - NES Skin

struct NESSkin: YokeSkin {
    var borderConfig: BorderConfig {
        BorderConfig(
            color: (r: 0.4, g: 0.55, b: 1.0, a: 0.5),
            glowColor: (r: 0.4, g: 0.55, b: 1.0, a: 0.35),
            glowRadius: 12,
            strokeWidth: 2,
            padding: -12,
            cornerRadius: 14
        )
    }

    func makeView(keys: KeyState) -> AnyView {
        AnyView(NESView(keys: keys))
    }
}

// MARK: - NES Color System

private struct C {
    // Body plastic — warm light gray
    static let body      = Color(red: 0.78, green: 0.76, blue: 0.73)
    static let bodyLight = Color(red: 0.84, green: 0.82, blue: 0.79)
    static let bodyDark  = Color(red: 0.70, green: 0.68, blue: 0.65)
    static let bodyEdge  = Color(red: 0.62, green: 0.60, blue: 0.57)

    // Dark panel stripe
    static let panel      = Color(red: 0.13, green: 0.13, blue: 0.14)
    static let panelLight = Color(red: 0.19, green: 0.19, blue: 0.20)

    // D-pad
    static let dpadBlack = Color(red: 0.09, green: 0.09, blue: 0.10)
    static let dpadGray  = Color(red: 0.16, green: 0.16, blue: 0.17)

    // Buttons — Nintendo red
    static let btnRed      = Color(red: 0.72, green: 0.14, blue: 0.20)
    static let btnRedLight = Color(red: 0.82, green: 0.22, blue: 0.26)
    static let btnRedDark  = Color(red: 0.48, green: 0.08, blue: 0.11)
    static let btnRedDeep  = Color(red: 0.34, green: 0.04, blue: 0.06)

    // Text
    static let textRed = Color(red: 0.62, green: 0.14, blue: 0.17)
}

// MARK: - Plastic Grain Texture

private struct PlasticGrain: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var y: CGFloat = 0.5
        while y < rect.height {
            p.addRect(CGRect(x: 0, y: y, width: rect.width, height: 0.5))
            y += 2.5
        }
        return p
    }
}

// MARK: - Cross Shape (rounded corners)

struct CrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let armW = w / 3
        let r: CGFloat = 3

        var p = Path()
        p.move(to: CGPoint(x: armW + r, y: 0))
        p.addLine(to: CGPoint(x: armW * 2 - r, y: 0))
        p.addQuadCurve(to: CGPoint(x: armW * 2, y: r), control: CGPoint(x: armW * 2, y: 0))
        p.addLine(to: CGPoint(x: armW * 2, y: armW - r))
        p.addQuadCurve(to: CGPoint(x: armW * 2 + r, y: armW), control: CGPoint(x: armW * 2, y: armW))
        p.addLine(to: CGPoint(x: w - r, y: armW))
        p.addQuadCurve(to: CGPoint(x: w, y: armW + r), control: CGPoint(x: w, y: armW))
        p.addLine(to: CGPoint(x: w, y: armW * 2 - r))
        p.addQuadCurve(to: CGPoint(x: w - r, y: armW * 2), control: CGPoint(x: w, y: armW * 2))
        p.addLine(to: CGPoint(x: armW * 2 + r, y: armW * 2))
        p.addQuadCurve(to: CGPoint(x: armW * 2, y: armW * 2 + r), control: CGPoint(x: armW * 2, y: armW * 2))
        p.addLine(to: CGPoint(x: armW * 2, y: h - r))
        p.addQuadCurve(to: CGPoint(x: armW * 2 - r, y: h), control: CGPoint(x: armW * 2, y: h))
        p.addLine(to: CGPoint(x: armW + r, y: h))
        p.addQuadCurve(to: CGPoint(x: armW, y: h - r), control: CGPoint(x: armW, y: h))
        p.addLine(to: CGPoint(x: armW, y: armW * 2 + r))
        p.addQuadCurve(to: CGPoint(x: armW - r, y: armW * 2), control: CGPoint(x: armW, y: armW * 2))
        p.addLine(to: CGPoint(x: r, y: armW * 2))
        p.addQuadCurve(to: CGPoint(x: 0, y: armW * 2 - r), control: CGPoint(x: 0, y: armW * 2))
        p.addLine(to: CGPoint(x: 0, y: armW + r))
        p.addQuadCurve(to: CGPoint(x: r, y: armW), control: CGPoint(x: 0, y: armW))
        p.addLine(to: CGPoint(x: armW - r, y: armW))
        p.addQuadCurve(to: CGPoint(x: armW, y: armW - r), control: CGPoint(x: armW, y: armW))
        p.addLine(to: CGPoint(x: armW, y: r))
        p.addQuadCurve(to: CGPoint(x: armW + r, y: 0), control: CGPoint(x: armW, y: 0))
        p.closeSubpath()
        return p
    }
}

// MARK: - NES Controller View

private struct NESView: View {
    @ObservedObject var keys: KeyState

    var body: some View {
        ZStack {
            // ── Drop shadow ──
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.35))
                .offset(y: 4)
                .blur(radius: 8)

            // ── Body: plastic shell ──
            RoundedRectangle(cornerRadius: 11)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: C.bodyLight, location: 0.0),
                            .init(color: C.body,      location: 0.35),
                            .init(color: C.bodyDark,  location: 0.85),
                            .init(color: C.bodyEdge,  location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Top edge bevel
            RoundedRectangle(cornerRadius: 11)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.50), location: 0.0),
                            .init(color: Color.white.opacity(0.15), location: 0.15),
                            .init(color: Color.clear,               location: 0.5),
                            .init(color: Color.black.opacity(0.12), location: 0.9),
                            .init(color: Color.black.opacity(0.20), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )

            // Inner shadow
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black, lineWidth: 4)
                .blur(radius: 3)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .opacity(0.08)

            // Plastic grain
            PlasticGrain()
                .fill(Color.white.opacity(0.015))
                .clipShape(RoundedRectangle(cornerRadius: 11))

            // ── Dark panel stripe ──
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [C.panelLight, C.panel, Color(white: 0.10)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black, lineWidth: 3)
                    .blur(radius: 2)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .opacity(0.5)

                VStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 1.5)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)

            // ── Controls ──
            HStack(spacing: 18) {
                dpad()

                Spacer()

                // Resize
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        roundBtn("−", shortcut: "Q", sz: 24)
                        roundBtn("+", shortcut: "E", sz: 24)
                    }
                    Text("SIZE")
                        .font(.system(size: 4.5, weight: .heavy, design: .rounded))
                        .foregroundColor(C.textRed.opacity(0.7))
                }

                Color.clear.frame(width: 6)

                // Merge
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        roundBtn("⟨", shortcut: "⇧A", sz: 26)
                        roundBtn("⟩", shortcut: "⇧D", sz: 26)
                    }
                    Text("MERGE")
                        .font(.system(size: 4.5, weight: .heavy, design: .rounded))
                        .foregroundColor(C.textRed.opacity(0.7))
                }

                Color.clear.frame(width: 6)

                // Layout
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        roundBtn("⧉", shortcut: "T", sz: 30)
                        roundBtn("≡", shortcut: "Y", sz: 30)
                        roundBtn("⬡", shortcut: "F", sz: 30)
                    }
                    Text("LAYOUT")
                        .font(.system(size: 4.5, weight: .heavy, design: .rounded))
                        .foregroundColor(C.textRed.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)

            // ── YOKE branding ──
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ZStack {
                        Text("Y O K E")
                            .font(.system(size: 6, weight: .black, design: .monospaced))
                            .foregroundColor(Color.black.opacity(0.08))
                            .offset(y: 0.5)
                        Text("Y O K E")
                            .font(.system(size: 6, weight: .black, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.12))
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 4)
                }
            }
        }
        .frame(height: 106)
        .padding(10)
    }

    // MARK: - D-Pad

    func dpad() -> some View {
        let arm: CGFloat = 20
        let crossSize = arm * 3

        return ZStack {
            // Circular recess
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.08), Color(white: 0.04)],
                        center: .center,
                        startRadius: 0, endRadius: crossSize * 0.55
                    )
                )
                .frame(width: crossSize + 6, height: crossSize + 6)
                .overlay(
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                        .blur(radius: 1.5)
                        .clipShape(Circle())
                        .opacity(0.5)
                )

            // Cross body
            CrossShape()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: C.dpadGray,  location: 0.0),
                            .init(color: C.dpadBlack, location: 0.5),
                            .init(color: Color(white: 0.06), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: crossSize, height: crossSize)
                .shadow(color: .black.opacity(0.4), radius: 2, y: 2)

            // Cross edge highlight
            CrossShape()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
                .frame(width: crossSize, height: crossSize)

            // Arrows
            dpadArrow("W", icon: "chevron.up").offset(y: -arm)
            dpadArrow("S", icon: "chevron.down").offset(y: arm)
            dpadArrow("A", icon: "chevron.left").offset(x: -arm)
            dpadArrow("D", icon: "chevron.right").offset(x: arm)

            // Center dimple
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 7, height: 7)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.14), Color(white: 0.07)],
                            center: .init(x: 0.35, y: 0.35),
                            startRadius: 0, endRadius: 4
                        )
                    )
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 2, height: 1.5)
                    .offset(x: -0.5, y: -1)
            }
        }
        .frame(width: crossSize + 12, height: crossSize + 12)
    }

    func dpadArrow(_ shortcut: String, icon: String) -> some View {
        let pressed = keys.pressedKey == shortcut

        return Image(systemName: icon)
            .font(.system(size: 10, weight: .black))
            .foregroundColor(pressed ? Color.white.opacity(0.85) : Color.white.opacity(0.20))
            .shadow(color: pressed ? Color.white.opacity(0.3) : .clear, radius: 3)
            .scaleEffect(pressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.05), value: pressed)
    }

    // MARK: - Round red buttons

    func roundBtn(_ icon: String, shortcut: String, sz: CGFloat) -> some View {
        let pressed = keys.pressedKey == shortcut

        return ZStack {
            // Button well
            Circle()
                .fill(Color.black.opacity(0.5))
                .frame(width: sz + 4, height: sz + 4)
            Circle()
                .stroke(Color.black.opacity(0.3), lineWidth: 1.5)
                .blur(radius: 1)
                .clipShape(Circle())
                .frame(width: sz + 4, height: sz + 4)

            // Shadow under button
            Circle()
                .fill(C.btnRedDeep)
                .frame(width: sz, height: sz)
                .offset(y: pressed ? 0 : 2)

            // Button face — convex gradient
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: C.btnRedLight, location: 0.0),
                            .init(color: C.btnRed,      location: 0.45),
                            .init(color: C.btnRedDark,  location: 0.85),
                            .init(color: C.btnRedDeep,  location: 1.0),
                        ],
                        center: .init(x: 0.38, y: 0.32),
                        startRadius: 0, endRadius: sz * 0.58
                    )
                )
                .frame(width: sz, height: sz)
                .offset(y: pressed ? 1.5 : 0)

            // Specular highlight
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(pressed ? 0.06 : 0.28), Color.clear],
                        center: .center,
                        startRadius: 0, endRadius: sz * 0.28
                    )
                )
                .frame(width: sz * 0.45, height: sz * 0.22)
                .offset(x: -sz * 0.06, y: pressed ? -sz * 0.06 : -sz * 0.13)

            // Rim highlight
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.clear, Color.black.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.6
                )
                .frame(width: sz, height: sz)
                .offset(y: pressed ? 1.5 : 0)

            // Icon
            Text(icon)
                .font(.system(size: sz > 28 ? 12 : 10, weight: .bold))
                .foregroundColor(Color.white.opacity(pressed ? 0.4 : 0.85))
                .shadow(color: .black.opacity(0.5), radius: 0.5, y: 0.5)
                .offset(y: pressed ? 1.5 : 0)
        }
        .animation(.easeOut(duration: 0.05), value: pressed)
    }
}
