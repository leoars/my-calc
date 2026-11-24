import AppKit

/// What the buttons of the window share: the pointer over them, the press that follows the
/// pointer until the button is released, and the press for accessibility.
class PressableView: NSView {
    var isEnabled = true { didSet { if oldValue != isEnabled { needsDisplay = true } } }
    /// Stays down: 2nd while it is on, Keep on Top, the chosen base.
    var isChecked = false { didSet { if oldValue != isChecked { needsDisplay = true } } }
    var onPress: (() -> Void)?
    private(set) var hovered = false { didSet { if oldValue != hovered { needsDisplay = true } } }
    private(set) var pressed = false { didSet { if oldValue != pressed { needsDisplay = true } } }
    private var tracking: NSTrackingArea?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }
    override func isAccessibilityEnabled() -> Bool { isEnabled }

    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        onPress?()
        return true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        pressed = true
        // Leaving the button before releasing cancels the press.
        while let next = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) {
            let inside = bounds.contains(convert(next.locationInWindow, from: nil))
            if next.type == .leftMouseUp {
                pressed = false
                if inside { onPress?() }
                break
            }
            pressed = inside
        }
    }

    /// Shows the button pressed for an instant, for a key of the keyboard.
    func flash() {
        guard isEnabled else { return }
        pressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in self?.pressed = false }
    }

    /// The light plate under the pointer of the buttons that have no face of their own.
    func drawSubtleBackground(radius: CGFloat = 4) {
        guard isEnabled, hovered || pressed || isChecked else { return }
        (pressed ? Theme.subtlePressed : Theme.subtleHover).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: radius, yRadius: radius).fill()
    }
}

/// A key of the keypad: a rounded rectangle, lighter for the digits, in the accent colour for
/// the equals key.
final class KeyButton: PressableView {
    let spec: KeySpec
    var title: String { didSet { if oldValue != title { needsDisplay = true; setAccessibilityLabel(title) } } }

    init(spec: KeySpec) {
        self.spec = spec
        title = spec.title
        super.init(frame: .zero)
        setAccessibilityLabel(title)
        setAccessibilityIdentifier("key." + spec.id)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// The fill for the state the key is in.
    var fill: NSColor {
        if spec.kind == .accent || isChecked {
            return !isEnabled ? Theme.disabledFill : pressed ? Theme.accentPressed : hovered ? Theme.accentHover : Theme.accent
        }
        if !isEnabled { return Theme.disabledFill }
        if pressed { return Theme.pressedFill }
        if hovered { return Theme.hoverFill }
        return spec.kind == .digit ? Theme.digitFill : Theme.functionFill
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: Theme.keyRadius, yRadius: Theme.keyRadius)
        fill.setFill()
        path.fill()
        Theme.keyBorder.setStroke()
        path.lineWidth = 1
        path.stroke()

        let onAccent = (spec.kind == .accent || isChecked) && isEnabled
        let color = !isEnabled ? Theme.disabledText : onAccent ? Theme.accentText : Theme.text
        if spec.id == "backspace" {
            Self.drawBackspace(in: bounds, color: color)
            return
        }
        var size: CGFloat
        let weight: NSFont.Weight
        switch spec.kind {
        case .digit: (size, weight) = (spec.id == "negate" ? 12.5 : 14.5, .regular)
        case .operation, .accent: (size, weight) = (18, .light)
        case .function: (size, weight) = (12, .regular)
        }
        var attributes: [NSAttributedString.Key: Any] = [:]
        var measured = NSSize.zero
        // A long title shrinks to fit a narrow key.
        repeat {
            attributes = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
            measured = (title as NSString).size(withAttributes: attributes)
            size -= 0.5
        } while measured.width > bounds.width - 6 && size >= 8
        (title as NSString).draw(at: NSPoint(x: (bounds.width - measured.width) / 2, y: (bounds.height - measured.height) / 2 - 0.5),
                                 withAttributes: attributes)
    }

