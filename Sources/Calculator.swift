import Foundation

enum CalcMode: Int, CaseIterable {
    case standard, scientific, programmer
}

enum BinaryOp: Equatable {
    case add, subtract, multiply, divide, modulo, power, root, logBase
    case and, or, xor, nand, nor, shiftLeft, shiftRight

    /// Higher binds tighter; the standard mode ignores it and works in the order typed.
    var precedence: Int {
        switch self {
        case .or, .nor: return 1
        case .xor: return 2
        case .and, .nand: return 3
        case .add, .subtract: return 4
        case .multiply, .divide, .modulo: return 5
        case .shiftLeft, .shiftRight: return 6
        case .power, .root, .logBase: return 7
        }
    }

    var symbol: String {
        switch self {
        case .add: return "+"
        case .subtract: return "−"
        case .multiply: return "×"
        case .divide: return "÷"
        case .modulo: return "Mod"
        case .power: return "^"
        case .root: return "yroot"
        case .logBase: return "log base"
        case .and: return "AND"
        case .or: return "OR"
        case .xor: return "XOR"
        case .nand: return "NAND"
        case .nor: return "NOR"
        case .shiftLeft: return "Lsh"
        case .shiftRight: return "Rsh"
        }
    }
}

enum UnaryOp: Equatable {
    case sqrt, reciprocal, square, cube, cubeRoot
    case sin, cos, tan, asin, acos, atan
    case sinh, cosh, tanh, asinh, acosh, atanh
    case sec, csc, cot, asec, acsc, acot
    case sech, csch, coth, asech, acsch, acoth
    case ln, exp, log, powerOfTen, powerOfTwo, factorial
    case integer, fraction, dms, degrees, abs, floor, ceiling
    case not, rotateLeft, rotateRight

    /// How the function is written on the line above the number.
    var name: String {
        switch self {
        case .sqrt: return "√"
        case .reciprocal: return "1/"
        case .square: return "sqr"
        case .cube: return "cube"
        case .cubeRoot: return "³√"
        case .sin: return "sin"
        case .cos: return "cos"
        case .tan: return "tan"
        case .asin: return "sin⁻¹"
        case .acos: return "cos⁻¹"
        case .atan: return "tan⁻¹"
        case .sinh: return "sinh"
        case .cosh: return "cosh"
        case .tanh: return "tanh"
        case .asinh: return "sinh⁻¹"
        case .acosh: return "cosh⁻¹"
        case .atanh: return "tanh⁻¹"
        case .ln: return "ln"
        case .exp: return "e^"
        case .log: return "log"
        case .powerOfTen: return "10^"
        case .powerOfTwo: return "2^"
        case .sec: return "sec"
        case .csc: return "csc"
        case .cot: return "cot"
        case .asec: return "sec⁻¹"
        case .acsc: return "csc⁻¹"
        case .acot: return "cot⁻¹"
        case .sech: return "sech"
        case .csch: return "csch"
        case .coth: return "coth"
        case .asech: return "sech⁻¹"
        case .acsch: return "csch⁻¹"
        case .acoth: return "coth⁻¹"
        case .abs: return "abs"
        case .floor: return "floor"
        case .ceiling: return "ceil"
        case .factorial: return "fact"
        case .integer: return "int"
        case .fraction: return "frac"
        case .dms: return "dms"
        case .degrees: return "deg"
        case .not: return "NOT"
        case .rotateLeft: return "RoL"
        case .rotateRight: return "RoR"
        }
    }
}

/// Everything a key of the calculator can ask for.
enum Key: Equatable {
    case digit(Int)
    case decimal, exponent, negate, backspace
    case clearEntry, clear, clearSmart, equals, percent
    case binary(BinaryOp)
    case unary(UnaryOp)
    case openParen, closeParen
    case pi, twoPi, euler, random
    case memoryClear, memoryRecall, memoryStore, memoryAdd, memorySubtract
    case toggleNotation
}

struct HistoryEntry: Equatable {
    let expression: String
    let value: BigDecimal
}

