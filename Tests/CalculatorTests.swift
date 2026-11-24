import Foundation

/// The calculator key by key, as a person would press them.
func runCalculatorTests() {
    // Decimal arithmetic, with nothing of the binary fractions on the display.
    expect(result("0.1 + 0.2 ="), "0.3", "0.1 + 0.2 = 0.3")
    expect(result("1.1 * 1.1 ="), "1.21", "1.1 × 1.1 = 1.21")
    expect(result("0.3 - 0.1 ="), "0.2", "0.3 − 0.1 = 0.2")
    expect(result("1 / 3 * 3 ="), "1", "a third times three is 1")
    expect(result("2 sqrt sqr"), "2", "the square of the root of 2 is 2")
    expect(result("9999999999999999 * 9999999999999999 ="), "99999999999999980000000000000001", "32 digits of a product, all of them")
    expect(result("1 / 7 ="), "0.14285714285714285714285714285714", "a seventh to 32 digits")
    expect(result("100 / 3 ="), "33.333333333333333333333333333333", "32 significant digits whatever the size")

    // Order of the operations.
    expect(result("1 + 2 * 3 ="), "9", "standard: in the order typed")
    expect(result("1 + 2 * 3 =", .scientific), "7", "scientific: multiplication first")
    expect(result("2 * 3 + 4 * 5 =", .scientific), "26", "two products and a sum")
    expect(result("2 + 3 * 4 ^ 2 =", .scientific), "50", "the power binds tighter than the product")
    expect(result("10 - 4 - 3 =", .scientific), "3", "equal precedence runs from the left")
    expect(result("( 1 + 2 ) * ( 3 + 4 ) =", .scientific), "21", "parentheses")
    expect(result("2 * ( 3 + ( 4 - 1 ) * 2 ) =", .scientific), "18", "parentheses inside parentheses")
    expect(result("2 * ( 3 + 4 =", .scientific), "14", "the equals key closes what was left open")
    expect(result("7 )", .scientific), "7", "a closing parenthesis with nothing open does nothing")
    expect(result("17 mod 5 =", .scientific) + " " + result("17 neg mod 5 =", .scientific) + " " + result("5.5 mod 2 =", .scientific), "2 -2 1.5",
           "Mod keeps the sign of the left side")

    // Chains and the equals key.
    expect(result("2 + 3 + 4 ="), "9", "a chain of sums")
    let running = Calculator()
    running.run("2 + 3 +")
    expect(running.shown, "5", "the next operator shows the result so far")
    expect(result("2 + 3 = = ="), "11", "equals again repeats the last operation")
    expect(result("2 * 3 = = ="), "54", "the repetition keeps the right side")
    expect(result("2 + 3 = 10 ="), "13", "a new number then equals applies the same operation to it")
    expect(result("5 + ="), "10", "an operator and equals uses the number on the display twice")
    expect(result("2 + * 3 ="), "6", "a second operator takes the place of the first")
    expect(result("2 + 3 * - 1 =", .scientific), "4", "replacing an operator by a weaker one runs what was waiting")
    expect(result("2 + 3 = + 4 ="), "9", "a result goes on into the next calculation")
    expect(result("2 + 3 = 7"), "7", "a digit after equals starts a new number")
    expect(result("5 ="), "5", "equals alone leaves the number")

    // Percent.
    expect(result("200 + 10 % ="), "220", "200 + 10 % is 220")
    expect(result("200 - 10 % ="), "180", "200 − 10 % is 180")
    expect(result("200 * 10 % =") + " " + result("50 / 10 % ="), "20 500", "in a product or a division it is the hundredth part")
    expect(result("50 %"), "0", "a percentage of nothing is 0")
    let percent = Calculator()
    percent.run("80 + 25 %")
    expect(percent.shown, "20", "the percent key shows the part")

    // Typing.
    expect(result("0 0 7"), "7", "zeros before a number are not typed")
    expect(result("1 . 5 . 2"), "1.52", "a second point is ignored")
    expect(result(". 5"), "0.5", "a point first gives 0.")
    expect(result("1 2 3 bs"), "12", "backspace takes the last digit")
    expect(result("1 . 5 bs bs bs"), "0", "down to 0")
    expect(result("1 2 neg 3"), "-123", "the sign key works while typing")
    expect(result("5 neg neg"), "5", "twice gives the number back")
    expect(result("9 sqrt neg"), "-3", "and it negates a result")
    expect(result("12345678901234567890123456789012345"), "12345678901234567890123456789012", "no more than 32 digits are typed")
    expect(result("2 + 3 bs ="), "2", "backspace on the right side leaves 0 there")
    expect(result("7 + 8 CE 2 ="), "9", "CE clears the number, not the calculation")
    expect(result("7 + 8 C 2 ="), "2", "C clears everything")
    expect(result("6 * 7 = bs"), "42", "backspace does not touch a result")
    expect(result("1.5 exp 3 =", .scientific), "1500", "Exp types the power of ten")
    expect(result("1.5 exp 3 neg =", .scientific), "0.0015", "the sign key then signs the exponent")
    let typing = Calculator(mode: .scientific)
    typing.run("2 exp 1 5")
    expect(typing.shown, "2.e+15", "the exponent shows as it is typed")
    typing.run("bs bs bs")
    expect(typing.shown, "2", "and backspace undoes it")
    expect(result("1 / 3 = fe", .scientific), "3.3333333333333333333333333333333e-1", "F-E turns the exponent form on")
    expect(result("1 5 0 0 fe fe", .scientific), "1500", "and off")

    // Functions on the keypad.
    expect(result("9 sqrt") + " " + result("4 1/x") + " " + result("5 sqr", .scientific) + " " + result("3 cube", .scientific), "3 0.25 25 27",
           "root, reciprocal, square and cube")
    expect(result("2 + 9 sqrt ="), "5", "a function works on the number being typed, inside a calculation")
    expect(result("30 sin", .scientific) + " " + result("60 cos", .scientific) + " " + result("45 tan", .scientific), "0.5 0.5 1", "degrees by default")
    expect(result("100 sin", .scientific, angle: .grads), "1", "grads")
    expect(result("pi cos", .scientific, angle: .radians) + " " + result("pi sin", .scientific, angle: .radians), "-1 0", "radians, with the pi key")
    expect(result("0.5 asin", .scientific) + " " + result("1 atan", .scientific, angle: .grads), "30 50", "the inverse functions answer in the unit chosen")
    expect(result("1 e^x ln", .scientific) + " " + result("1000 log", .scientific) + " " + result("3 10^x", .scientific), "1 3 1000", "logarithms and their inverses")
    expect(result("2 ^ 10 =", .scientific) + " " + result("2 ^ 0.5 = sqr", .scientific) + " " + result("1024 yroot 10 =", .scientific) + " " + result("27 cbrt", .scientific),
           "1024 2 2 3", "powers and roots")
    expect(result("5 fact", .scientific) + " " + result("0 fact", .scientific) + " " + result("170 fact", .scientific),
           "120 1 7.2574156153079989673967282111293e+306", "factorials, beyond what a Double holds")
    expect(result("3.7 int", .scientific) + " " + result("3.7 frac", .scientific) + " " + result("3.7 neg int", .scientific), "3 0.7 -3", "integer and fractional parts")
    expect(result("1 / 3 * 3 = int", .scientific) + " " + result("1 / 3 * 3 = frac", .scientific), "1 0", "a result that shows as 1 is 1 for Int and Frac")
    expect(result("2.5 dms", .scientific) + " " + result("2.30 deg", .scientific), "2.3 2.5", "degrees, minutes and seconds")
    expect(result("2pi", .scientific), "6.283185307179586476925286766559", "two pi")
    expect(result("1 sinh asinh", .scientific) + " " + result("2 cosh acosh", .scientific) + " " + result("0.5 tanh atanh", .scientific), "1 2 0.5",
           "the hyperbolic functions and their inverses undo each other")

    expect(result("5 neg abs", .scientific) + " " + result("2.5 floor", .scientific) + " " + result("2.5 neg floor", .scientific) + " "
           + result("2.5 ceil", .scientific) + " " + result("2.5 neg ceil", .scientific) + " " + result("7 floor", .scientific), "5 2 -3 3 -2 7",
           "absolute value, floor and ceiling")
    expect(result("8 logy 2 =", .scientific) + " " + result("10 2^x", .scientific) + " " + result("e ln", .scientific), "3 1024 1", "logarithm in any base, powers of two and e")
    expect(result("60 sec", .scientific) + " " + result("30 csc", .scientific) + " " + result("45 cot", .scientific) + " " + result("2 asec", .scientific)
           + " " + result("2 acsc", .scientific) + " " + result("1 acot", .scientific) + " " + result("0 acot", .scientific), "2 2 1 60 30 45 90",
           "secant, cosecant and cotangent, and their inverses")
    expect(result("0 sech", .scientific) + " " + result("2 csch 1/x asinh", .scientific) + " " + result("3 coth acoth", .scientific) + " "
           + result("0.5 asech sech", .scientific) + " " + result("0 csch", .scientific), "1 2 3 0.5 [divideByZero]", "the hyperbolic ones too")
    let random = Calculator(mode: .scientific)
    random.press(.random)
    let first = random.value
    random.press(.random)
    check(first >= .zero && first < .one && first != random.value, "rand gives a new number between 0 and 1 each time")
    expect(result("5 + 3 cs 2 =", .scientific) + " " + result("5 + cs 2 =", .scientific), "7 2", "one key clears the number being typed, or else everything")

    // Errors.
    expect(result("1 / 0 ="), "[divideByZero]", "division by zero")
    expect(result("0 / 0 ="), "[undefined]", "zero by zero is undefined")
    expect(result("0 1/x"), "[divideByZero]", "the reciprocal of zero")
    expect(result("4 neg sqrt"), "[invalidInput]", "the root of a negative number")
    expect(result("0 ln", .scientific) + result("2 asin", .scientific) + result("90 tan", .scientific) + result("3 neg fact", .scientific),
           "[invalidInput][invalidInput][invalidInput][invalidInput]", "functions outside their domain")
    expect(result("10 ^ 10000 =", .scientific) + result("3249 fact", .scientific) + result("5 mod 0 =", .scientific),
           "[overflow][overflow][undefined]", "overflow, and Mod by zero")
    expect(result("1 exp 9999 * 9 =", .scientific), "9.e+9999", "numbers go up to ten to the 10000")
    expect(result("1 exp 9999 neg / 1 exp 9 ="  , .scientific), "0", "what is too small becomes 0")
    let failing = Calculator()
    failing.run("1 / 0 =")
    check(failing.displayText.isEmpty && failing.error == .divideByZero, "the error takes the place of the number")
    failing.run("+ sqrt =")
    check(failing.error == .divideByZero, "operators do nothing while the error shows")
    failing.run("7 + 1 =")
    expect(failing.shown, "8", "a digit starts over after an error")
    failing.run("1 / 0 = C")
    expect(failing.shown, "0", "and C clears it")

    // Memory.
    expect(result("5 MS C 3 + MR ="), "8", "MS keeps the number and MR brings it back")
    expect(result("5 MS 2 M+ 1 M- C MR"), "6", "M+ and M- add to and subtract from the memory")
    expect(result("5 MS MC 7 MR"), "7", "MC empties it, and MR then has nothing to bring")
    expect(result("2 * 3 = MS 1 0 + MR ="), "16", "a result can be kept, and the next digit starts a new number")
    let memory = Calculator()
    check(!memory.hasMemory, "the memory starts empty")
    memory.run("4 M+")
    check(memory.hasMemory, "M+ on an empty memory stores the number")
    memory.run("1 MS 2 MS 3 M+")
    expect(memory.memories.map(\.description).joined(separator: " "), "5 1 4", "MS adds a number to the list; M+ works on the newest")
    memory.recallMemory(at: 2)
    expect(memory.shown, "4", "any number of the list can be brought back")
    memory.removeMemory(at: 0)
    memory.run("MR")
    expect(memory.shown, "1", "or taken out of it")
    memory.run("MC")
    check(!memory.hasMemory, "MC empties the list")

    // The line above the number, and the history.
    let lines = Calculator(mode: .scientific)
    lines.run("1 + 2 *")
    expect(lines.expressionText, "1 + 2 ×", "the calculation so far is on the line above")
    lines.run("( 3 + 4")
    expect(lines.expressionText, "1 + 2 × ( 3 +", "with the parentheses open")
    check(lines.openParentheses == 1, "one parenthesis is open")
    lines.run(")")
    expect(lines.expressionText, "1 + 2 × (3 + 4)", "and closed")
    lines.run("=")
    expect(lines.expressionText + "|" + lines.shown, "1 + 2 × (3 + 4) =|15", "equals shows the whole calculation above its result")
    lines.run("MS")
    expect(lines.expressionText, "1 + 2 × (3 + 4) =", "the memory keys leave it there")
    lines.run("9 sqrt")
    expect(lines.expressionText, "√(9)", "a function is written with its argument")
    lines.run("+ 30 sin =")
    lines.run("2 + 3 = =")
    expect(lines.history.map(\.expression).joined(separator: " | "), "1 + 2 × (3 + 4) = | √(9) + sin(30) = | 2 + 3 = | 5 + 3 =",
           "the history keeps each calculation")
    expect(lines.history.map { $0.value.description }.joined(separator: " "), "15 3.5 5 8", "with its result")
    lines.run("C")
    lines.recall(lines.history[1])
    lines.run("* 2 =")
    expect(lines.shown, "7", "a line of the history comes back to the display")
    lines.clearHistory()
    check(lines.history.isEmpty, "the history can be cleared")
    let long = Calculator()
    for _ in 0..<(Calculator.maximumHistory + 20) { long.run("1 + 1 =") }
    check(long.history.count == Calculator.maximumHistory, "the history keeps the last \(Calculator.maximumHistory) calculations")

    // Copy and paste.
    let brazilian = Calculator(format: NumberFormat(locale: Locale(identifier: "pt_BR"), grouping: true))
    brazilian.run("1234567.5")
    expect(brazilian.displayText + " " + brazilian.copyText, "1.234.567,5 1234567,5", "Copy takes the number without the grouping")
    func pasted(_ text: String, _ identifier: String = "en_US", mode: CalcMode = .standard) -> String {
        let calculator = Calculator(mode: mode, format: NumberFormat(locale: Locale(identifier: identifier), grouping: false))
        calculator.paste(text)
        return calculator.shown
    }
    expect(pasted("1,234,567.89") + " " + pasted("1.234.567,89", "pt_BR") + " " + pasted("3.14", "pt_BR") + " " + pasted("3,14"), "1234567.89 1234567,89 3,14 3.14",
           "Paste reads a number in the person's region or with the other decimal sign")
    expect(pasted("1.234", "pt_BR") + " " + pasted("1,234") + " " + pasted(" -42 ") + " " + pasted("R$ 19,90", "pt_BR"), "1234 1234 -42 19,90",
           "thousands, a sign, and text around the number")
    expect(pasted("2+3*4=") + " " + pasted("2+3*4=", mode: .scientific) + " " + pasted("1.5e3=", mode: .scientific) + " " + pasted("2e-3=", mode: .scientific),
           "20 14 1500 0.002", "a pasted calculation is typed key by key")
    expect(pasted("FF", mode: .programmer) + " " + pasted("12 34"), "0 1234", "letters only count as digits in hexadecimal")

    // Changing modes keeps the number.
    let moving = Calculator()
    moving.run("7.9 + 1")
    moving.setMode(.scientific)
    expect(moving.shown + "|" + moving.expressionText, "1|", "a new mode keeps the number and drops the calculation")
    moving.run("C 7.9")
    moving.setMode(.programmer)
    expect(moving.shown, "7", "the programmer mode keeps the whole part")
}