    /// The erase sign: a tag pointing left with a cross in it.
    static func drawBackspace(in bounds: NSRect, color: NSColor) {
        let width: CGFloat = 17, height: CGFloat = 12
        let x = floor(bounds.midX - width / 2) + 0.5, y = floor(bounds.midY - height / 2) + 0.5
        let tag = NSBezierPath()
        tag.move(to: NSPoint(x: x, y: y + height / 2))
        tag.line(to: NSPoint(x: x + 5.5, y: y))
        tag.line(to: NSPoint(x: x + width - 1.5, y: y))
        tag.appendArc(withCenter: NSPoint(x: x + width - 1.5, y: y + 1.5), radius: 1.5, startAngle: 270, endAngle: 0)
        tag.line(to: NSPoint(x: x + width, y: y + height - 1.5))
        tag.appendArc(withCenter: NSPoint(x: x + width - 1.5, y: y + height - 1.5), radius: 1.5, startAngle: 0, endAngle: 90)
        tag.line(to: NSPoint(x: x + 5.5, y: y + height))
        tag.close()
        tag.lineJoinStyle = .round
        let cross = NSBezierPath()
        let centre = NSPoint(x: x + 10.5, y: y + height / 2)
        cross.move(to: NSPoint(x: centre.x - 2.5, y: centre.y - 2.5))
        cross.line(to: NSPoint(x: centre.x + 2.5, y: centre.y + 2.5))
        cross.move(to: NSPoint(x: centre.x + 2.5, y: centre.y - 2.5))
        cross.line(to: NSPoint(x: centre.x - 2.5, y: centre.y + 2.5))
        color.setStroke()
        for path in [tag, cross] {
            path.lineWidth = 1
            path.lineCapStyle = .round
            path.stroke()
        }
    }
}

/// A button that is only its text: the memory row, the angle unit, the menus of functions.
final class TextButton: PressableView {
    var title: String { didSet { if oldValue != title { needsDisplay = true; setAccessibilityLabel(title) } } }
    var fontSize: CGFloat = 10.5
    var weight = NSFont.Weight.regular
    /// A small arrow after the text, for the buttons that open a menu.
    var showsArrow = false
    let id: String

    init(id: String, title: String) {
        self.id = id
        self.title = title
        super.init(frame: .zero)
        setAccessibilityLabel(title)
        setAccessibilityIdentifier("button." + id)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private var attributes: [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: fontSize, weight: weight), .foregroundColor: isEnabled ? Theme.text : Theme.disabledText]
    }

    /// The width the text asks for, with its margins.
    var fittingWidth: CGFloat { ceil((title as NSString).size(withAttributes: attributes).width) + 16 + (showsArrow ? 11 : 0) }

    override func draw(_ dirtyRect: NSRect) {
        drawSubtleBackground()
        let size = (title as NSString).size(withAttributes: attributes)
        let total = size.width + (showsArrow ? 11 : 0)
        let x = (bounds.width - total) / 2
        (title as NSString).draw(at: NSPoint(x: x, y: (bounds.height - size.height) / 2 - 0.5), withAttributes: attributes)
        if showsArrow {
            let arrow = NSBezierPath()
            let centre = NSPoint(x: x + size.width + 7, y: bounds.midY + 0.5)
            arrow.move(to: NSPoint(x: centre.x - 3, y: centre.y - 1.5))
            arrow.line(to: NSPoint(x: centre.x, y: centre.y + 1.5))
            arrow.line(to: NSPoint(x: centre.x + 3, y: centre.y - 1.5))
            arrow.lineWidth = 1
            arrow.lineCapStyle = .round
            arrow.lineJoinStyle = .round
            (isEnabled ? Theme.text : Theme.disabledText).setStroke()
            arrow.stroke()
        }
    }
}

/// The small drawings of the header and of the panels, made of lines by the app itself.
enum Glyph {
    case menu, keepOnTop, history, trash, keypad, bits