/// The calculator itself, without any interface: it takes keys and answers what the display
/// shows. The standard mode works in the order the keys are pressed; the scientific and the
/// programmer modes follow the precedence of the operators and take parentheses.
final class Calculator {
    private struct Pending {
        let value: BigDecimal
        let op: BinaryOp
    }

    /// One level of parentheses: the operations waiting for their right side, and their text.
    private struct Frame {
        var pending: [Pending] = []
        var tokens: [String] = []
    }

    static let maximumDepth = 25
    static let maximumHistory = 100

    private(set) var mode: CalcMode
    var angleUnit = AngleUnit.degrees
    private(set) var radix = Radix.dec
    private(set) var wordSize = WordSize.qword
    var format: NumberFormat

    /// The number shown when nothing is being typed.
    private(set) var value = BigDecimal.zero
    private(set) var entry: Entry?
    private(set) var error: CalcError?
    /// The numbers kept with MS, the newest first; MR, M+ and M− work on the newest.
    private(set) var memories: [BigDecimal] = []
    private(set) var history: [HistoryEntry] = []
    /// The F-E key: results in exponent form.
    private(set) var scientificNotation = false

    private var frames = [Frame()]
    /// The text of the operand on the display when it is not a plain number: `√(9)`, `(1 + 2)`.
    private var operandText: String?
    /// False right after an operator or an opening parenthesis: the display still shows the left
    /// side, and the next operator replaces the one just pressed.
    private var operandReady = true
    private var lastRepeat: (op: BinaryOp, operand: BigDecimal)?
    /// The calculation the equals key has just finished, shown until the next key.
    private var finished: String?

    init(mode: CalcMode = .standard, format: NumberFormat = NumberFormat()) {
        self.mode = mode
        self.format = format
    }

    // MARK: What the interface shows

    /// The main line of the display; empty while there is an error (see `error`).
    var displayText: String { text(grouping: nil) }

    /// The same without digit grouping, for Copy.
    var copyText: String { text(grouping: false) }

    private func text(grouping: Bool?) -> String {
        if error != nil { return "" }
        if mode == .programmer {
            if let entry { return format.string(digits: entry.digits, radix: radix, negative: entry.isNegative, grouping: grouping) }
            return format.string(integer(value), radix: radix, wordSize: wordSize, grouping: grouping)
        }
        if let entry { return format.string(entry, grouping: grouping) }
        return format.string(value, scientific: scientificNotation, grouping: grouping)
    }

    /// The line above the number: the calculation so far.
    var expressionText: String {
        if let finished, error == nil { return finished }
        var parts: [String] = []
        for (index, frame) in frames.enumerated() {
            if index > 0 { parts.append("(") }
            parts.append(contentsOf: frame.tokens)
        }
        if operandReady, entry == nil, let operandText { parts.append(operandText) }
        return parts.joined(separator: " ")
    }

    var hasMemory: Bool { !memories.isEmpty }
    var openParentheses: Int { frames.count - 1 }
    var isFlat: Bool { mode == .standard }

    /// The bits of the number on the display, for the bit panel of the programmer mode.
    var bits: UInt64 { UInt64(bitPattern: integer(operand)) & wordSize.mask }

    /// The number on the display as the programmer mode writes it in a base.
    func text(in radix: Radix) -> String {
        guard error == nil else { return "" }
        return format.string(integer(operand), radix: radix, wordSize: wordSize)
    }

    /// Whether a digit can be typed in the current base.
    func accepts(digit: Int) -> Bool { digit < (mode == .programmer ? radix.rawValue : 10) }

    // MARK: Settings

    func setMode(_ newMode: CalcMode) {
        guard newMode != mode else { return }
        let kept = error == nil ? operand : .zero
        reset()
        mode = newMode
        scientificNotation = false
        value = newMode == .programmer ? BigDecimal(Int(integer(kept))) : kept
    }

    func setRadix(_ newRadix: Radix) {
        guard mode == .programmer, error == nil else { radix = newRadix; return }
        value = operand
        entry = nil
        radix = newRadix
    }

