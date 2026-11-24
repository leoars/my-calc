import AppKit

/// The keyboard: each key press is a key of the keypad, a function or a command of the window.
func runKeyboardTests() {
    func command(_ characters: String, code: UInt16 = 0, control: Bool = false, option: Bool = false, shift: Bool = false,
                 _ mode: CalcMode = .standard) -> String {
        KeyboardMap.command(characters: characters, keyCode: code, control: control, option: option, shift: shift, mode: mode) ?? "-"
    }
    expect(["7", "+", "-", "*", "/", "=", ".", ","].map { command($0) }.joined(separator: " "),
           "7 add subtract multiply divide equals decimal decimal", "digits, operators and both decimal signs")
    expect([36, 76, 51, 53, 117, 101].map { command("", code: $0) }.joined(separator: " "), "equals equals backspace c ce negate",
           "Return, Enter, Backspace, Esc, Delete and F9")
    expect(["l", "r", "m", "p", "q"].map { command($0, control: true) }.joined(separator: " "), "mc mr ms m+ m-", "the memory with Control")
    expect(command("h", control: true) + " " + command("d", control: true, shift: true) + " " + command("d", control: true), "history history.clear -",
           "the history with Control")
    expect([18, 19, 20, 21].map { command("", code: $0, option: true) }.joined(separator: " "),
           "mode.standard mode.scientific mode.programmer mode.programmer", "Option with a digit chooses the mode")
    expect(command("r") + " " + command("@") + " " + command("%") + " " + command("q") + " " + command("s"), "reciprocal sqrt percent square -", "the standard mode")
    expect(["s", "o", "t", "u", "i", "j"].map { command($0, .scientific) }.joined(separator: " ") + " "
           + ["s", "o", "t"].map { command($0, shift: true, .scientific) }.joined(separator: " ") + " "
           + ["s", "o", "t"].map { command($0, control: true, .scientific) }.joined(separator: " "),
           "fn.sin fn.cos fn.tan fn.sec fn.csc fn.cot fn.asin fn.acos fn.atan fn.sinh fn.cosh fn.tanh", "trigonometry by letter, with Shift and with Control")
    expect(["n", "l", "q", "#", "y", "^", "!", "p", "e", "x", "d", "m", "v", "|", "[", "]", "(", ")"].map { command($0, .scientific) }.joined(separator: " "),
           "ln log square square.second power power factorial pi e exp mod fn.dms fe abs fn.floor fn.ceil open close", "the letters of the scientific mode")
    expect(["y", "b", "g", "n"].map { command($0, control: true, .scientific) }.joined(separator: " "), "power.second sqrt.second pow10 ln.second",
           "the other faces of the keys with Control")
    expect([99, 118, 96].map { command("", code: $0, .scientific) }.joined(separator: " "), "angle.degrees angle.radians angle.grads", "F3, F4 and F5 choose the angle unit")
    expect(["a", "F", "%", "&", "|", "^", "~", ".", ",", "<", ">", "j", "k"].map { command($0, .programmer) }.joined(separator: " "),
           "A F mod fn.and fn.or fn.xor fn.not fn.nand fn.nor lsh rsh fn.rol fn.ror", "the programmer mode")
    expect([96, 97, 98, 100, 111, 120, 99, 118].map { command("", code: $0, .programmer) }.joined(separator: " "),
           "radix.hex radix.dec radix.oct radix.bin word.qword word.dword word.word word.byte", "the function keys choose the base and the word")
}