    func draw(in bounds: NSRect, color: NSColor) {
        let centre = NSPoint(x: floor(bounds.midX) + 0.5, y: floor(bounds.midY) + 0.5)
        let path = NSBezierPath()
        path.lineWidth = 1
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        color.setStroke()
        switch self {
        case .menu:
            for offset in [-5, 0, 5] as [CGFloat] {
                path.move(to: NSPoint(x: centre.x - 7, y: centre.y + offset))
                path.line(to: NSPoint(x: centre.x + 7, y: centre.y + offset))
            }
        case .keepOnTop:
            // A window in front of another, with an arrow coming to the front.
            path.appendRoundedRect(NSRect(x: centre.x - 7, y: centre.y - 1, width: 10, height: 8), xRadius: 1.5, yRadius: 1.5)
            path.move(to: NSPoint(x: centre.x - 3, y: centre.y - 4))
            path.line(to: NSPoint(x: centre.x - 3, y: centre.y - 5.5))
            path.appendArc(withCenter: NSPoint(x: centre.x - 1.5, y: centre.y - 5.5), radius: 1.5, startAngle: 180, endAngle: 270)
            path.line(to: NSPoint(x: centre.x + 5.5, y: centre.y - 7))
            path.appendArc(withCenter: NSPoint(x: centre.x + 5.5, y: centre.y - 5.5), radius: 1.5, startAngle: 270, endAngle: 0)
            path.line(to: NSPoint(x: centre.x + 7, y: centre.y + 1.5))
            path.appendArc(withCenter: NSPoint(x: centre.x + 5.5, y: centre.y + 1.5), radius: 1.5, startAngle: 0, endAngle: 90)
            path.move(to: NSPoint(x: centre.x - 0.5, y: centre.y + 1))
            path.line(to: NSPoint(x: centre.x + 3.5, y: centre.y - 3))
            path.move(to: NSPoint(x: centre.x + 0.5, y: centre.y - 3.5))
            path.line(to: NSPoint(x: centre.x + 4, y: centre.y - 3.5))
            path.line(to: NSPoint(x: centre.x + 4, y: centre.y))
        case .history:
            // A clock whose rim turns back, with an arrowhead at its start.
            path.appendArc(withCenter: centre, radius: 7, startAngle: 215, endAngle: 170)
            path.move(to: NSPoint(x: centre.x - 8.5, y: centre.y - 6.5))
            path.line(to: NSPoint(x: centre.x - 5.8, y: centre.y - 3.6))
            path.line(to: NSPoint(x: centre.x - 2.6, y: centre.y - 5.6))
            path.move(to: NSPoint(x: centre.x, y: centre.y - 4))
            path.line(to: NSPoint(x: centre.x, y: centre.y + 0.5))
            path.line(to: NSPoint(x: centre.x + 3, y: centre.y + 2.5))
        case .trash:
            path.move(to: NSPoint(x: centre.x - 6, y: centre.y - 4.5))
            path.line(to: NSPoint(x: centre.x + 6, y: centre.y - 4.5))
            path.move(to: NSPoint(x: centre.x - 2, y: centre.y - 4.5))
            path.line(to: NSPoint(x: centre.x - 2, y: centre.y - 6.5))
            path.line(to: NSPoint(x: centre.x + 2, y: centre.y - 6.5))
            path.line(to: NSPoint(x: centre.x + 2, y: centre.y - 4.5))
            path.move(to: NSPoint(x: centre.x - 4.5, y: centre.y - 4.5))
            path.line(to: NSPoint(x: centre.x - 3.5, y: centre.y + 7))
            path.line(to: NSPoint(x: centre.x + 3.5, y: centre.y + 7))
            path.line(to: NSPoint(x: centre.x + 4.5, y: centre.y - 4.5))
            path.move(to: NSPoint(x: centre.x - 1.5, y: centre.y - 1.5))
            path.line(to: NSPoint(x: centre.x - 1.5, y: centre.y + 4))
            path.move(to: NSPoint(x: centre.x + 1.5, y: centre.y - 1.5))
            path.line(to: NSPoint(x: centre.x + 1.5, y: centre.y + 4))
        case .keypad:
            // Nine dots, as the keys of a keypad.
            color.setFill()
            for row in -1...1 {
                for column in -1...1 {
                    NSBezierPath(ovalIn: NSRect(x: centre.x + CGFloat(column) * 5 - 1.5, y: centre.y + CGFloat(row) * 5 - 1.5, width: 3, height: 3)).fill()
                }
            }
            return
        case .bits:
            // Two rows of bits: rings for zeros, dots for ones.
            color.setFill()
            for row in 0...1 {
                for column in 0...2 {
                    let rect = NSRect(x: centre.x + CGFloat(column - 1) * 6 - 2, y: centre.y + (row == 0 ? -5.5 : 1.5), width: 4, height: 4)
                    if (row + column) % 2 == 0 { NSBezierPath(ovalIn: rect).fill() } else { NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).stroke() }
                }
            }
            return
        }
        path.stroke()
    }
}

