import AppKit
import SwiftUI

@MainActor
class KeyState: ObservableObject {
    static let shared = KeyState()
    @Published var pressedKey: String? = nil
    @Published var altHeld: Bool = false
    @Published var shiftHeld: Bool = false
    @Published var helpPage: Int = 0
    @Published var errorFlash: Bool = false
    @Published var focusedIsFloating: Bool = false
    var creditsStartTick: Int = -1

    func press(_ key: String) {
        pressedKey = key
    }

    func release(_ key: String) {
        if pressedKey == key {
            pressedKey = nil
        }
    }

    func updateModifiers(_ flags: CGEventFlags) {
        let alt = flags.contains(.maskAlternate)
        let shift = flags.contains(.maskShift)
        if alt != altHeld { altHeld = alt }
        if shift != shiftHeld { shiftHeld = shift }
    }
}
