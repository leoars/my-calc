import Foundation

private func d(_ text: String) -> BigDecimal { BigDecimal(text)! }

/// The decimal number type: exact in base ten, rounded only to the digits asked for.
func runBigDecimalTests() {
    let p = BigMath.precision
    expect(d("0.1").adding(d("0.2"), precision: p).description, "0.3", "0.1 + 0.2 is 0.3")
    expect(d("1.1").multiplied(by: d("1.1"), precision: p).description, "1.21", "1.1 × 1.1 is 1.21")
    expect(d("0.3").subtracting(d("0.1"), precision: p).description, "0.2", "0.3 − 0.1 is 0.2")
    expect(d("1").divided(by: d("8"), precision: p).description, "0.125", "1 ÷ 8 is 0.125")
    expect(d("1").divided(by: d("3"), precision: 10).description, "0.3333333333", "1 ÷ 3 keeps the digits asked for")
    expect(d("2").divided(by: d("3"), precision: 10).description, "0.6666666667", "the last digit is rounded")
    expect(d("1").divided(by: 7, precision: 12).description, "0.142857142857", "division by a small whole number")
    expect(d("123456789012345678901234567890").multiplied(by: d("987654321098765432109876543210"), precision: 60).description,
           "121932631137021795226185032733622923332237463801111263526900", "a 60-digit product is exact")
    expect(d("1e30").adding(d("1"), precision: p).description, "1000000000000000000000000000001", "1e30 + 1 keeps the 1")
    expect(d("1e9999").adding(d("1"), precision: p).description, "1e9999", "a term far below the precision is dropped")
    expect(d("-5").adding(d("5"), precision: p).description, "0", "opposites add up to zero")
    check(BigDecimal.zero.negated == .zero && !BigDecimal.zero.negated.isNegative, "zero has no sign")
    expect(d("100").description + " " + d("0.50").description + " " + d("-0012.3400").description, "100 0.5 -12.34",
           "zeros at either end are not part of the number")
    check(BigDecimal("") == nil && BigDecimal("1.2.3") == nil && BigDecimal("abc") == nil && BigDecimal("e5") == nil && BigDecimal("-") == nil,
          "texts that are not numbers are refused")
    expect(d("1.5e3").description + " " + d("25e-4").description, "1500 0.0025", "the exponent form is read")
    check(d("-2") < d("1") && d("0.1") < d("0.11") && d("-0.2") < d("-0.1") && d("9") < d("10") && !(d("3") < d("3")), "numbers compare by value")
    expect(d("2.5").rounded(1).description + " " + d("-2.5").rounded(1).description + " " + d("0.9995").rounded(3).description,
           "3 -3 1", "the half rounds away from zero, and the carry runs through the nines")
    expect(d("123.987").truncated.description + " " + d("-0.5").truncated.description + " " + d("7e3").truncated.description,
           "123 0 7000", "the integer part is cut towards zero")
    let division = d("-17.5").quotientAndRemainder(dividingBy: d("5"))
    expect(division.quotient.description + " " + division.remainder.description, "-3 -2.5", "the remainder keeps the sign of the dividend")
    expect(d("1e40").quotientAndRemainder(dividingBy: d("7")).remainder.description, "4", "a large remainder is exact")
    check(d("42").intValue == 42 && d("-7e2").intValue == -700 && d("1.5").intValue == nil, "whole numbers convert to Int")
    check(d("123.4").magnitude10 == 3 && d("0.05").magnitude10 == -1 && d("1").magnitude10 == 1, "the position of the first digit is known")
}