/// The window: the layout of each mode, and the keys reaching the calculator.
func runWindowTests() {
    AppSettings.defaults.removeObject(forKey: AppSettings.modeKey)
    let controller = MainWindowController()
    let window = controller.window
    defer { window.close() }
    let content = window.contentView!
    check(controller.mode == .standard && window.title == "My Calc" && controller.titleLabel.stringValue == "Standard",
          "the window opens in the standard mode, with its name in the header")
    check(controller.calculator.format.grouping, "digits are grouped unless turned off")

    // The standard keypad, key by key, as in the layout the app follows.
    func titles(_ rows: Int, _ columns: Int) -> String {
        (0..<rows).map { row in controller.keys[(row * columns)..<((row + 1) * columns)].map(\.title).joined(separator: " ") }.joined(separator: " | ")
    }
    expect(titles(6, 4), "% CE C ⌫ | ¹⁄ₓ x² ²√x ÷ | 7 8 9 × | 4 5 6 − | 1 2 3 + | +/− 0 . =", "standard: six rows of four keys")
    let kinds = controller.keys.map(\.spec.kind)
    check(kinds.filter { $0 == .digit }.count == 12 && kinds.filter { $0 == .accent }.count == 1 && controller.keys.last?.spec.id == "equals",
          "digits, sign and decimal separator are the lighter keys; equals is the accent one, at the bottom right")
    check(controller.memoryButtons.map(\.title) == ["MC", "MR", "M+", "M−", "MS", "M"] && controller.memoryButtons.last?.showsArrow == true,
          "the memory row: MC, MR, M+, M−, MS and the list")
    check(!controller.memoryButton("mc")!.isEnabled && !controller.memoryButton("mr")!.isEnabled && !controller.memoryButton("mlist")!.isEnabled
          && controller.memoryButton("ms")!.isEnabled && controller.memoryButton("m+")!.isEnabled, "MC, MR and the list are dimmed while the memory is empty")
    check(controller.menuButton.frame.minX < controller.titleLabel.frame.minX && controller.titleLabel.frame.maxX < controller.keepOnTopButton.frame.minX
          && controller.historyButton.frame.maxX > content.bounds.width - 12 && controller.menuButton.frame.midY < controller.display.frame.minY,
          "the header: menu, mode name, keep on top, and the history at the right")
    let memoryRow = controller.memoryButtons[0].frame
    check(controller.display.frame.maxY <= memoryRow.minY && memoryRow.maxY <= controller.keys[0].frame.minY, "display, memory row and keys from the top down")

    var sizes: [CalcMode: NSSize] = [:]
    for (mode, rows, columns) in [(CalcMode.standard, 6, 4), (.scientific, 7, 5), (.programmer, 6, 5)] {
        controller.setMode(mode)
        sizes[mode] = content.bounds.size
        check(content.bounds.size == controller.defaultSize(for: mode) && window.contentMinSize == controller.defaultSize(for: mode),
              "\(mode): the window takes the size of the mode, which is its smallest")
        for grown in [false, true] {
            if grown { window.setContentSize(NSSize(width: 520, height: 800)) }
            let frames = controller.keys.map(\.frame)
            let label = "\(mode)\(grown ? ", enlarged" : "")"
            check(frames.count == rows * columns && Set(controller.keys.map(\.spec.id)).count == frames.count, "\(label): \(rows) × \(columns) keys, each with its id")
            check(frames.allSatisfy { content.bounds.insetBy(dx: Theme.margin - 0.5, dy: Theme.margin - 0.5).contains($0) }, "\(label): the keys are inside the window")
            var apart = true
            for (index, first) in frames.enumerated() { for second in frames[(index + 1)...] where first.insetBy(dx: -0.5, dy: -0.5).intersects(second) { apart = false } }
            check(apart, "\(label): no key touches another")
            check(abs(frames.last!.maxY - (content.bounds.height - Theme.margin)) <= 1 && abs(frames.last!.maxX - (content.bounds.width - Theme.margin)) <= 1
                  && abs(frames[0].minX - Theme.margin) <= 1, "\(label): the keys fill the window to its margins")
            let widths = frames.map(\.width), heights = frames.map(\.height)
            check(widths.max()! - widths.min()! <= 1 && heights.max()! - heights.min()! <= 1, "\(label): all the keys have the same size")
        }
        check(AppSettings.defaults.integer(forKey: AppSettings.modeKey) == mode.rawValue, "\(mode): the mode is remembered")
    }
    check(sizes[.scientific]!.height > sizes[.standard]!.height && sizes[.standard]!.width == Theme.defaultWidth, "the scientific mode is taller")

    // Standard.
    controller.setMode(.standard)
    for id in ["1", "2", "decimal", "5", "add", "3", "equals"] { controller.run(id) }
    expect(controller.display.text + "|" + controller.display.expression, "15.5|12.5 + 3 =", "keys reach the display, and the calculation shows above the result")
    controller.run("ms")
    check(controller.memoryButton("mc")!.isEnabled && controller.memoryButton("mr")!.isEnabled && controller.memoryButton("mlist")!.isEnabled,
          "with a number kept, the whole memory row is on")
    controller.run("divide")
    controller.run("0")
    controller.run("equals")
    expect(controller.display.text, "Cannot divide by zero", "an error shows its message")
    controller.run("c")
    expect(controller.display.text, "0", "C clears it")
    check(!controller.run("fn.sin") && !controller.run("A") && !controller.run("open") && !controller.run("fe"), "what belongs to other modes is not there")
    let wide = "8,888,888,888,888,888,888,888,888,888,888,888,888,888"
    let room = controller.display.bounds.width - 2 * DisplayView.inset
    let fitted = controller.display.fittedFontSize(for: wide, width: room)
    check(fitted < Theme.displayFontSize && (wide as NSString).size(withAttributes: [.font: Theme.displayFont(fitted)]).width <= room,
          "32 digits shrink to fit the display")
    check(controller.display.fittedFontSize(for: "0", width: room) == Theme.displayFontSize, "a short number has the full size")

    // Memory and history panels.
    controller.run("mlist")
    check(controller.panel == .memory && controller.listPanel.superview != nil && controller.listPanel.rows == [ListRow(value: "15.5")]
          && controller.listPanel.frame.minY >= controller.display.frame.maxY && controller.listPanel.frame.maxY == content.bounds.height,
          "the list of the memory opens over the keys, under the display")
    controller.run("7")
    check(controller.panel == nil && controller.listPanel.superview == nil, "a key closes it")
    controller.run("ms")
    controller.run("mlist")
    check(controller.listPanel.rows.map(\.value) == ["7", "15.5"], "the newest number first")
    controller.listPanel.onSelect?(1)
    expect(controller.display.text, "15.5", "a click on a number brings it back")
    controller.run("mlist")
    controller.listPanel.clearButton.onPress?()
    check(!controller.calculator.hasMemory && controller.listPanel.rows.isEmpty && !controller.memoryButton("mr")!.isEnabled, "the bin empties the memory")
    controller.closePanel()
    controller.run("history.clear")
    for id in ["c", "2", "multiply", "3", "equals", "1", "add", "1", "equals"] { controller.run(id) }
    controller.run("history")
    check(controller.panel == .history && controller.historyButton.isChecked
          && controller.listPanel.rows == [ListRow(detail: "1 + 1 =", value: "2"), ListRow(detail: "2 × 3 =", value: "6")],
          "the history lists each calculation with its result, the newest first")
    controller.listPanel.onSelect?(1)
    check(controller.display.text == "6" && controller.panel == nil, "a click on a line brings its result back and closes the list")
    controller.run("history")
    controller.listPanel.clearButton.onPress?()
    check(controller.calculator.history.isEmpty && controller.listPanel.clearButton.isHidden, "the bin clears the history")
    controller.run("history")
    check(controller.panel == nil, "the history button closes the list too")

    // Keep on top.
    controller.keepOnTopButton.onPress?()
    check(controller.isKeptOnTop && controller.keepOnTopButton.isChecked, "Keep on Top keeps the window above the others")
    controller.toggleKeepOnTop(nil)
    check(!controller.isKeptOnTop && !controller.keepOnTopButton.isChecked, "and lets it go")

    // Scientific.
    controller.setMode(.scientific)
    expect(titles(7, 5), "2ⁿᵈ π e C ⌫ | x² ¹⁄ₓ |x| exp mod | ²√x ( ) n! ÷ | xʸ 7 8 9 × | 10ˣ 4 5 6 − | log 1 2 3 + | ln +/− 0 . =",
           "scientific: seven rows of five keys")
    check(!controller.angleButton.isHidden && controller.angleButton.title == "DEG" && !controller.trigonometryButton.isHidden
          && controller.trigonometryButton.title == "Trigonometry" && controller.functionButton.title == "Function" && controller.baseRows.isHidden,
          "scientific: the angle unit, F-E and the two menus of functions")
    for id in ["3", "0"] { controller.run(id) }
    expect(controller.key("c")!.title, "CE", "while a number is typed the clear key is CE")
    controller.run("fn.sin")
    expect(controller.display.text + " " + controller.display.expression + " " + controller.key("c")!.title, "0.5 sin(30) C", "the sine of 30 degrees, from the menu")
    controller.run("second")
    check(controller.second && controller.key("second")!.isChecked && controller.key("square")!.title == "x³" && controller.key("sqrt")!.title == "³√x"
          && controller.key("power")!.title == "ʸ√x" && controller.key("pow10")!.title == "2ˣ" && controller.key("log")!.title == "logᵧx"
          && controller.key("ln")!.title == "eˣ", "2nd shows the other face of the keys")
    for id in ["c", "2", "square"] { controller.run(id) }
    expect(controller.display.text, "8", "and the key does what it shows")
    controller.run("second")
    check(!controller.second && controller.key("square")!.title == "x²", "2nd again brings the first faces back")
    for id in ["c", "2", "7", "sqrt.second"] { controller.run(id) }
    expect(controller.display.text, "3", "a shortcut reaches the other face directly")
    controller.angleButton.onPress?()
    check(controller.calculator.angleUnit == .radians && controller.angleButton.title == "RAD", "the angle button goes from DEG to RAD")
    controller.run("angle.grads")
    check(controller.angleButton.title == "GRAD", "and the keyboard chooses the unit too")
    controller.run("angle.degrees")
    for id in ["c", "1", "divide", "8", "equals", "fe"] { controller.run(id) }
    check(controller.display.text == "1.25e-1" && controller.notationButton.isChecked, "F-E shows the exponent form")
    controller.run("fe")
    let trigonometry = controller.makeFunctionMenu(KeypadLayout.trigonometry), functions = controller.makeFunctionMenu(KeypadLayout.functions)
    check(trigonometry.items.filter { !$0.isSeparatorItem }.count == 24 && trigonometry.items.first?.title == "sin"
          && functions.items.filter { !$0.isSeparatorItem }.map(\.title) == ["|x|", "⌊x⌋", "⌈x⌉", "rand", "→ dms", "→ deg"],
          "the Trigonometry menu has its 24 functions, the Function menu its six")
    for id in ["c", "2", "decimal", "5"] { controller.run(id) }
    controller.chooseFunction(functions.items[2])
    expect(controller.display.text, "3", "a function chosen from the menu is applied")
    for id in ["c", "open", "1", "add", "2", "close", "multiply", "3", "equals"] { controller.run(id) }
    expect(controller.display.text, "9", "parentheses from the keypad")

    // Programmer.
    controller.setMode(.programmer)
    expect(titles(6, 5), "A << >> C ⌫ | B ( ) % ÷ | C 7 8 9 × | D 4 5 6 − | E 1 2 3 + | F +/− 0 . =", "programmer: six rows of five keys")
    check(!controller.baseRows.isHidden && controller.baseRows.selected == 1 && controller.wordButton.title == "QWORD" && controller.historyButton.isHidden
          && controller.memoryButtons.filter { !$0.isHidden }.map(\.id) == ["ms", "mlist"] && controller.bitPanel.isHidden,
          "programmer: the four bases, the word size, MS and the list of the memory")
    check(!controller.key("A")!.isEnabled && !controller.key("F")!.isEnabled && controller.key("9")!.isEnabled && !controller.key("decimal")!.isEnabled,
          "in decimal the letters and the decimal separator are off")
    controller.run("radix.hex")
    check(controller.key("A")!.isEnabled && controller.key("F")!.isEnabled && controller.baseRows.selected == 0, "in hexadecimal the letters are on")
    for id in ["c", "F", "F"] { controller.run(id) }
    check(controller.baseRows.values == ["FF", "255", "377", "1111 1111"] && controller.display.text == "FF", "the number shows in the four bases at once")
    controller.baseRows.onChoose?(3)
    check(controller.calculator.radix == .bin && controller.display.text == "1111 1111" && !controller.key("2")!.isEnabled && !controller.run("2"),
          "a click on a base chooses it; in binary only 0 and 1 are on")
    controller.run("radix.dec")
    for id in ["fn.and", "1", "5", "equals"] { controller.run(id) }
    expect(controller.display.text, "15", "a function of the Bitwise menu")
    check(controller.makeFunctionMenu(KeypadLayout.bitwise).items.filter { !$0.isSeparatorItem }.map(\.title) == ["AND", "OR", "NOT", "NAND", "NOR", "XOR", "RoL", "RoR"],
          "the Bitwise menu")
    controller.bitsButton.onPress?()
    check(controller.showsBits && !controller.bitPanel.isHidden && controller.keys.allSatisfy(\.isHidden) && controller.bitPanel.bits == 15
          && controller.bitsButton.isChecked && !controller.keypadButton.isChecked, "the bits take the place of the keys")
    controller.bitPanel.onToggle?(4)
    expect(controller.display.text, "31", "a click on a bit changes the number")
    controller.run("1")
    expect(controller.display.text, "1", "the keyboard still types while the bits show")
    let bits = (0..<64).map { controller.bitPanel.rect(forBit: $0) }
    check(bits.allSatisfy { controller.bitPanel.bounds.contains($0) } && bits[63].minX < bits[48].minX && bits[63].minY < bits[47].minY
          && bits[15].minY > bits[16].minY && bits[1].minX < bits[0].minX, "the 64 bits in four rows, the highest first")
    controller.keypadButton.onPress?()
    check(!controller.showsBits && controller.bitPanel.isHidden && controller.keys.allSatisfy { !$0.isHidden }, "and the keys come back")
    controller.wordButton.onPress?()
    check(controller.calculator.wordSize == .dword && controller.wordButton.title == "DWORD", "the word button goes from QWORD to DWORD")
    controller.run("word.byte")
    for id in ["c", "1", "2", "7", "add", "1", "equals"] { controller.run(id) }
    check(controller.display.text == "-128" && controller.bitPanel.wordSize == 8, "a byte wraps around")
    controller.run("word.qword")

    // Grouping, copy and paste.
    controller.setMode(.standard)
    controller.run("c")
    for id in ["1", "2", "3", "4", "5", "6", "7"] { controller.run(id) }
    expect(controller.display.text, "1,234,567", "digits are grouped on the display")
    controller.setDigitGrouping(false)
    check(controller.display.text == "1234567" && AppSettings.defaults.object(forKey: AppSettings.digitGroupingKey) as? Bool == false,
          "grouping can be turned off, and that is remembered")
    controller.setDigitGrouping(true)
    expect(controller.calculator.copyText, "1234567", "Copy takes the number without the grouping")
    controller.run("c")
    controller.calculator.paste("2.5 + 2.5 =")
    controller.refresh()
    expect(controller.display.text, "5", "a pasted calculation runs")

    // Menus.
    let view = controller.makeViewMenu(), edit = controller.makeEditMenu(), modes = controller.makeModeMenu()
    expect(view.items.map { $0.isSeparatorItem ? "-" : $0.title }.joined(separator: "|"),
           "Standard|Scientific|Programmer|-|History|Memory|-|Keep on Top|Digit Grouping", "the View menu")
    expect(edit.items.map { $0.isSeparatorItem ? "-" : $0.title }.joined(separator: "|"), "Copy|Paste|-|Copy History|Clear History|Clear Memory", "the Edit menu")
    expect(modes.items.map { $0.isSeparatorItem ? "-" : $0.title }.joined(separator: "|"), "Standard|Scientific|Programmer|-|Settings…|About My Calc",
           "the menu of the header: the modes, then Settings and About")
    check(modes.items[0].state == .on && modes.items[1].state == .off, "with the current mode ticked")
    check(view.items[0...2].map(\.keyEquivalent) == ["1", "2", "3"], "Command with 1 to 3 chooses the mode")
    check(controller.validateMenuItem(view.items[0]) && view.items[0].state == .on && controller.validateMenuItem(view.items[1]) && view.items[1].state == .off
          && !controller.validateMenuItem(view.items[5]) && !controller.validateMenuItem(edit.items[5]), "the menu bar ticks the mode and dims what has nothing to act on")
    controller.chooseMode(view.items[2])
    check(controller.mode == .programmer && !controller.validateMenuItem(view.items[4]), "the menu changes the mode; there is no history in the programmer mode")
    controller.setMode(.standard)

    // Light and dark.
    func resolved(_ color: NSColor, _ name: NSAppearance.Name) -> NSColor {
        var result = NSColor.clear
        NSAppearance(named: name)!.performAsCurrentDrawingAppearance { result = color.usingColorSpace(.sRGB)! }
        return result
    }
    func luminance(_ color: NSColor) -> CGFloat { 0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent }
    check(luminance(resolved(Theme.text, .aqua)) < 0.2 && luminance(resolved(Theme.text, .darkAqua)) > 0.9
          && luminance(resolved(Theme.tint, .aqua)) > 0.85 && luminance(resolved(Theme.tint, .darkAqua)) < 0.2, "dark text on light, light text on dark")
    for name in [NSAppearance.Name.aqua, .darkAqua] {
        check(resolved(Theme.digitFill, name).alphaComponent > resolved(Theme.functionFill, name).alphaComponent, "\(name.rawValue): the digits are lighter than the functions")
        check(abs(luminance(resolved(Theme.accent, name)) - luminance(resolved(Theme.accentText, name))) > 0.35, "\(name.rawValue): the equals sign stands out on the accent colour")
    }

    // Settings.
    let settings = SettingsWindow(controller: controller)
    check(settings.groupingButton.state == .on, "Settings shows digit grouping")
    settings.groupingButton.state = .off
    settings.toggleGrouping(settings.groupingButton)
    check(!controller.calculator.format.grouping, "and turns it off")
    controller.setDigitGrouping(true)
}