/// A button that is only a drawing.
final class GlyphButton: PressableView {
    let glyph: Glyph
    let id: String

    init(id: String, glyph: Glyph, label: String) {
        self.id = id
        self.glyph = glyph
        super.init(frame: .zero)
        setAccessibilityLabel(label)
        setAccessibilityIdentifier("button." + id)
        toolTip = label
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func draw(_ dirtyRect: NSRect) {
        drawSubtleBackground()
        glyph.draw(in: bounds, color: !isEnabled ? Theme.disabledText : isChecked ? Theme.accent : Theme.text)
    }
}

/// The display: the calculation so far on a small line and the number below it, large and to
/// the right, shrinking when it is long.
final class DisplayView: FlippedView {
    var expression = "" { didSet { if oldValue != expression { needsDisplay = true } } }
    var text = "0" { didSet { if oldValue != text { needsDisplay = true; setAccessibilityValue(text) } } }
    /// The largest size of the number; the programmer mode uses a smaller one.
    var fontSize = Theme.displayFontSize { didSet { needsDisplay = true } }
    static let inset: CGFloat = 14

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityIdentifier("display")
        setAccessibilityValue(text)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// The size the number is drawn with: the largest that fits the width, down to a minimum.
    func fittedFontSize(for text: String, width: CGFloat) -> CGFloat {
        var size = fontSize
        while size > 9, (text as NSString).size(withAttributes: [.font: Theme.displayFont(size)]).width > width { size -= 1 }
        return size
    }

    override func draw(_ dirtyRect: NSRect) {
        let room = bounds.width - 2 * Self.inset
        // The line of the calculation keeps its end in sight when it is too long.
        let small: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: Theme.secondaryText]
        var line = expression
        while line.count > 1, (line as NSString).size(withAttributes: small).width > room {
            line = "…" + line.dropFirst(line.hasPrefix("…") ? 3 : 2)
        }
        let lineSize = (line as NSString).size(withAttributes: small)
        (line as NSString).draw(at: NSPoint(x: bounds.width - Self.inset - lineSize.width, y: 6), withAttributes: small)

        let size = fittedFontSize(for: text, width: room)
        let attributes: [NSAttributedString.Key: Any] = [.font: Theme.displayFont(size), .foregroundColor: Theme.text]
        let textSize = (text as NSString).size(withAttributes: attributes)
        // Smaller numbers stay on the line where the large ones stand.
        let drop = (Theme.displayFont(fontSize).ascender - Theme.displayFont(size).ascender) * 0.25
        (text as NSString).draw(at: NSPoint(x: bounds.width - Self.inset - textSize.width, y: bounds.height - 6 - textSize.height - drop),
                                withAttributes: attributes)
    }
}

/// The number of the programmer mode in the four bases at once. A click on a row chooses its base.
final class BaseRowsView: FlippedView {
    var values = ["0", "0", "0", "0"] { didSet { if oldValue != values { needsDisplay = true } } }
    var selected = 1 { didSet { if oldValue != selected { needsDisplay = true } } }
    var onChoose: ((Int) -> Void)?
    static let names = ["HEX", "DEC", "OCT", "BIN"]

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityIdentifier("bases")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func rowRect(_ index: Int) -> NSRect {
        NSRect(x: 0, y: CGFloat(index) * Theme.baseRowHeight, width: bounds.width, height: Theme.baseRowHeight)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let index = (0..<4).first(where: { rowRect($0).contains(point) }) { onChoose?(index) }
    }

