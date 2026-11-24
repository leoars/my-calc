import Foundation

enum KeyKind {
    /// Digits, the sign and the decimal separator: the lighter keys.
    case digit
    case function
    /// The four operations, drawn larger.
    case operation
    /// The equals key, in the accent colour.
    case accent
}

/// One key of the keypad: what it shows, what it asks of the calculator and, for the keys that
/// change with 2nd, the other face.
struct KeySpec {
    struct Second {
        let title: String
        let key: Key
    }

    let id: String
    let title: String
    let key: Key?
    var kind = KeyKind.function
    var second: Second?

    init(_ id: String, _ title: String, _ key: Key?, kind: KeyKind = .function, second: Second? = nil) {
        self.id = id
        self.title = title
        self.key = key
        self.kind = kind
        self.second = second
    }
}

/// A function that is not on the keypad: it lives in a menu of the window and has a shortcut.
struct MenuFunction {
    let id: String
    let title: String
    let key: Key
}

/// The keys of a mode, row by row; every row has the same number of keys.
struct KeypadLayout {
    let rows: [[KeySpec]]

    var columns: Int { rows.first?.count ?? 0 }
    var keys: [KeySpec] { rows.flatMap { $0 } }

    static func layout(for mode: CalcMode, decimalSeparator: String) -> KeypadLayout {
        switch mode {
        case .standard: return KeypadLayout(rows: standard(decimalSeparator))
        case .scientific: return KeypadLayout(rows: scientific(decimalSeparator))
        case .programmer: return KeypadLayout(rows: programmer(decimalSeparator))
        }
    }

    private static func digit(_ value: Int) -> KeySpec {
        let name = String(value, radix: 16, uppercase: true)
        return KeySpec(name, name, .digit(value), kind: .digit)
    }

    private static let backspace = KeySpec("backspace", "⌫", .backspace)
    private static let divide = KeySpec("divide", "÷", .binary(.divide), kind: .operation)
    private static let multiply = KeySpec("multiply", "×", .binary(.multiply), kind: .operation)
    private static let subtract = KeySpec("subtract", "−", .binary(.subtract), kind: .operation)
    private static let add = KeySpec("add", "+", .binary(.add), kind: .operation)
    private static let equals = KeySpec("equals", "=", .equals, kind: .accent)
    private static let negate = KeySpec("negate", "+/−", .negate, kind: .digit)

    private static func decimal(_ separator: String) -> KeySpec { KeySpec("decimal", separator, .decimal, kind: .digit) }

    private static func standard(_ separator: String) -> [[KeySpec]] {
        [
            [KeySpec("percent", "%", .percent), KeySpec("ce", "CE", .clearEntry), KeySpec("c", "C", .clear), backspace],
            [KeySpec("reciprocal", "¹⁄ₓ", .unary(.reciprocal)), KeySpec("square", "x²", .unary(.square)),
             KeySpec("sqrt", "²√x", .unary(.sqrt)), divide],
            [digit(7), digit(8), digit(9), multiply],
            [digit(4), digit(5), digit(6), subtract],
            [digit(1), digit(2), digit(3), add],
            [negate, digit(0), decimal(separator), equals],
        ]
    }

    private static func scientific(_ separator: String) -> [[KeySpec]] {
        [
            [KeySpec("second", "2ⁿᵈ", nil), KeySpec("pi", "π", .pi), KeySpec("e", "e", .euler),
             KeySpec("c", "C", .clearSmart), backspace],
            [KeySpec("square", "x²", .unary(.square), second: .init(title: "x³", key: .unary(.cube))),
             KeySpec("reciprocal", "¹⁄ₓ", .unary(.reciprocal)), KeySpec("abs", "|x|", .unary(.abs)),
             KeySpec("exp", "exp", .exponent), KeySpec("mod", "mod", .binary(.modulo))],
            [KeySpec("sqrt", "²√x", .unary(.sqrt), second: .init(title: "³√x", key: .unary(.cubeRoot))),
             KeySpec("open", "(", .openParen), KeySpec("close", ")", .closeParen),
             KeySpec("factorial", "n!", .unary(.factorial)), divide],
            [KeySpec("power", "xʸ", .binary(.power), second: .init(title: "ʸ√x", key: .binary(.root))),
             digit(7), digit(8), digit(9), multiply],
            [KeySpec("pow10", "10ˣ", .unary(.powerOfTen), second: .init(title: "2ˣ", key: .unary(.powerOfTwo))),
             digit(4), digit(5), digit(6), subtract],
            [KeySpec("log", "log", .unary(.log), second: .init(title: "logᵧx", key: .binary(.logBase))),
             digit(1), digit(2), digit(3), add],
            [KeySpec("ln", "ln", .unary(.ln), second: .init(title: "eˣ", key: .unary(.exp))),
             negate, digit(0), decimal(separator), equals],
        ]
    }