    func setWordSize(_ size: WordSize) {
        guard mode == .programmer, error == nil else { wordSize = size; return }
        let current = integer(operand)
        entry = nil
        wordSize = size
        value = BigDecimal(Int(wrap(current)))
    }

    func toggleBit(_ index: Int) {
        guard mode == .programmer, error == nil, index >= 0, index < wordSize.rawValue else { return }
        let flipped = integer(operand) ^ Int64(bitPattern: UInt64(1) << UInt64(index))
        entry = nil
        operandText = nil
        operandReady = true
        value = BigDecimal(Int(wrap(flipped)))
    }

    func clearHistory() { history = [] }

    /// A click on a line of the history brings its result back to the display.
    func recall(_ item: HistoryEntry) {
        if error != nil { reset() }
        entry = nil
        operandText = nil
        operandReady = true
        value = mode == .programmer ? BigDecimal(Int(integer(item.value))) : item.value
    }

    /// A click on a number of the memory list brings it to the display.
    func recallMemory(at index: Int) {
        guard memories.indices.contains(index) else { return }
        if error != nil { reset() }
        finished = nil
        show(mode == .programmer ? BigDecimal(Int(integer(memories[index]))) : memories[index])
    }

    func removeMemory(at index: Int) {
        if memories.indices.contains(index) { memories.remove(at: index) }
    }

    // MARK: Keys

    func press(_ key: Key) {
        if error != nil {
            switch key {
            case .clear, .clearEntry: reset(); return
            case .digit, .decimal, .pi, .twoPi, .memoryRecall: reset()
            case .memoryClear: memories = []; return
            case .clearSmart: reset(); return
            default: return
            }
        }
        let shown = finished
        finished = nil
        do {
            try handle(key)
            // Keys that leave the display as it is leave the finished calculation above it too.
            switch key {
            case .memoryStore, .memoryAdd, .memorySubtract, .memoryClear, .toggleNotation: finished = shown
            default: break
            }
        } catch let failure as CalcError {
            fail(failure)
        } catch {
            fail(.invalidInput)
        }
    }

    /// Types a text as if its characters were keys: a number in the person's region or with a
    /// point, with the operators between numbers.
    func paste(_ text: String) {
        let separators = text.filter { $0 == "." || $0 == "," }
        var negatePending = false
        var typing = false
        func finishNumber() {
            if typing, negatePending { press(.negate) }
            typing = false
            negatePending = false
        }
        let characters = Array(text.trimmingCharacters(in: .whitespacesAndNewlines))
        var index = 0
        while index < characters.count {
            let character = characters[index]
            index += 1
            if character.isWhitespace || character == "\u{00A0}" || character == "\u{202F}" { continue }
            if let digit = character.hexDigitValue, character.isASCII, accepts(digit: digit) {
                press(.digit(digit))
                typing = true
                continue
            }
            let text = String(character)
            if text == "." || text == "," || text == format.decimalSeparator || text == format.groupingSeparator {
                let isDecimal: Bool
                if text == format.decimalSeparator {
                    isDecimal = true
                } else if separators.contains(Character(format.decimalSeparator)) || separators.count > 1 {
                    isDecimal = false
                } else if text == format.groupingSeparator {
                    // One sign that the region uses for thousands: thousands when three digits follow.
                    let following = characters[index...].prefix { $0.isNumber }.count
                    isDecimal = following != 3
                } else {
                    isDecimal = true
                }
                if isDecimal { press(.decimal); typing = true }
                continue
            }
            switch character {
            case "e", "E":
                guard mode != .programmer, typing else { continue }
                press(.exponent)
                if index < characters.count, characters[index] == "-" || characters[index] == "−" {
                    index += 1
                    while index < characters.count, let digit = characters[index].wholeNumberValue {
                        press(.digit(digit))
                        index += 1
                    }
                    press(.negate)
                } else if index < characters.count, characters[index] == "+" {
                    index += 1
                }
            case "-", "−":
                if typing {
                    finishNumber()
                    press(.binary(.subtract))
                } else {
                    negatePending.toggle()
                }
            case "+": finishNumber(); press(.binary(.add))
            case "*", "×": finishNumber(); press(.binary(.multiply))
            case "/", "÷": finishNumber(); press(.binary(.divide))
            case "=": finishNumber(); press(.equals)
            case "(": if !isFlat { press(.openParen) }
            case ")": finishNumber(); if !isFlat { press(.closeParen) }
            default: break
            }
        }
        finishNumber()
    }