/// The functions of the scientific mode against values computed elsewhere to 60 digits.
func runMathTests() {
    func digits(_ value: BigDecimal?) -> String { value.map { $0.rounded(45).description } ?? "nil" }
    expect(digits(try? BigMath.exp(.one)), "2.71828182845904523536028747135266249775724709", "e to 45 digits")
    expect(digits(try? BigMath.ln(.two)), "0.693147180559945309417232121458176568075500134", "ln 2")
    expect(digits(BigMath.ln10), "2.30258509299404568401799145468436420760110149", "ln 10")
    expect(digits(try? BigMath.sqrt(.two)), "1.41421356237309504880168872420969807856967188", "√2")
    expect(digits(try? BigMath.exp(d("-5.5"))), "0.00408677143846406699346470268472076840839065665", "e to the -5.5")
    expect(digits(try? BigMath.log10(.two)), "0.301029995663981195213738894724493026768189881", "log 2")
    expect(digits(try? BigMath.sin(.one, unit: .radians)), "0.841470984807896506652502321630298999622563061", "sin 1 rad")
    expect(digits(try? BigMath.cos(.one, unit: .radians)), "0.540302305868139717400936607442976603732310421", "cos 1 rad")
    expect(digits(try? BigMath.tan(.one, unit: .radians)), "1.55740772465490223050697480745836017308725077", "tan 1 rad")
    expect(digits(try? BigMath.sin(BigDecimal(20), unit: .degrees)), "0.342020143325668733044099614682259580763083368", "sin 20°")
    expect(digits(try? BigMath.asin(d("0.3"), unit: .radians)), "0.304692654015397507972002961227529166954560032", "arcsin 0.3")
    expect(digits(BigMath.atan(.two, unit: .radians)), "1.10714871779409050301706546017853704007004765", "arctan 2")
    expect(digits(try? BigMath.sinh(.one)), "1.17520119364380145688238185059560081515571798", "sinh 1")
    expect(digits(try? BigMath.asinh(.one)), "0.881373587019543025232609324979792309028160328", "arsinh 1")
    expect(digits(try? BigMath.atanh(d("0.5"))), "0.549306144334054845697622618461262852323745279", "artanh 0.5")
    expect(digits(BigMath.cubeRoot(.two)), "1.25992104989487316476721060727822835057025146", "∛2")
    expect(digits(try? BigMath.factorial(d("0.5"))), "0.886226925452758013649083741670572591398774728", "0.5! is half the root of pi")
    expect(digits(try? BigMath.factorial(d("2.5"))), "3.32335097044784255118406403126464721774540523", "2.5!")
    expect(digits(try? BigMath.power(.two, d("0.5"))), "1.41421356237309504880168872420969807856967188", "2 to the 0.5")

    // What is exact in decimal comes out exact, not a hair off.
    func exact(_ value: BigDecimal?) -> String { value?.description ?? "nil" }
    expect(exact(try? BigMath.sin(BigDecimal(30), unit: .degrees)), "0.5", "sin 30° is exactly 0.5")
    expect(exact(try? BigMath.sin(BigDecimal(180), unit: .degrees)) + exact(try? BigMath.cos(BigDecimal(90), unit: .degrees))
           + exact(try? BigMath.sin(BigDecimal(-360), unit: .degrees)) + exact(try? BigMath.cos(BigDecimal(300), unit: .grads)), "0000",
           "the sines and cosines that are zero are zero")
    expect(exact(try? BigMath.cos(BigDecimal(60), unit: .degrees)) + " " + exact(try? BigMath.tan(BigDecimal(45), unit: .degrees))
           + " " + exact(try? BigMath.tan(BigDecimal(50), unit: .grads)) + " " + exact(try? BigMath.sin(BigDecimal(-90), unit: .degrees)),
           "0.5 1 1 -1", "round angles give round results")
    expect(exact(try? BigMath.asin(d("0.5"), unit: .degrees)) + " " + exact(try? BigMath.acos(d("0.5"), unit: .degrees)) + " "
           + exact(BigMath.atan(.one, unit: .degrees)) + " " + exact(BigMath.atan(.one, unit: .grads)) + " " + exact(try? BigMath.acos(d("-1"), unit: .degrees)),
           "30 60 45 50 180", "and the inverses give the round angles back")
    expect(exact(try? BigMath.sin(BigMath.piDigits.rounded(BigMath.precision), unit: .radians)), "0", "the sine of the pi key is 0")
    expect(exact(try? BigMath.log10(BigDecimal(1000))) + " " + exact(try? BigMath.log10(d("0.001"))) + " " + exact(try? BigMath.ln(.one)), "3 -3 0",
           "logarithms of the powers of ten are whole")
    expect(exact(try? BigMath.sqrt(BigDecimal(144))) + " " + exact(BigMath.cubeRoot(BigDecimal(-27))) + " " + exact(try? BigMath.sqrt(d("0.0001"))),
           "12 -3 0.01", "roots of perfect powers are exact")
    expect(exact(try? BigMath.power(.two, BigDecimal(100))), "1267650600228229401496703205376", "2 to the 100 is exact")
    expect(exact(try? BigMath.power(.two, BigDecimal(-2))) + " " + exact(try? BigMath.power(BigDecimal(-2), BigDecimal(3))) + " "
           + exact(try? BigMath.power(.zero, .zero)) + " " + exact(try? BigMath.power(BigDecimal(4), d("0.5"))), "0.25 -8 1 2", "powers with their signs")
    expect(exact(try? BigMath.root(BigDecimal(32), BigDecimal(5))) + " " + exact(try? BigMath.root(BigDecimal(-32), BigDecimal(5))), "2 -2",
           "the y-th root, odd roots of negative numbers included")
    expect(exact(try? BigMath.factorial(BigDecimal(20))), "2432902008176640000", "20!")
    expect(exact(try? BigMath.factorial(.zero)), "1", "0! is 1")
    expect(exact(BigMath.toDegreesMinutesSeconds(d("2.5"))) + " " + exact(BigMath.fromDegreesMinutesSeconds(d("2.3"))) + " "
           + exact(BigMath.toDegreesMinutesSeconds(d("10.2575"))), "2.3 2.5 10.1527", "degrees to degrees, minutes and seconds and back")

    func failure(_ body: () throws -> BigDecimal) -> CalcError? {
        do { _ = try body(); return nil } catch { return error as? CalcError }
    }
    check(failure { try BigMath.sqrt(BigDecimal(-4)) } == .invalidInput && failure { try BigMath.ln(.zero) } == .invalidInput
          && failure { try BigMath.log10(BigDecimal(-1)) } == .invalidInput, "roots and logarithms outside their domain are refused")
    check(failure { try BigMath.asin(.two, unit: .degrees) } == .invalidInput && failure { try BigMath.acosh(d("0.5")) } == .invalidInput
          && failure { try BigMath.atanh(.one) } == .invalidInput, "so are the inverse functions")
    check(failure { try BigMath.tan(BigDecimal(90), unit: .degrees) } == .invalidInput && failure { try BigMath.tan(BigDecimal(100), unit: .grads) } == .invalidInput,
          "the tangent of a right angle is refused")
    check(failure { try BigMath.factorial(BigDecimal(-3)) } == .invalidInput && failure { try BigMath.factorial(BigDecimal(3249)) } == .overflow,
          "the factorial of a negative whole number is refused, and of a number too large overflows")
    check(failure { try BigMath.power(BigDecimal(-8), d("0.5")) } == .invalidInput && failure { try BigMath.power(.zero, BigDecimal(-1)) } == .divideByZero
          && failure { try BigMath.exp(BigDecimal(30000)) } == .overflow, "powers outside the real numbers or the range are refused")
}
