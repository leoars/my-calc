import AppKit

/// The content of the window: tints the material behind it, takes the keyboard and lays the
/// parts out again when the window changes size.
final class KeypadHostView: FlippedView {
    weak var controller: MainWindowController?

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        Theme.tint.setFill()
        bounds.fill()
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) { controller?.layout() }

    override func keyDown(with event: NSEvent) {
        if controller?.handleKey(event) != true { super.keyDown(with: event) }
    }

    /// The shortcuts with Control and with Option never reach `keyDown` by themselves.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.type == .keyDown, !flags.contains(.command), flags.contains(.control) || flags.contains(.option),
           window?.firstResponder === self, controller?.handleKey(event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        // A click beside the panel of the history or of the memory closes it.
        controller?.closePanel()
    }
}

/// The window of the calculator: the header with the mode, the display, the memory row and the
/// keypad of the current mode.
final class MainWindowController: NSObject, NSWindowDelegate, NSMenuItemValidation {
    enum Panel {
        case history, memory
    }

    let window: NSWindow
    let calculator: Calculator
    private let host = KeypadHostView()
    var settingsWindow: SettingsWindow?

    // Header
    let menuButton = GlyphButton(id: "menu", glyph: .menu, label: L("header.menu"))
    let titleLabel = NSTextField(labelWithString: "")
    let keepOnTopButton = GlyphButton(id: "keepOnTop", glyph: .keepOnTop, label: L("header.keepOnTop"))
    let historyButton = GlyphButton(id: "history", glyph: .history, label: L("menu.showHistory"))

    let display = DisplayView(frame: .zero)
    let baseRows = BaseRowsView(frame: .zero)
    let bitPanel = BitPanel(frame: .zero)
    let listPanel = ListPanel(frame: .zero)

    /// MC, MR, M+, M−, MS and the list of the memory.
    let memoryButtons: [TextButton] = [("mc", "MC"), ("mr", "MR"), ("m+", "M+"), ("m-", "M−"), ("ms", "MS"), ("mlist", "M")]
        .map { TextButton(id: $0.0, title: $0.1) }
    // Scientific
    let angleButton = TextButton(id: "angle", title: "DEG")
    let notationButton = TextButton(id: "fe", title: "F-E")
    let trigonometryButton = TextButton(id: "trigonometry", title: L("scientific.trigonometry"))
    let functionButton = TextButton(id: "function", title: L("scientific.function"))
    // Programmer
    let keypadButton = GlyphButton(id: "keypad", glyph: .keypad, label: L("programmer.keypad"))
    let bitsButton = GlyphButton(id: "bits", glyph: .bits, label: L("programmer.bits"))
    let wordButton = TextButton(id: "word", title: "QWORD")
    let bitwiseButton = TextButton(id: "bitwise", title: L("programmer.bitwise"))

    private(set) var keys: [KeyButton] = []
    private var layoutOfKeys = KeypadLayout(rows: [])

    /// The 2nd key: the keys that have another face show it.
    private(set) var second = false
    /// The programmer mode shows the bits in the place of the keys.
    private(set) var showsBits = false
    private(set) var panel: Panel?

    var mode: CalcMode { calculator.mode }
    var isKeptOnTop: Bool { window.level == .floating }

