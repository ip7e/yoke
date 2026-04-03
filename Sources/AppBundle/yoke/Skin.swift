import SwiftUI

// MARK: - Border configuration

struct BorderConfig {
    var color: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)
    var glowColor: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)
    var glowRadius: CGFloat
    var strokeWidth: CGFloat
    var padding: CGFloat // negative = outside the window
    var cornerRadius: CGFloat
}

// MARK: - Skin protocol

@MainActor
protocol YokeSkin {
    var borderConfig: BorderConfig { get }
    func makeView(keys: KeyState) -> AnyView
}