    private static func programmer(_ separator: String) -> [[KeySpec]] {
        [
            [digit(10), KeySpec("lsh", "<<", .binary(.shiftLeft)), KeySpec("rsh", ">>", .binary(.shiftRight)),
             KeySpec("c", "C", .clearSmart), backspace],
            [digit(11), KeySpec("open", "(", .openParen), KeySpec("close", ")", .closeParen),
             KeySpec("mod", "%", .binary(.modulo)), divide],
            [digit(12), digit(7), digit(8), digit(9), multiply],
            [digit(13), digit(4), digit(5), digit(6), subtract],
            [digit(14), digit(1), digit(2), digit(3), add],
            [digit(15), negate, digit(0), decimal(separator), equals],
        ]
    }

    /// The Trigonometry menu of the scientific mode, in its four groups.
    static let trigonometry: [[MenuFunction]] = [
        [MenuFunction(id: "fn.sin", title: "sin", key: .unary(.sin)), MenuFunction(id: "fn.cos", title: "cos", key: .unary(.cos)),
         MenuFunction(id: "fn.tan", title: "tan", key: .unary(.tan)), MenuFunction(id: "fn.sec", title: "sec", key: .unary(.sec)),
         MenuFunction(id: "fn.csc", title: "csc", key: .unary(.csc)), MenuFunction(id: "fn.cot", title: "cot", key: .unary(.cot))],
        [MenuFunction(id: "fn.asin", title: "sin⁻¹", key: .unary(.asin)), MenuFunction(id: "fn.acos", title: "cos⁻¹", key: .unary(.acos)),
         MenuFunction(id: "fn.atan", title: "tan⁻¹", key: .unary(.atan)), MenuFunction(id: "fn.asec", title: "sec⁻¹", key: .unary(.asec)),
         MenuFunction(id: "fn.acsc", title: "csc⁻¹", key: .unary(.acsc)), MenuFunction(id: "fn.acot", title: "cot⁻¹", key: .unary(.acot))],
        [MenuFunction(id: "fn.sinh", title: "sinh", key: .unary(.sinh)), MenuFunction(id: "fn.cosh", title: "cosh", key: .unary(.cosh)),
         MenuFunction(id: "fn.tanh", title: "tanh", key: .unary(.tanh)), MenuFunction(id: "fn.sech", title: "sech", key: .unary(.sech)),
         MenuFunction(id: "fn.csch", title: "csch", key: .unary(.csch)), MenuFunction(id: "fn.coth", title: "coth", key: .unary(.coth))],
        [MenuFunction(id: "fn.asinh", title: "sinh⁻¹", key: .unary(.asinh)), MenuFunction(id: "fn.acosh", title: "cosh⁻¹", key: .unary(.acosh)),
         MenuFunction(id: "fn.atanh", title: "tanh⁻¹", key: .unary(.atanh)), MenuFunction(id: "fn.asech", title: "sech⁻¹", key: .unary(.asech)),
         MenuFunction(id: "fn.acsch", title: "csch⁻¹", key: .unary(.acsch)), MenuFunction(id: "fn.acoth", title: "coth⁻¹", key: .unary(.acoth))],
    ]

    /// The Function menu of the scientific mode.
    static let functions: [[MenuFunction]] = [
        [MenuFunction(id: "fn.abs", title: "|x|", key: .unary(.abs)), MenuFunction(id: "fn.floor", title: "⌊x⌋", key: .unary(.floor)),
         MenuFunction(id: "fn.ceil", title: "⌈x⌉", key: .unary(.ceiling)), MenuFunction(id: "fn.rand", title: "rand", key: .random)],
        [MenuFunction(id: "fn.dms", title: "→ dms", key: .unary(.dms)), MenuFunction(id: "fn.deg", title: "→ deg", key: .unary(.degrees))],
    ]

    /// The Bitwise menu of the programmer mode.
    static let bitwise: [[MenuFunction]] = [
        [MenuFunction(id: "fn.and", title: "AND", key: .binary(.and)), MenuFunction(id: "fn.or", title: "OR", key: .binary(.or)),
         MenuFunction(id: "fn.not", title: "NOT", key: .unary(.not)), MenuFunction(id: "fn.nand", title: "NAND", key: .binary(.nand)),
         MenuFunction(id: "fn.nor", title: "NOR", key: .binary(.nor)), MenuFunction(id: "fn.xor", title: "XOR", key: .binary(.xor))],
        [MenuFunction(id: "fn.rol", title: "RoL", key: .unary(.rotateLeft)), MenuFunction(id: "fn.ror", title: "RoR", key: .unary(.rotateRight))],
    ]