    private func handle(_ key: Key) throws {
        switch key {
        case .digit(let digit): type(digit)
        case .decimal: typePoint()
        case .exponent: typeExponent()
        case .backspace: backspace()
        case .negate: try negate()
        case .clear: reset()
        case .clearSmart:
            // One key for both: it clears the number being typed, or else everything.
            if entry != nil { try handle(.clearEntry) } else { reset() }
        case .clearEntry:
            entry = nil
            operandText = nil
            operandReady = true
            value = .zero
        case .binary(let op): try binary(op)
        case .equals: try equals()
        case .percent: try percent()
        case .unary(let function): try unary(function)
        case .openParen: openParenthesis()
        case .closeParen: try closeParenthesis()
        case .pi: show(BigMath.piDigits.rounded(BigMath.precision))
        case .twoPi: show(BigMath.piDigits.multiplied(by: .two, precision: BigMath.precision))
        case .euler: show(try BigMath.exp(.one))
        case .random: show(Self.random())
        case .memoryClear: memories = []
        case .memoryRecall:
            guard let newest = memories.first else { return }
            show(mode == .programmer ? BigDecimal(Int(integer(newest))) : newest)
        case .memoryStore:
            settle()
            memories.insert(value, at: 0)
        case .memoryAdd, .memorySubtract:
            settle()
            let change = key == .memoryAdd ? value : value.negated
            if memories.isEmpty {
                memories = [change]
            } else {
                memories[0] = try checked(memories[0].adding(change, precision: BigMath.precision))
            }
        case .toggleNotation:
            guard mode != .programmer else { return }
            settle()
            scientificNotation.toggle()
        }
    }

    // MARK: Typing

    private var operand: BigDecimal {
        guard let entry else { return value }
        if mode == .programmer {
            let bits = UInt64(entry.digits, radix: radix.rawValue) ?? 0
            let signed = radix == .dec && entry.isNegative ? 0 &- Int64(bitPattern: bits) : Int64(bitPattern: bits)
            return BigDecimal(Int(wrap(signed)))
        }
        return entry.value
    }

    /// Ends the typing: what was typed becomes the value.
    private func settle() {
        value = operand
        entry = nil
        operandReady = true
    }

    private func show(_ newValue: BigDecimal) {
        entry = nil
        operandText = nil
        operandReady = true
        value = newValue
    }

    private func beginEntry() -> Entry {
        if let entry { return entry }
        operandText = nil
        operandReady = true
        return Entry()
    }

    private func type(_ digit: Int) {
        guard accepts(digit: digit) else { return }
        var typed = beginEntry()
        let character = String(digit, radix: 16, uppercase: true)
        if mode == .programmer {
            let digits = typed.digits == "0" ? character : typed.digits + character
            // The number must fit in the word: as bits in the other bases, with its sign in decimal.
            guard let bits = UInt64(digits, radix: radix.rawValue) else { return }
            let limit = radix == .dec ? wordSize.mask >> 1 : wordSize.mask
            guard bits <= limit else { return }
            typed.digits = digits
        } else if var exponent = typed.exponent {
            guard exponent.count < 4 else { return }
            exponent = exponent == "0" ? character : exponent + character
            typed.exponent = exponent
        } else if let fraction = typed.fraction {
            guard typed.significantDigits < NumberFormat.displayDigits else { return }
            typed.fraction = fraction + character
        } else {
            guard typed.significantDigits < NumberFormat.displayDigits else { return }
            typed.digits = typed.digits == "0" ? character : typed.digits + character
        }
        entry = typed
    }

