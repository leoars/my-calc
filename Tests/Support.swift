import Foundation

var failures = 0

func check(_ condition: Bool, _ name: String) {
    print(condition ? "ok    \(name)" : "FAIL  \(name)")
    if !condition { failures += 1 }
}

/// Compares a text with the expected one and shows both when they differ.
func expect(_ actual: String, _ expected: String, _ name: String) {
    check(actual == expected, actual == expected ? name : "\(name) — got \(actual), expected \(expected)")
}

let keyNames: [String: Key] = [
    "+": .binary(.add), "-": .binary(.subtract), "*": .binary(.multiply), "/": .binary(.divide),
    "=": .equals, "%": .percent, ".": .decimal, "neg": .negate, "bs": .backspace, "C": .clear, "CE": .clearEntry,
    "(": .openParen, ")": .closeParen, "exp": .exponent, "pi": .pi, "2pi": .twoPi, "fe": .toggleNotation,
    "sqrt": .unary(.sqrt), "1/x": .unary(.reciprocal), "sqr": .unary(.square), "cube": .unary(.cube), "cbrt": .unary(.cubeRoot),
    "sin": .unary(.sin), "cos": .unary(.cos), "tan": .unary(.tan), "asin": .unary(.asin), "acos": .unary(.acos), "atan": .unary(.atan),
    "sinh": .unary(.sinh), "cosh": .unary(.cosh), "tanh": .unary(.tanh), "asinh": .unary(.asinh), "acosh": .unary(.acosh), "atanh": .unary(.atanh),
    "ln": .unary(.ln), "e^x": .unary(.exp), "log": .unary(.log), "10^x": .unary(.powerOfTen), "fact": .unary(.factorial),
    "int": .unary(.integer), "frac": .unary(.fraction), "dms": .unary(.dms), "deg": .unary(.degrees),
    "^": .binary(.power), "yroot": .binary(.root), "mod": .binary(.modulo),
    "and": .binary(.and), "or": .binary(.or), "xor": .binary(.xor), "lsh": .binary(.shiftLeft), "rsh": .binary(.shiftRight),
    "not": .unary(.not), "rol": .unary(.rotateLeft), "ror": .unary(.rotateRight),
    "MC": .memoryClear, "MR": .memoryRecall, "MS": .memoryStore, "M+": .memoryAdd, "M-": .memorySubtract,
    "nand": .binary(.nand), "nor": .binary(.nor), "logy": .binary(.logBase), "2^x": .unary(.powerOfTwo),
    "abs": .unary(.abs), "floor": .unary(.floor), "ceil": .unary(.ceiling), "e": .euler, "cs": .clearSmart,
    "sec": .unary(.sec), "csc": .unary(.csc), "cot": .unary(.cot), "asec": .unary(.asec), "acsc": .unary(.acsc), "acot": .unary(.acot),
    "sech": .unary(.sech), "csch": .unary(.csch), "coth": .unary(.coth), "asech": .unary(.asech), "acsch": .unary(.acsch), "acoth": .unary(.acoth),
]

extension Calculator {
    /// Presses the keys of a script: names from `keyNames` separated by spaces; anything else is
    /// typed digit by digit, as in "12.5".
    @discardableResult
    func run(_ script: String) -> Calculator {
        for word in script.split(separator: " ") {
            if let key = keyNames[String(word)] {
                press(key)
                continue
            }
            for character in word {
                if character == "." { press(.decimal) } else if let digit = character.hexDigitValue { press(.digit(digit)) }
            }
        }
        return self
    }

    /// The display, or the error in brackets.
    var shown: String { error.map { "[\($0)]" } ?? displayText }
}

/// The display after a script on a new calculator.
func result(_ script: String, _ mode: CalcMode = .standard, angle: AngleUnit = .degrees) -> String {
    let calculator = Calculator(mode: mode)
    calculator.angleUnit = angle
    return calculator.run(script).shown
}