    override func draw(_ dirtyRect: NSRect) {
        for index in 0..<4 {
            let rect = rowRect(index)
            let chosen = index == selected
            if chosen {
                // A short bar in the accent colour marks the base in use.
                Theme.accent.setFill()
                NSBezierPath(roundedRect: NSRect(x: 6, y: rect.minY + 4, width: 3, height: rect.height - 8), xRadius: 1.5, yRadius: 1.5).fill()
            }
            let name: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: chosen ? .semibold : .regular),
                                                       .foregroundColor: Theme.text]
            (Self.names[index] as NSString).draw(at: NSPoint(x: 16, y: rect.minY + 4), withAttributes: name)
            var size: CGFloat = 12
            var attributes: [NSAttributedString.Key: Any] = [:]
            var measured = NSSize.zero
            repeat {
                attributes = [.font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular), .foregroundColor: Theme.text]
                measured = (values[index] as NSString).size(withAttributes: attributes)
                size -= 0.5
            } while measured.width > bounds.width - 62 && size >= 6
            (values[index] as NSString).draw(at: NSPoint(x: 52, y: rect.minY + (rect.height - measured.height) / 2), withAttributes: attributes)
        }
    }
}

/// One line of the history or of the memory: a small text above and the number below it.
struct ListRow: Equatable {
    var detail = ""
    let value: String
}

/// The panel that comes over the keys with the history or with the numbers of the memory. A
/// click on a line chooses it; the bin at the bottom empties the list.
final class ListPanel: FlippedView {
    static let rowHeight: CGFloat = 50

    private let scroll = NSScrollView()
    private let rowsView = ListRowsView()
    let clearButton = GlyphButton(id: "list.clear", glyph: .trash, label: "")
    private let emptyLabel = NSTextField(labelWithString: "")
    var rows: [ListRow] = [] { didSet { reload() } }
    var emptyText = "" { didSet { emptyLabel.stringValue = emptyText } }
    var onSelect: ((Int) -> Void)? {
        get { rowsView.onSelect }
        set { rowsView.onSelect = newValue }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.documentView = rowsView
        addSubview(scroll)
        emptyLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        emptyLabel.textColor = Theme.text
        addSubview(emptyLabel)
        addSubview(clearButton)
        setAccessibilityIdentifier("list")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func resizeSubviews(withOldSize oldSize: NSSize) { reload() }

    private func reload() {
        scroll.frame = NSRect(x: 0, y: 6, width: bounds.width, height: max(0, bounds.height - 46))
        clearButton.frame = NSRect(x: bounds.width - 40, y: bounds.height - 36, width: 32, height: 30)
        clearButton.isHidden = rows.isEmpty
        emptyLabel.isHidden = !rows.isEmpty
        emptyLabel.sizeToFit()
        emptyLabel.frame.origin = NSPoint(x: 14, y: 14)
        rowsView.rows = rows
        rowsView.frame = NSRect(x: 0, y: 0, width: scroll.contentSize.width,
                                height: max(scroll.contentSize.height, CGFloat(rows.count) * Self.rowHeight))
        rowsView.needsDisplay = true
        rowsView.scroll(.zero)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Only the top corners are round: the panel rises from the bottom of the window.
        let path = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height + 8), xRadius: 8, yRadius: 8)
        Theme.panelFill.setFill()
        path.fill()
        Theme.keyBorder.setStroke()
        path.stroke()
    }

    // The keys under the panel must not take the clicks on it.
    override func mouseDown(with event: NSEvent) {}
}

private final class ListRowsView: FlippedView {
    var rows: [ListRow] = []
    var onSelect: ((Int) -> Void)?
    private var hovered: Int? { didSet { if oldValue != hovered { needsDisplay = true } } }
    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    private func row(at point: NSPoint) -> Int? {
        let index = Int(floor(point.y / ListPanel.rowHeight))
        return point.y >= 0 && rows.indices.contains(index) ? index : nil
    }

    override func mouseMoved(with event: NSEvent) { hovered = row(at: convert(event.locationInWindow, from: nil)) }
    override func mouseExited(with event: NSEvent) { hovered = nil }

    override func mouseDown(with event: NSEvent) {
        if let index = row(at: convert(event.locationInWindow, from: nil)) { onSelect?(index) }
    }