    static func menuFunction(_ id: String, mode: CalcMode) -> MenuFunction? {
        let groups = mode == .scientific ? trigonometry + functions : mode == .programmer ? bitwise : []
        return groups.flatMap { $0 }.first { $0.id == id }
    }
}

/// The keyboard: which key of the keypad, which function of a menu or which command of the
/// window a key press means. The answers are the ids of `KeySpec` and `MenuFunction`, or
/// commands named `mode.…`, `angle.…`, `radix.…`, `word.…`, `history` and `history.clear`.
enum KeyboardMap {
    static func command(characters: String, keyCode: UInt16, control: Bool, option: Bool, shift: Bool, mode: CalcMode) -> String? {
        let text = characters.lowercased()
        if option {
            switch keyCode {
            case 18: return "mode.standard"
            case 19: return "mode.scientific"
            case 20, 21: return "mode.programmer"
            default: return nil
            }
        }
        if control {
            switch (text, mode) {
            case ("l", _): return "mc"
            case ("r", _): return "mr"
            case ("m", _): return "ms"
            case ("p", _): return "m+"
            case ("q", _): return "m-"
            case ("h", _): return "history"
            case ("d", _) where shift: return "history.clear"
            case ("s", .scientific): return "fn.sinh"
            case ("o", .scientific): return "fn.cosh"
            case ("t", .scientific): return "fn.tanh"
            case ("y", .scientific): return "power.second"
            case ("b", .scientific): return "sqrt.second"
            case ("g", .scientific): return "pow10"
            case ("n", .scientific): return "ln.second"
            default: return nil
            }
        }
        // Keys without a character of their own.
        switch keyCode {
        case 36, 76: return "equals"
        case 51: return "backspace"
        case 53: return "c"
        case 117: return mode == .standard ? "ce" : "c"
        case 101: return "negate"  // F9
        case 99: return mode == .scientific ? "angle.degrees" : (mode == .programmer ? "word.word" : nil)  // F3
        case 118: return mode == .scientific ? "angle.radians" : (mode == .programmer ? "word.byte" : nil)  // F4
        case 96: return mode == .scientific ? "angle.grads" : (mode == .programmer ? "radix.hex" : nil)  // F5
        case 97: return mode == .programmer ? "radix.dec" : nil  // F6
        case 98: return mode == .programmer ? "radix.oct" : nil  // F7
        case 100: return mode == .programmer ? "radix.bin" : nil  // F8
        case 111: return mode == .programmer ? "word.qword" : nil  // F12
        case 120: return mode == .programmer ? "word.dword" : nil  // F2
        default: break
        }
        if let character = text.first, text.count == 1, character.isASCII, character.isNumber { return text }
        switch text {
        case "+": return "add"
        case "-": return "subtract"
        case "*": return "multiply"
        case "/": return "divide"
        case "=": return "equals"
        default: break
        }
        switch mode {
        case .standard:
            switch text {
            case ".", ",": return "decimal"
            case "%": return "percent"
            case "r": return "reciprocal"
            case "@": return "sqrt"
            case "q": return "square"
            default: return nil
            }
        case .scientific:
            switch text {
            case ".", ",": return "decimal"
            case "(": return "open"
            case ")": return "close"
            case "r": return "reciprocal"
            case "@": return "sqrt"
            case "q": return "square"
            case "#": return "square.second"
            case "y", "^": return "power"
            case "s": return shift ? "fn.asin" : "fn.sin"
            case "o": return shift ? "fn.acos" : "fn.cos"
            case "t": return shift ? "fn.atan" : "fn.tan"
            case "u": return shift ? "fn.asec" : "fn.sec"
            case "i": return shift ? "fn.acsc" : "fn.csc"
            case "j": return shift ? "fn.acot" : "fn.cot"
            case "n": return "ln"
            case "l": return "log"
            case "!": return "factorial"
            case "p": return "pi"
            case "e": return "e"
            case "x": return "exp"
            case "d", "%": return "mod"
            case "m": return "fn.dms"
            case "v": return "fe"
            case "|": return "abs"
            case "[": return "fn.floor"
            case "]": return "fn.ceil"
            default: return nil
            }
        case .programmer:
            switch text {
            case "a", "b", "c", "d", "e", "f": return text.uppercased()
            case "(": return "open"
            case ")": return "close"
            case "%": return "mod"
            case "&": return "fn.and"
            case "|": return "fn.or"
            case "^": return "fn.xor"
            case "~": return "fn.not"
            case ".": return "fn.nand"
            case ",": return "fn.nor"
            case "<": return "lsh"
            case ">": return "rsh"
            case "j": return "fn.rol"
            case "k": return "fn.ror"
            default: return nil
            }
        }
    }
}