    private func typePoint() {
        guard mode != .programmer else { return }
        var typed = beginEntry()
        if typed.fraction == nil, typed.exponent == nil { typed.fraction = "" }
        entry = typed
    }

    private func typeExponent() {
        guard mode == .scientific, var typed = entry, typed.exponent == nil,
              !typed.value.isZero else { return }
        typed.exponent = ""
        entry = typed
    }

    private func backspace() {
        guard var typed = entry else { return }
        if let exponent = typed.exponent {
            if exponent.isEmpty {
                typed.exponent = nil
                typed.exponentIsNegative = false
            } else {
                typed.exponent = String(exponent.dropLast())
            }
        } else if let fraction = typed.fraction {
            typed.fraction = fraction.isEmpty ? nil : String(fraction.dropLast())
        } else {
            typed.digits = typed.digits.count > 1 ? String(typed.digits.dropLast()) : "0"
            if typed.digits == "0" { typed.isNegative = false }
        }
        entry = typed
    }

    private func negate() throws {
        if var typed = entry {
            if typed.exponent != nil {
                typed.exponentIsNegative.toggle()
                entry = typed
                return
            }
            if mode != .programmer || radix == .dec {
                if typed.value.isZero, typed.fraction == nil { return }
                typed.isNegative.toggle()
                entry = typed
                return
            }
        }
        let current = operand
        let text = operandText
        show(mode == .programmer ? BigDecimal(Int(wrap(0 &- integer(current)))) : current.negated)
        if let text { operandText = "negate(" + text + ")" }
    }

    // MARK: Operations

    private func numberText(_ number: BigDecimal) -> String {
        if mode == .programmer { return format.string(integer(number), radix: radix, wordSize: wordSize, grouping: false) }
        return format.string(number, grouping: false)
    }

    private func binary(_ op: BinaryOp) throws {
        let programmerOnly: Bool
        switch op {
        case .and, .or, .xor, .nand, .nor, .shiftLeft, .shiftRight: programmerOnly = true
        default: programmerOnly = false
        }
        if programmerOnly, mode != .programmer { return }
        if mode == .programmer, op == .power || op == .root || op == .logBase { return }
        if !operandReady, entry == nil, let last = frames[frames.count - 1].pending.last {
            // Another operator right after one: it takes the place of the first.
            frames[frames.count - 1].pending.removeLast()
            frames[frames.count - 1].tokens.removeLast()
            let reduced = try reduce(last.value, before: op)
            frames[frames.count - 1].pending.append(Pending(value: reduced, op: op))
            frames[frames.count - 1].tokens.append(op.symbol)
            value = reduced
            return
        }
        let right = operand
        let text = operandText ?? numberText(right)
        entry = nil
        frames[frames.count - 1].tokens.append(contentsOf: [text, op.symbol])
        let reduced = try reduce(right, before: op)
        frames[frames.count - 1].pending.append(Pending(value: reduced, op: op))
        value = reduced
        operandText = nil
        operandReady = false
        lastRepeat = nil
    }

    /// Runs the waiting operations of the current level that bind at least as tight as `op`
    /// (all of them for nil, or in the standard mode), with `right` as the right side.
    private func reduce(_ right: BigDecimal, before op: BinaryOp?) throws -> BigDecimal {
        var result = right
        while let last = frames[frames.count - 1].pending.last {
            if let op, !isFlat, last.op.precedence < op.precedence { break }
            result = try apply(last.op, last.value, result)
            frames[frames.count - 1].pending.removeLast()
        }
        return result
    }

