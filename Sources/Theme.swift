import AppKit

/// A view with the origin at the top left, like the layouts of the keypad.
class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Measures, colours and fonts of the window. Everything is drawn by the app itself, over the
/// translucent material of the window, in the light and in the dark appearance of the system.
enum Theme {
    static func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    /// One colour for the light appearance and another for the dark one.
    static func dynamic(_ light: NSColor, _ dark: NSColor) -> NSColor {
        NSColor(name: nil) { $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light }
    }

    // Layout, in points
    static let margin: CGFloat = 4
    static let gap: CGFloat = 2
    static let keyRadius: CGFloat = 4
    static let headerHeight: CGFloat = 42
    static let displayHeight: CGFloat = 96
    static let barHeight: CGFloat = 30
    static let baseRowHeight: CGFloat = 22
    static let defaultWidth: CGFloat = 322
    /// The height of a row of keys when the window has its first size.
    static func keyHeight(for mode: CalcMode) -> CGFloat { mode == .standard ? 50 : 44 }

    // Window: a tint over the material, which lets some of the desktop through.
    static let tint = dynamic(rgb(0xF3F3F3, alpha: 0.72), rgb(0x1F2423, alpha: 0.70))
    static let text = dynamic(rgb(0x1B1B1B), rgb(0xFFFFFF))
    static let secondaryText = dynamic(rgb(0x000000, alpha: 0.62), rgb(0xFFFFFF, alpha: 0.78))
    static let disabledText = dynamic(rgb(0x000000, alpha: 0.34), rgb(0xFFFFFF, alpha: 0.34))
    static let accent = dynamic(rgb(0x005FB8), rgb(0x4CC2FF))
    static let accentHover = dynamic(rgb(0x1A6FBF), rgb(0x48B2E9))
    static let accentPressed = dynamic(rgb(0x337FC6), rgb(0x44A2D3))
    static let accentText = dynamic(rgb(0xFFFFFF), rgb(0x000000))

    // Keys: digits a little lighter than functions and operators.
    static let digitFill = dynamic(rgb(0xFFFFFF, alpha: 0.95), rgb(0xFFFFFF, alpha: 0.105))
    static let functionFill = dynamic(rgb(0xFFFFFF, alpha: 0.52), rgb(0xFFFFFF, alpha: 0.058))
    static let hoverFill = dynamic(rgb(0xFFFFFF, alpha: 0.72), rgb(0xFFFFFF, alpha: 0.082))
    static let pressedFill = dynamic(rgb(0xFFFFFF, alpha: 0.38), rgb(0xFFFFFF, alpha: 0.035))
    static let disabledFill = dynamic(rgb(0xFFFFFF, alpha: 0.30), rgb(0xFFFFFF, alpha: 0.03))
    static let keyBorder = dynamic(rgb(0x000000, alpha: 0.075), rgb(0xFFFFFF, alpha: 0.045))
    /// Under the pointer, for the buttons without a face: header, memory and menus.
    static let subtleHover = dynamic(rgb(0x000000, alpha: 0.055), rgb(0xFFFFFF, alpha: 0.075))
    static let subtlePressed = dynamic(rgb(0x000000, alpha: 0.03), rgb(0xFFFFFF, alpha: 0.045))
    /// The panel of the history and of the memory, over the keys.
    static let panelFill = dynamic(rgb(0xF4F4F4), rgb(0x272C2B))

    static let displayFontSize: CGFloat = 36
    static func displayFont(_ size: CGFloat) -> NSFont { .monospacedDigitSystemFont(ofSize: size, weight: .semibold) }
}