    override init() {
        let defaults = AppSettings.defaults
        let mode = CalcMode(rawValue: defaults.integer(forKey: AppSettings.modeKey)) ?? .standard
        let format = NumberFormat(locale: .current, grouping: AppSettings.bool(AppSettings.digitGroupingKey, default: true))
        calculator = Calculator(mode: mode, format: format)
        calculator.angleUnit = AngleUnit(rawValue: defaults.integer(forKey: AppSettings.angleUnitKey)) ?? .degrees
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: Theme.defaultWidth, height: 510),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        super.init()
        window.title = "My Calc"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        // The material of the window lets a little of what is behind it through, tinted by the host.
        let effect = NSVisualEffectView()
        effect.material = .underWindowBackground
        effect.blendingMode = .behindWindow
        effect.state = .active
        window.contentView = effect
        host.controller = self
        host.frame = effect.bounds
        host.autoresizingMask = [.width, .height]
        effect.addSubview(host)

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = Theme.text
        memoryButtons.last?.showsArrow = true
        for button in [trigonometryButton, functionButton, bitwiseButton] { button.showsArrow = true }
        for button in [angleButton, notationButton, wordButton] { button.fontSize = 12; button.weight = .semibold }
        let views: [NSView] = [menuButton, titleLabel, keepOnTopButton, historyButton, display, baseRows, bitPanel]
            + memoryButtons + [angleButton, notationButton, trigonometryButton, functionButton, keypadButton, bitsButton, wordButton, bitwiseButton]
        views.forEach(host.addSubview)

        menuButton.onPress = { [weak self] in self?.showModeMenu() }
        keepOnTopButton.onPress = { [weak self] in self?.toggleKeepOnTop(nil) }
        historyButton.onPress = { [weak self] in self?.togglePanel(.history) }
        for button in memoryButtons {
            button.onPress = { [weak self, unowned button] in self?.run(button.id) }
        }
        angleButton.onPress = { [weak self] in
            guard let self else { return }
            self.setAngleUnit(AngleUnit(rawValue: (self.calculator.angleUnit.rawValue + 1) % 3) ?? .degrees)
        }
        notationButton.onPress = { [weak self] in self?.run("fe") }
        trigonometryButton.onPress = { [weak self] in self?.showFunctionMenu(KeypadLayout.trigonometry, from: self?.trigonometryButton) }
        functionButton.onPress = { [weak self] in self?.showFunctionMenu(KeypadLayout.functions, from: self?.functionButton) }
        bitwiseButton.onPress = { [weak self] in self?.showFunctionMenu(KeypadLayout.bitwise, from: self?.bitwiseButton) }
        keypadButton.onPress = { [weak self] in self?.setShowsBits(false) }
        bitsButton.onPress = { [weak self] in self?.setShowsBits(true) }
        wordButton.onPress = { [weak self] in
            guard let self else { return }
            let sizes = WordSize.allCases
            self.setWordSize(sizes[((sizes.firstIndex(of: self.calculator.wordSize) ?? 0) + 1) % sizes.count])
        }
        baseRows.onChoose = { [weak self] index in self?.setRadix(Radix.allCases[index]) }
        bitPanel.onToggle = { [weak self] index in
            self?.calculator.toggleBit(index)
            self?.refresh()
        }
        listPanel.onSelect = { [weak self] index in self?.chooseListRow(index) }
        listPanel.clearButton.onPress = { [weak self] in
            guard let self else { return }
            if self.panel == .history { self.calculator.clearHistory() } else { self.calculator.press(.memoryClear) }
            self.refresh()
        }