    private func equals() throws {
        let right = operand
        entry = nil
        if frames.count == 1, frames[0].pending.isEmpty {
            if let lastRepeat {
                // The equals key again repeats the last operation on the result.
                let expression = [numberText(right), lastRepeat.op.symbol, numberText(lastRepeat.operand)].joined(separator: " ")
                let result = try apply(lastRepeat.op, right, lastRepeat.operand)
                record(expression, result)
                show(result)
            } else {
                record(operandText ?? numberText(right), right)
                show(right)
            }
            return
        }
        lastRepeat = frames[frames.count - 1].pending.last.map { ($0.op, right) }
        var result = right
        var text = operandText ?? numberText(right)
        var expression = ""
        // Parentheses left open are closed by the equals key.
        while true {
            let tokens = frames[frames.count - 1].tokens + [text]
            result = try reduce(result, before: nil)
            frames.removeLast()
            if frames.isEmpty {
                expression = tokens.joined(separator: " ")
                break
            }
            text = "(" + tokens.joined(separator: " ") + ")"
        }
        frames = [Frame()]
        record(expression, result)
        show(result)
    }

    private func percent() throws {
        guard mode == .standard else { return }
        let right = operand
        guard let last = frames[frames.count - 1].pending.last else {
            show(.zero)
            return
        }
        // 200 + 10 % is 200 + 20: in a sum the percentage is taken of the left side. In a
        // product it is just the hundredth part: 200 × 10 % is 200 × 0.1.
        let part = last.op == .add || last.op == .subtract
            ? last.value.multiplied(by: right, precision: BigMath.precision).scaled(byPowerOfTen: -2)
            : right.scaled(byPowerOfTen: -2)
        show(try checked(part))
    }

    private func unary(_ function: UnaryOp) throws {
        let programmerFunction = [.not, .rotateLeft, .rotateRight].contains(function)
        if mode == .programmer {
            guard programmerFunction else { return }
        } else if programmerFunction {
            return
        }
        let argument = operand
        let text = function.name + "(" + (operandText ?? numberText(argument)) + ")"
        let result = try compute(function, argument)
        show(result)
        operandText = text
    }

    private func openParenthesis() {
        guard !isFlat, frames.count <= Self.maximumDepth else { return }
        // A number typed right before the parenthesis gives way to what is inside it.
        entry = nil
        operandText = nil
        operandReady = false
        frames.append(Frame())
    }

    private func closeParenthesis() throws {
        guard !isFlat, frames.count > 1 else { return }
        let right = operand
        entry = nil
        let tokens = frames[frames.count - 1].tokens + [operandText ?? numberText(right)]
        let result = try reduce(right, before: nil)
        frames.removeLast()
        show(result)
        operandText = "(" + tokens.joined(separator: " ") + ")"
    }

    private func record(_ expression: String, _ result: BigDecimal) {
        finished = expression + " ="
        guard mode == .standard || mode == .scientific else { return }
        history.append(HistoryEntry(expression: expression + " =", value: result))
        if history.count > Self.maximumHistory { history.removeFirst(history.count - Self.maximumHistory) }
    }

    private func reset() {
        frames = [Frame()]
        entry = nil
        error = nil
        operandText = nil
        operandReady = true
        lastRepeat = nil
        finished = nil
        value = .zero
    }

    private func fail(_ failure: CalcError) {
        reset()
        error = failure
    }

    // MARK: Arithmetic

    /// Beyond ten to the 10000 is an overflow; under ten to the -10000 is zero.
    private func checked(_ number: BigDecimal) throws -> BigDecimal {
        if number.magnitude10 > BigMath.maximumExponent { throw CalcError.overflow }
        if !number.isZero, number.magnitude10 < -BigMath.maximumExponent { return .zero }
        return number
    }