    private func fitted(_ text: String, _ attributes: [NSAttributedString.Key: Any], width: CGFloat) -> String {
        var line = text
        while line.count > 1, (line as NSString).size(withAttributes: attributes).width > width {
            line = "…" + line.dropFirst(line.hasPrefix("…") ? 3 : 2)
        }
        return line
    }

    override func draw(_ dirtyRect: NSRect) {
        let small: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: Theme.secondaryText]
        let large: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 18, weight: .semibold),
                                                    .foregroundColor: Theme.text]
        for (index, item) in rows.enumerated() {
            let rect = NSRect(x: 4, y: CGFloat(index) * ListPanel.rowHeight, width: bounds.width - 8, height: ListPanel.rowHeight)
            guard rect.intersects(dirtyRect) else { continue }
            if hovered == index {
                Theme.subtleHover.setFill()
                NSBezierPath(roundedRect: rect.insetBy(dx: 0, dy: 1), xRadius: 4, yRadius: 4).fill()
            }
            let detail = fitted(item.detail, small, width: rect.width - 20) as NSString
            let detailSize = detail.size(withAttributes: small)
            detail.draw(at: NSPoint(x: rect.maxX - 10 - detailSize.width, y: rect.minY + 5), withAttributes: small)
            let value = fitted(item.value, large, width: rect.width - 20) as NSString
            let valueSize = value.size(withAttributes: large)
            value.draw(at: NSPoint(x: rect.maxX - 10 - valueSize.width, y: rect.minY + 22), withAttributes: large)
        }
    }
}

/// The 64 bits of the programmer mode, in four rows of four nibbles. A click on a bit flips it;
/// the bits beyond the word size are greyed.
final class BitPanel: FlippedView {
    var bits: UInt64 = 0 { didSet { if oldValue != bits { needsDisplay = true } } }
    var wordSize = 64 { didSet { if oldValue != wordSize { needsDisplay = true } } }
    var onToggle: ((Int) -> Void)?

    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .regular)
    private static let labelFont = NSFont.systemFont(ofSize: 9)

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityIdentifier("bits")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private var digitWidth: CGFloat { ceil(("0" as NSString).size(withAttributes: [.font: Self.font]).width) + 3 }

    /// Where the bit `index` (0 the lowest) is drawn: the highest at the top left.
    func rect(forBit index: Int) -> NSRect {
        let row = 3 - index / 16
        let position = 15 - index % 16  // from the left of its row
        let group = position / 4, inGroup = position % 4
        let groupWidth = 4 * digitWidth
        let spacing = (bounds.width - 4 * groupWidth) / 4
        let rowHeight = bounds.height / 4
        let x = spacing / 2 + CGFloat(group) * (groupWidth + spacing) + CGFloat(inGroup) * digitWidth
        return NSRect(x: x, y: CGFloat(row) * rowHeight + rowHeight / 2 - 16, width: digitWidth, height: 20)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for index in 0..<wordSize where rect(forBit: index).contains(point) {
            onToggle?(index)
            return
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        for index in 0..<64 {
            let rect = rect(forBit: index)
            let on = bits >> UInt64(index) & 1 == 1
            let color = index < wordSize ? (on ? Theme.accent : Theme.text) : Theme.disabledText
            let attributes: [NSAttributedString.Key: Any] = [.font: on ? NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .bold) : Self.font,
                                                             .foregroundColor: color]
            let text = (on ? "1" : "0") as NSString
            let size = text.size(withAttributes: attributes)
            text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.minY), withAttributes: attributes)
        }
        // Under each nibble, the position of its lowest bit.
        let labels: [NSAttributedString.Key: Any] = [.font: Self.labelFont, .foregroundColor: Theme.secondaryText]
        for index in stride(from: 0, to: 64, by: 4) {
            let lowest = rect(forBit: index)
            let text = String(index) as NSString
            let size = text.size(withAttributes: labels)
            text.draw(at: NSPoint(x: lowest.maxX - size.width - 1, y: lowest.maxY - 1), withAttributes: labels)
        }
    }
}