        rebuild()
        if let saved = defaults.string(forKey: AppSettings.windowOriginKey) {
            window.setFrameTopLeftPoint(NSPointFromString(saved))
            // A screen that is no longer there must not hide the window.
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        } else {
            window.center()
        }
        window.makeFirstResponder(host)
    }

    // MARK: Layout

    /// The height of the title bar, which the content runs under.
    private var topInset: CGFloat { window.frame.height - window.contentLayoutRect.height }

    /// The parts above the keys, from the top of the content, for a mode.
    private func fixedHeight(for mode: CalcMode) -> CGFloat {
        let base = topInset + Theme.headerHeight
        switch mode {
        case .standard: return base + Theme.displayHeight + Theme.barHeight
        case .scientific: return base + Theme.displayHeight + 3 * Theme.barHeight
        case .programmer: return base + 62 + 4 * Theme.baseRowHeight + 2 * Theme.barHeight + 4
        }
    }

    /// The first size of the window in a mode, which is also its smallest.
    func defaultSize(for mode: CalcMode) -> NSSize {
        let rows = CGFloat(KeypadLayout.layout(for: mode, decimalSeparator: ".").rows.count)
        return NSSize(width: Theme.defaultWidth,
                      height: fixedHeight(for: mode) + rows * Theme.keyHeight(for: mode) + (rows - 1) * Theme.gap + Theme.margin)
    }

    /// Builds the keypad of the current mode and gives the window its size, keeping its top left corner.
    func rebuild() {
        keys.forEach { $0.removeFromSuperview() }
        layoutOfKeys = KeypadLayout.layout(for: mode, decimalSeparator: calculator.format.decimalSeparator)
        keys = layoutOfKeys.keys.map { spec in
            let button = KeyButton(spec: spec)
            button.onPress = { [weak self] in self?.perform(spec) }
            host.addSubview(button, positioned: .below, relativeTo: listPanel.superview == nil ? nil : listPanel)
            return button
        }
        second = false
        if mode != .programmer { showsBits = false }
        panel = nil
        listPanel.removeFromSuperview()
        titleLabel.stringValue = L(Self.modeNames[mode.rawValue])

        let size = defaultSize(for: mode)
        let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
        window.contentMinSize = size
        window.setContentSize(size)
        window.setFrameTopLeftPoint(topLeft)
        layout()
        refresh()
    }

    static let modeNames = ["menu.standard", "menu.scientific", "menu.programmer"]

    /// Places every part for the current size of the window; the keys share what is left.
    func layout() {
        let bounds = host.bounds
        guard bounds.width > 0 else { return }
        let width = bounds.width
        var y = topInset
        menuButton.frame = NSRect(x: 6, y: y + 5, width: 36, height: 32)
        titleLabel.sizeToFit()
        titleLabel.frame.origin = NSPoint(x: 46, y: y + (Theme.headerHeight - titleLabel.frame.height) / 2)
        keepOnTopButton.frame = NSRect(x: titleLabel.frame.maxX + 8, y: y + 5, width: 32, height: 32)
        historyButton.frame = NSRect(x: width - 42, y: y + 5, width: 36, height: 32)
        historyButton.isHidden = mode == .programmer
        y += Theme.headerHeight

        let programmer = mode == .programmer, scientific = mode == .scientific
        display.fontSize = programmer ? 30 : Theme.displayFontSize
        display.frame = NSRect(x: 0, y: y, width: width, height: programmer ? 62 : Theme.displayHeight)
        y = display.frame.maxY
        baseRows.isHidden = !programmer
        if programmer {
            baseRows.frame = NSRect(x: 0, y: y, width: width, height: 4 * Theme.baseRowHeight)
            y = baseRows.frame.maxY + 4
        }

        func bar(_ views: [NSView], widths: [CGFloat]? = nil) {
            var x = Theme.margin
            let each = (width - 2 * Theme.margin) / CGFloat(views.count)
            for (index, view) in views.enumerated() {
                let w = widths?[index] ?? each
                view.frame = NSRect(x: x, y: y + 1, width: w, height: Theme.barHeight - 2)
                x += w
            }
            y += Theme.barHeight
        }
        [angleButton, notationButton, trigonometryButton, functionButton].forEach { $0.isHidden = !scientific }
        [keypadButton, bitsButton, wordButton, bitwiseButton].forEach { $0.isHidden = !programmer }
        memoryButtons.forEach { $0.isHidden = programmer && !["ms", "mlist"].contains($0.id) }
        let panelTop: CGFloat
        if scientific {
            bar([angleButton, notationButton], widths: [angleButton.fittingWidth + 8, notationButton.fittingWidth + 8])
            panelTop = y
            bar(memoryButtons)
            bar([trigonometryButton, functionButton], widths: [trigonometryButton.fittingWidth, functionButton.fittingWidth])
        } else if programmer {
            let stored = memoryButtons.filter { !$0.isHidden }
            bar([keypadButton, bitsButton, wordButton], widths: [40, 40, wordButton.fittingWidth + 12])
            // MS and the list of the memory stand at the right of the same row.
            var x = width - Theme.margin
            for button in stored.reversed() {
                x -= 52
                button.frame = NSRect(x: x, y: keypadButton.frame.minY, width: 52, height: Theme.barHeight - 2)
            }
            panelTop = y
            bar([bitwiseButton], widths: [bitwiseButton.fittingWidth])
        } else {
            panelTop = y
            bar(memoryButtons)
        }

        // The keys take the rest, down to the bottom margin.
        let rows = layoutOfKeys.rows.count, columns = layoutOfKeys.columns
        let area = NSRect(x: Theme.margin, y: y, width: width - 2 * Theme.margin, height: max(0, bounds.height - y - Theme.margin))
        if rows > 0, columns > 0 {
            let keyWidth = (area.width - CGFloat(columns - 1) * Theme.gap) / CGFloat(columns)
            let keyHeight = (area.height - CGFloat(rows - 1) * Theme.gap) / CGFloat(rows)
            for (index, button) in keys.enumerated() {
                let row = index / columns, column = index % columns
                // Whole points, so the edges of the keys stay sharp.
                let x = area.minX + (CGFloat(column) * (keyWidth + Theme.gap)).rounded()
                let top = area.minY + (CGFloat(row) * (keyHeight + Theme.gap)).rounded()
                let right = area.minX + (CGFloat(column) * (keyWidth + Theme.gap) + keyWidth).rounded()
                let bottom = area.minY + (CGFloat(row) * (keyHeight + Theme.gap) + keyHeight).rounded()
                button.frame = NSRect(x: x, y: top, width: right - x, height: bottom - top)
                button.isHidden = showsBits
            }
        }
        bitPanel.isHidden = !(programmer && showsBits)
        bitPanel.frame = area
        if listPanel.superview != nil {
            listPanel.frame = NSRect(x: 0, y: panelTop, width: width, height: bounds.height - panelTop)
        }
    }

    func key(_ id: String) -> KeyButton? { keys.first { $0.spec.id == id } }
    func memoryButton(_ id: String) -> TextButton? { memoryButtons.first { $0.id == id } }

    /// Brings the window up to date with the calculator.
    func refresh() {
        display.expression = calculator.expressionText
        display.text = calculator.error.map { L($0.messageKey) } ?? calculator.displayText
        for button in keys {
            let spec = button.spec
            if spec.id == "second" {
                button.isChecked = second
            } else if let other = spec.second {
                button.title = second ? other.title : spec.title
            } else if spec.key == .clearSmart {
                // One key: CE while a number is being typed, C otherwise.
                button.title = calculator.entry != nil ? "CE" : "C"
            }
            button.isEnabled = isEnabled(spec)
        }
        for id in ["mc", "mr", "mlist"] { memoryButton(id)?.isEnabled = calculator.hasMemory }
        keepOnTopButton.isChecked = isKeptOnTop
        historyButton.isChecked = panel == .history
        if mode == .scientific {
            angleButton.title = ["DEG", "RAD", "GRAD"][calculator.angleUnit.rawValue]
            notationButton.isChecked = calculator.scientificNotation
        }
        if mode == .programmer {
            baseRows.values = Radix.allCases.map { calculator.text(in: $0) }
            baseRows.selected = Radix.allCases.firstIndex(of: calculator.radix) ?? 1
            wordButton.title = ["QWORD", "DWORD", "WORD", "BYTE"][WordSize.allCases.firstIndex(of: calculator.wordSize) ?? 0]
            bitPanel.wordSize = calculator.wordSize.rawValue
            bitPanel.bits = calculator.error == nil ? calculator.bits : 0
            keypadButton.isChecked = !showsBits
            bitsButton.isChecked = showsBits
        }
        if let panel {
            // The newest first, as on a pile.
            let rows = panel == .history
                ? calculator.history.reversed().map { ListRow(detail: $0.expression, value: calculator.format.string($0.value)) }
                : calculator.memories.map { ListRow(value: calculator.format.string($0)) }
            if listPanel.rows != rows { listPanel.rows = rows }
            listPanel.emptyText = L(panel == .history ? "history.empty" : "memory.empty")
        }
    }

    private func isEnabled(_ spec: KeySpec) -> Bool {
        if spec.id == "second" { return true }
        guard let key = spec.key else { return false }
        guard mode == .programmer else { return true }
        if case .digit(let digit) = key { return calculator.accepts(digit: digit) }
        return spec.id != "decimal"
    }

    // MARK: Keys and commands

    private func perform(_ spec: KeySpec, secondFace: Bool? = nil) {
        if spec.id == "second" {
            second.toggle()
            refresh()
            return
        }
        guard isEnabled(spec) else { return }
        let useSecond = secondFace ?? second
        guard let key = useSecond ? (spec.second?.key ?? spec.key) : spec.key else { return }
        press(key)
    }

    /// Sends a key to the calculator and shows the result.
    private func press(_ key: Key) {
        calculator.press(key)
        if panel != nil { closePanel() }
        refresh()
    }

    /// A key of the keyboard: a key of the keypad, a function of a menu or a command of the window.
    func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.contains(.command) else { return false }
        // The Clear key of the numeric keypad.
        if event.keyCode == 71 { return run("c") }
        guard let command = KeyboardMap.command(characters: event.charactersIgnoringModifiers ?? "", keyCode: event.keyCode,
                                                control: flags.contains(.control), option: flags.contains(.option),
                                                shift: flags.contains(.shift), mode: mode) else { return false }
        return run(command)
    }

    /// Runs a command: the id of a key (with `.second` for its other face), of a function of a
    /// menu, of a button of the memory, or one of the commands of `KeyboardMap`. False when the
    /// current mode has nothing by that name, or it is disabled.
    @discardableResult
    func run(_ command: String) -> Bool {
        switch command {
        case "mode.standard": setMode(.standard)
        case "mode.scientific": setMode(.scientific)
        case "mode.programmer": setMode(.programmer)
        case "angle.degrees": setAngleUnit(.degrees)
        case "angle.radians": setAngleUnit(.radians)
        case "angle.grads": setAngleUnit(.grads)
        case "radix.hex": setRadix(.hex)
        case "radix.dec": setRadix(.dec)
        case "radix.oct": setRadix(.oct)
        case "radix.bin": setRadix(.bin)
        case "word.qword": setWordSize(.qword)
        case "word.dword": setWordSize(.dword)
        case "word.word": setWordSize(.word)
        case "word.byte": setWordSize(.byte)
        case "history": togglePanel(.history)
        case "mlist": togglePanel(.memory)
        case "history.clear": clearHistory(nil)
        case "mc": memoryCommand(.memoryClear, "mc")
        case "mr": memoryCommand(.memoryRecall, "mr")
        case "m+": memoryCommand(.memoryAdd, "m+")
        case "m-": memoryCommand(.memorySubtract, "m-")
        case "ms": memoryCommand(.memoryStore, "ms")
        case "fe":
            guard mode == .scientific else { return false }
            notationButton.flash()
            press(.toggleNotation)
        default:
            if let function = KeypadLayout.menuFunction(command, mode: mode) {
                press(function.key)
                return true
            }
            let secondFace = command.hasSuffix(".second")
            let id = secondFace ? String(command.dropLast(7)) : command
            guard let button = key(id), button.isEnabled else { return false }
            button.flash()
            perform(button.spec, secondFace: secondFace ? true : nil)
        }
        return true
    }

    private func memoryCommand(_ key: Key, _ id: String) {
        guard memoryButton(id)?.isEnabled == true else { return }
        memoryButton(id)?.flash()
        let wasOpen = panel
        calculator.press(key)
        // The list stays open while the memory is changed from it.
        if wasOpen == .memory, key != .memoryRecall, calculator.hasMemory { refresh() } else { closePanel(); refresh() }
    }

    func setMode(_ newMode: CalcMode) {
        guard newMode != mode else { return }
        calculator.setMode(newMode)
        AppSettings.defaults.set(newMode.rawValue, forKey: AppSettings.modeKey)
        rebuild()
    }

    func setAngleUnit(_ unit: AngleUnit) {
        calculator.angleUnit = unit
        AppSettings.defaults.set(unit.rawValue, forKey: AppSettings.angleUnitKey)
        refresh()
    }

    func setRadix(_ radix: Radix) {
        calculator.setRadix(radix)
        refresh()
    }

    func setWordSize(_ size: WordSize) {
        calculator.setWordSize(size)
        layout()
        refresh()
    }

    func setShowsBits(_ on: Bool) {
        guard mode == .programmer else { return }
        showsBits = on
        layout()
        refresh()
    }

    func setDigitGrouping(_ on: Bool) {
        calculator.format.grouping = on
        AppSettings.defaults.set(on, forKey: AppSettings.digitGroupingKey)
        settingsWindow?.sync()
        refresh()
    }

    // MARK: History and memory

    func togglePanel(_ kind: Panel) {
        if panel == kind {
            closePanel()
            return
        }
        guard kind == .memory ? calculator.hasMemory : mode != .programmer else { return }
        panel = kind
        if listPanel.superview == nil { host.addSubview(listPanel) }
        listPanel.clearButton.setAccessibilityLabel(L(kind == .history ? "menu.clearHistory" : "menu.clearMemory"))
        listPanel.clearButton.toolTip = L(kind == .history ? "menu.clearHistory" : "menu.clearMemory")
        layout()
        refresh()
    }

    func closePanel() {
        guard panel != nil else { return }
        panel = nil
        listPanel.removeFromSuperview()
        refresh()
    }

    private func chooseListRow(_ index: Int) {
        if panel == .history {
            let items = Array(calculator.history.reversed())
            guard items.indices.contains(index) else { return }
            calculator.recall(items[index])
        } else {
            calculator.recallMemory(at: index)
        }
        closePanel()
        refresh()
    }

    // MARK: Menus of the window

    /// The button with three lines: the modes, and what the window has no other place for.
    func makeModeMenu() -> NSMenu {
        let menu = NSMenu()
        for (index, name) in Self.modeNames.enumerated() {
            let item = menu.addItem(withTitle: L(name), action: #selector(chooseMode(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = index == mode.rawValue ? .on : .off
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: L("menu.settings"), action: #selector(openAppSettings(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: L("menu.about"), action: #selector(showAboutPanel(_:)), keyEquivalent: "").target = self
        return menu
    }

    private func showModeMenu() {
        makeModeMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: menuButton.bounds.maxY + 2), in: menuButton)
    }

    func makeFunctionMenu(_ groups: [[MenuFunction]]) -> NSMenu {
        let menu = NSMenu()
        for (index, group) in groups.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            for function in group {
                let item = menu.addItem(withTitle: function.title, action: #selector(chooseFunction(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = function.id
            }
        }
        return menu
    }

    private func showFunctionMenu(_ groups: [[MenuFunction]], from button: NSView?) {
        guard let button else { return }
        makeFunctionMenu(groups).popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 2), in: button)
    }

    @objc func chooseFunction(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { run(id) }
    }

    // MARK: Menu commands

    @objc func chooseMode(_ sender: NSMenuItem) {
        if let chosen = CalcMode(rawValue: sender.tag) { setMode(chosen) }
    }

    @objc func toggleHistory(_ sender: Any?) { togglePanel(.history) }

    @objc func toggleMemoryList(_ sender: Any?) { togglePanel(.memory) }

    @objc func toggleDigitGrouping(_ sender: Any?) { setDigitGrouping(!calculator.format.grouping) }

    @objc func toggleKeepOnTop(_ sender: Any?) {
        window.level = isKeptOnTop ? .normal : .floating
        refresh()
    }

    @objc func clearHistory(_ sender: Any?) {
        calculator.clearHistory()
        refresh()
    }

    @objc func clearMemory(_ sender: Any?) {
        calculator.press(.memoryClear)
        closePanel()
        refresh()
    }

    @objc func copyHistory(_ sender: Any?) {
        let lines = calculator.history.map { $0.expression + " " + calculator.format.string($0.value, grouping: false) }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lines.joined(separator: "\n"), forType: .string)
    }

    @objc func copy(_ sender: Any?) {
        guard calculator.error == nil else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(calculator.copyText, forType: .string)
    }

    @objc func paste(_ sender: Any?) {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        calculator.paste(String(text.prefix(2000)))
        second = false
        closePanel()
        refresh()
    }

    @objc func openAppSettings(_ sender: Any?) {
        let settings = settingsWindow ?? SettingsWindow(controller: self)
        settingsWindow = settings
        settings.sync()
        centerDialog(settings.window)
        settings.window.makeKeyAndOrderFront(nil)
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(chooseMode(_:)):
            item.state = item.tag == mode.rawValue ? .on : .off
        case #selector(toggleHistory(_:)):
            item.state = panel == .history ? .on : .off
            return mode != .programmer
        case #selector(toggleMemoryList(_:)):
            item.state = panel == .memory ? .on : .off
            return calculator.hasMemory
        case #selector(toggleDigitGrouping(_:)):
            item.state = calculator.format.grouping ? .on : .off
        case #selector(toggleKeepOnTop(_:)):
            item.state = isKeptOnTop ? .on : .off
        case #selector(copyHistory(_:)), #selector(clearHistory(_:)):
            return !calculator.history.isEmpty
        case #selector(clearMemory(_:)):
            return calculator.hasMemory
        case #selector(copy(_:)):
            return calculator.error == nil
        case #selector(paste(_:)):
            return NSPasteboard.general.string(forType: .string) != nil
        default: break
        }
        return true
    }

    func makeEditMenu() -> NSMenu {
        let menu = NSMenu(title: L("menu.edit"))
        menu.addItem(withTitle: L("menu.copy"), action: #selector(copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: L("menu.paste"), action: #selector(paste(_:)), keyEquivalent: "v")
        menu.addItem(.separator())
        menu.addItem(withTitle: L("menu.copyHistory"), action: #selector(copyHistory(_:)), keyEquivalent: "")
        menu.addItem(withTitle: L("menu.clearHistory"), action: #selector(clearHistory(_:)), keyEquivalent: "D")
        menu.addItem(withTitle: L("menu.clearMemory"), action: #selector(clearMemory(_:)), keyEquivalent: "")
        return menu
    }

    func makeViewMenu() -> NSMenu {
        let menu = NSMenu(title: L("menu.view"))
        for (index, name) in Self.modeNames.enumerated() {
            let item = menu.addItem(withTitle: L(name), action: #selector(chooseMode(_:)), keyEquivalent: String(index + 1))
            item.tag = index
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: L("menu.showHistory"), action: #selector(toggleHistory(_:)), keyEquivalent: "y")
        menu.addItem(withTitle: L("menu.showMemory"), action: #selector(toggleMemoryList(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L("header.keepOnTop"), action: #selector(toggleKeepOnTop(_:)), keyEquivalent: "t")
        menu.addItem(withTitle: L("menu.digitGrouping"), action: #selector(toggleDigitGrouping(_:)), keyEquivalent: "")
        return menu
    }

    // MARK: Window

    func windowDidMove(_ notification: Notification) {
        let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
        AppSettings.defaults.set(NSStringFromPoint(topLeft), forKey: AppSettings.windowOriginKey)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        // The keyboard goes to the keypad, whatever was clicked before.
        if window.firstResponder !== host { window.makeFirstResponder(host) }
    }
}