    private func apply(_ op: BinaryOp, _ left: BigDecimal, _ right: BigDecimal) throws -> BigDecimal {
        if mode == .programmer { return BigDecimal(Int(try apply(op, integer(left), integer(right)))) }
        let p = BigMath.precision
        let result: BigDecimal
        switch op {
        case .add: result = left.adding(right, precision: p)
        case .subtract: result = left.subtracting(right, precision: p)
        case .multiply: result = left.multiplied(by: right, precision: p)
        case .divide:
            guard !right.isZero else { throw left.isZero ? CalcError.undefined : CalcError.divideByZero }
            result = left.divided(by: right, precision: p)
        case .modulo:
            guard !right.isZero else { throw CalcError.undefined }
            result = left.quotientAndRemainder(dividingBy: right).remainder.rounded(p)
        case .power: result = try BigMath.power(left, right)
        case .root: result = try BigMath.root(left, right)
        case .logBase:
            // The logarithm of the left side in the base of the right side.
            let base = try BigMath.naturalLog(right, precision: BigMath.working)
            guard !base.isZero else { throw CalcError.invalidInput }
            result = try BigMath.naturalLog(left, precision: BigMath.working).divided(by: base, precision: BigMath.working).rounded(p)
        case .and, .or, .xor, .nand, .nor, .shiftLeft, .shiftRight: throw CalcError.invalidInput
        }
        return try checked(result)
    }

    private func compute(_ function: UnaryOp, _ x: BigDecimal) throws -> BigDecimal {
        if mode == .programmer { return BigDecimal(Int(compute(function, integer(x)))) }
        let p = BigMath.precision
        let result: BigDecimal
        switch function {
        case .sqrt: result = try BigMath.sqrt(x)
        case .reciprocal:
            guard !x.isZero else { throw CalcError.divideByZero }
            result = BigDecimal.one.divided(by: x, precision: p)
        case .square: result = x.multiplied(by: x, precision: p)
        case .cube: result = x.multiplied(by: x, precision: p + 10).multiplied(by: x, precision: p)
        case .cubeRoot: result = BigMath.cubeRoot(x)
        case .sin: result = try BigMath.sin(x, unit: angleUnit)
        case .cos: result = try BigMath.cos(x, unit: angleUnit)
        case .tan: result = try BigMath.tan(x, unit: angleUnit)
        case .asin: result = try BigMath.asin(x, unit: angleUnit)
        case .acos: result = try BigMath.acos(x, unit: angleUnit)
        case .atan: result = BigMath.atan(x, unit: angleUnit)
        case .sinh: result = try BigMath.sinh(x)
        case .cosh: result = try BigMath.cosh(x)
        case .tanh: result = try BigMath.tanh(x)
        case .asinh: result = try BigMath.asinh(x)
        case .acosh: result = try BigMath.acosh(x)
        case .atanh: result = try BigMath.atanh(x)
        case .ln: result = try BigMath.ln(x)
        case .exp: result = try BigMath.exp(x)
        case .log: result = try BigMath.log10(x)
        case .powerOfTen: result = try BigMath.powerOfTen(x)
        case .powerOfTwo: result = try BigMath.power(.two, x)
        case .sec, .csc, .cot:
            let (sine, cosine) = try BigMath.sineAndCosine(x, unit: angleUnit)
            let divisor = function == .sec ? cosine : sine
            guard !divisor.isZero else { throw CalcError.invalidInput }
            result = (function == .cot ? cosine : BigDecimal.one).divided(by: divisor, precision: p)
        case .asec, .acsc, .acot:
            if x.isZero {
                // The arc cotangent of zero is the right angle; the other two have no value there.
                guard function == .acot else { throw CalcError.invalidInput }
                result = try BigMath.acos(.zero, unit: angleUnit)
            } else {
                let inverse = BigDecimal.one.divided(by: x, precision: BigMath.working)
                result = function == .asec ? try BigMath.acos(inverse, unit: angleUnit)
                    : function == .acsc ? try BigMath.asin(inverse, unit: angleUnit) : BigMath.atan(inverse, unit: angleUnit)
            }
        case .sech, .csch, .coth:
            let value = function == .sech ? try BigMath.cosh(x) : function == .csch ? try BigMath.sinh(x) : try BigMath.tanh(x)
            guard !value.isZero else { throw CalcError.divideByZero }
            result = BigDecimal.one.divided(by: value, precision: p)
        case .asech, .acsch, .acoth:
            guard !x.isZero else { throw CalcError.invalidInput }
            let inverse = BigDecimal.one.divided(by: x, precision: BigMath.working)
            result = function == .asech ? try BigMath.acosh(inverse) : function == .acsch ? try BigMath.asinh(inverse) : try BigMath.atanh(inverse)
        case .abs: result = x.magnitude
        case .floor, .ceiling:
            let whole = BigMath.snapped(x)
            let cut = whole.truncated
            if cut == whole {
                result = cut
            } else if function == .floor {
                result = whole.isNegative ? cut.subtracting(.one, precision: p) : cut
            } else {
                result = whole.isNegative ? cut : cut.adding(.one, precision: p)
            }
        case .factorial:
            let whole = BigMath.snapped(x)
            result = try BigMath.factorial(whole.isInteger ? whole : x)
        case .integer: result = BigMath.snapped(x).truncated
        case .fraction:
            let whole = BigMath.snapped(x)
            result = whole.subtracting(whole.truncated, precision: p)
        case .dms: result = BigMath.toDegreesMinutesSeconds(BigMath.snapped(x))
        case .degrees: result = BigMath.fromDegreesMinutesSeconds(BigMath.snapped(x))
        case .not, .rotateLeft, .rotateRight: throw CalcError.invalidInput
        }
        return try checked(result)
    }

    /// A number between 0 and 1, with as many digits as the display shows.
    private static func random() -> BigDecimal {
        let digits = (0..<NumberFormat.displayDigits).map { _ in UInt8.random(in: 0...9) }
        return BigDecimal(negative: false, digits: digits, exponent: -NumberFormat.displayDigits)
    }

    // MARK: Whole numbers of the programmer mode

    /// Keeps the low bits of the word and extends its sign.
    private func wrap(_ number: Int64) -> Int64 {
        let unused = Int64(64 - wordSize.rawValue)
        return unused == 0 ? number : (number << unused) >> unused
    }

    private static let twoTo64 = BigDecimal("18446744073709551616")!

    /// The value as a whole number of the word: the fraction is dropped and what does not fit
    /// wraps around, as in two's complement.
    private func integer(_ number: BigDecimal) -> Int64 {
        let whole = BigMath.snapped(number).truncated
        var rest = whole.quotientAndRemainder(dividingBy: Self.twoTo64).remainder
        if rest.isNegative { rest = rest.adding(Self.twoTo64, precision: 40) }
        return wrap(Int64(bitPattern: UInt64(rest.description) ?? 0))
    }

    private func apply(_ op: BinaryOp, _ left: Int64, _ right: Int64) throws -> Int64 {
        let width = Int64(wordSize.rawValue)
        switch op {
        case .add: return wrap(left &+ right)
        case .subtract: return wrap(left &- right)
        case .multiply: return wrap(left &* right)
        case .divide:
            guard right != 0 else { throw left == 0 ? CalcError.undefined : CalcError.divideByZero }
            return wrap(left.dividedReportingOverflow(by: right).partialValue)
        case .modulo:
            guard right != 0 else { throw CalcError.undefined }
            return wrap(left.remainderReportingOverflow(dividingBy: right).partialValue)
        case .and: return left & right
        case .or: return left | right
        case .xor: return left ^ right
        case .nand: return wrap(~(left & right))
        case .nor: return wrap(~(left | right))
        case .shiftLeft:
            guard right >= 0, right < width else { return 0 }
            return wrap(left << right)
        case .shiftRight:
            guard right >= 0 else { return 0 }
            return right < width ? left >> right : (left < 0 ? -1 : 0)
        case .power, .root, .logBase: throw CalcError.invalidInput
        }
    }

    private func compute(_ function: UnaryOp, _ number: Int64) -> Int64 {
        let bits = UInt64(bitPattern: number) & wordSize.mask
        let top = UInt64(wordSize.rawValue - 1)
        switch function {
        case .not: return wrap(~number)
        case .rotateLeft: return wrap(Int64(bitPattern: ((bits << 1) | (bits >> top)) & wordSize.mask))
        case .rotateRight: return wrap(Int64(bitPattern: ((bits >> 1) | ((bits & 1) << top)) & wordSize.mask))
        default: return number
        }
    }
}
