import Foundation

/// A decimal number of any size: `digits` read as an integer, times ten to the `exponent`.
/// Arithmetic is done in base ten, so 0.1 + 0.2 is 0.3, and each operation takes the number of
/// significant digits to keep. No Double takes part in a result.
struct BigDecimal: Equatable, Comparable, CustomStringConvertible {
    /// Most significant first, without zeros at either end; empty for zero.
    private(set) var digits: [UInt8] = []
    private(set) var exponent = 0
    private(set) var isNegative = false

    static let zero = BigDecimal()
    static let one = BigDecimal(1)
    static let two = BigDecimal(2)
    static let ten = BigDecimal(10)

    init() {}

    init(_ value: Int) {
        var rest = value.magnitude
        var reversed: [UInt8] = []
        while rest > 0 {
            reversed.append(UInt8(rest % 10))
            rest /= 10
        }
        self.init(negative: value < 0, digits: reversed.reversed(), exponent: 0)
    }

    init(_ value: UInt64) {
        var rest = value
        var reversed: [UInt8] = []
        while rest > 0 {
            reversed.append(UInt8(rest % 10))
            rest /= 10
        }
        self.init(negative: false, digits: reversed.reversed(), exponent: 0)
    }

    init(negative: Bool, digits: [UInt8], exponent: Int) {
        self.digits = digits
        self.exponent = exponent
        isNegative = negative
        normalize()
    }

    /// "-12.5", "3", ".5", "1.2e-7": ASCII digits with a point; nil for anything else.
    init?(_ text: String) {
        var negative = false
        var mantissa: [UInt8] = []
        var fraction = 0
        var seenPoint = false, seenDigit = false
        var characters = Substring(text)
        if let first = characters.first, first == "-" || first == "+" {
            negative = first == "-"
            characters = characters.dropFirst()
        }
        var power = 0
        while let character = characters.first {
            characters = characters.dropFirst()
            if let value = character.wholeNumberValue, character.isASCII {
                mantissa.append(UInt8(value))
                if seenPoint { fraction += 1 }
                seenDigit = true
            } else if character == ".", !seenPoint {
                seenPoint = true
            } else if character == "e" || character == "E" {
                guard seenDigit, let value = Int(characters), characters.first != " " else { return nil }
                power = value
                characters = ""
            } else {
                return nil
            }
        }
        guard seenDigit else { return nil }
        self.init(negative: negative, digits: mantissa, exponent: power - fraction)
    }

    private mutating func normalize() {
        if let first = digits.firstIndex(where: { $0 != 0 }) {
            if first > 0 { digits.removeFirst(first) }
            var trailing = 0
            while digits[digits.count - 1 - trailing] == 0 { trailing += 1 }
            if trailing > 0 {
                digits.removeLast(trailing)
                exponent += trailing
            }
        } else {
            digits = []
            exponent = 0
            isNegative = false
        }
    }

    var isZero: Bool { digits.isEmpty }
    var isInteger: Bool { exponent >= 0 }
    /// The number of digits before the decimal point: 123.4 has 3, 0.05 has -1, zero has 0.
    var magnitude10: Int { digits.isEmpty ? 0 : digits.count + exponent }

    var negated: BigDecimal {
        var copy = self
        if !isZero { copy.isNegative.toggle() }
        return copy
    }

    var magnitude: BigDecimal {
        var copy = self
        copy.isNegative = false
        return copy
    }

    /// Times ten to `power`, exactly.
    func scaled(byPowerOfTen power: Int) -> BigDecimal {
        var copy = self
        if !isZero { copy.exponent += power }
        return copy
    }

    /// Kept to `precision` significant digits, the half rounded away from zero.
    func rounded(_ precision: Int) -> BigDecimal {
        guard digits.count > precision, precision > 0 else { return self }
        var kept = Array(digits[0..<precision])
        var power = exponent + digits.count - precision
        if digits[precision] >= 5 {
            var index = precision - 1
            while index >= 0 {
                if kept[index] == 9 {
                    kept[index] = 0
                    index -= 1
                } else {
                    kept[index] += 1
                    break
                }
            }
            if index < 0 {
                kept = [1] + [UInt8](repeating: 0, count: precision - 1)
                power += 1
            }
        }
        return BigDecimal(negative: isNegative, digits: kept, exponent: power)
    }

    /// The integer part, towards zero.
    var truncated: BigDecimal {
        guard exponent < 0 else { return self }
        let keep = digits.count + exponent
        guard keep > 0 else { return .zero }
        return BigDecimal(negative: isNegative, digits: Array(digits[0..<keep]), exponent: 0)
    }

    /// The value as an Int when it is an integer that fits.
    var intValue: Int? {
        guard isInteger, magnitude10 <= 18 else { return nil }
        var value = 0
        for digit in digits { value = value * 10 + Int(digit) }
        for _ in 0..<exponent { value *= 10 }
        return isNegative ? -value : value
    }

    /// Only for first guesses of the iterations; never shown.
    var doubleValue: Double { Double(description) ?? 0 }

    /// "-1.25e-7"-style text that `init(_:)` reads back; plain for numbers of ordinary size.
    var description: String {
        guard !isZero else { return "0" }
        let all = String(decoding: digits.map { $0 + 48 }, as: UTF8.self)
        let sign = isNegative ? "-" : ""
        let point = magnitude10
        if exponent >= 0, point <= 60 {
            return sign + all + String(repeating: "0", count: exponent)
        }
        if point > 0, point <= 60 {
            return sign + all.prefix(point) + "." + all.dropFirst(point)
        }
        if point <= 0, point > -20 {
            return sign + "0." + String(repeating: "0", count: -point) + all
        }
        return sign + all.prefix(1) + (all.count > 1 ? "." + all.dropFirst() : "") + "e\(point - 1)"
    }

    // MARK: Comparison

    private static func compareMagnitudes(_ a: BigDecimal, _ b: BigDecimal) -> Int {
        if a.isZero || b.isZero { return a.isZero ? (b.isZero ? 0 : -1) : 1 }
        if a.magnitude10 != b.magnitude10 { return a.magnitude10 < b.magnitude10 ? -1 : 1 }
        for index in 0..<max(a.digits.count, b.digits.count) {
            let x = index < a.digits.count ? a.digits[index] : 0
            let y = index < b.digits.count ? b.digits[index] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }

    static func < (a: BigDecimal, b: BigDecimal) -> Bool {
        if a.isNegative != b.isNegative { return a.isNegative }
        let order = compareMagnitudes(a, b)
        return a.isNegative ? order > 0 : order < 0
    }

    // MARK: Arithmetic

    /// The digits of both as integers at the lower of the two exponents.
    private static func aligned(_ a: BigDecimal, _ b: BigDecimal) -> (a: [UInt8], b: [UInt8], exponent: Int) {
        let low = min(a.exponent, b.exponent)
        return (a.digits + [UInt8](repeating: 0, count: a.exponent - low),
                b.digits + [UInt8](repeating: 0, count: b.exponent - low), low)
    }

    func adding(_ other: BigDecimal, precision: Int) -> BigDecimal {
        if isZero { return other.rounded(precision) }
        if other.isZero { return rounded(precision) }
        // A term too small to reach the kept digits only pads the other with zeros.
        if magnitude10 - other.magnitude10 > precision + digits.count + 2 { return rounded(precision) }
        if other.magnitude10 - magnitude10 > precision + other.digits.count + 2 { return other.rounded(precision) }
        let (x, y, low) = Self.aligned(self, other)
        if isNegative == other.isNegative {
            return BigDecimal(negative: isNegative, digits: Self.sum(x, y), exponent: low).rounded(precision)
        }
        let order = Self.compareIntegers(x, y)
        if order == 0 { return .zero }
        let difference = order > 0 ? Self.difference(x, y) : Self.difference(y, x)
        return BigDecimal(negative: order > 0 ? isNegative : other.isNegative, digits: difference, exponent: low).rounded(precision)
    }

    func subtracting(_ other: BigDecimal, precision: Int) -> BigDecimal {
        adding(other.negated, precision: precision)
    }

    func multiplied(by other: BigDecimal, precision: Int) -> BigDecimal {
        guard !isZero, !other.isZero else { return .zero }
        var product = [Int](repeating: 0, count: digits.count + other.digits.count)
        for (i, x) in digits.enumerated() where x != 0 {
            for (j, y) in other.digits.enumerated() {
                product[i + j + 1] += Int(x) * Int(y)
            }
        }
        var carry = 0
        var result = [UInt8](repeating: 0, count: product.count)
        for index in stride(from: product.count - 1, through: 0, by: -1) {
            let total = product[index] + carry
            result[index] = UInt8(total % 10)
            carry = total / 10
        }
        return BigDecimal(negative: isNegative != other.isNegative, digits: result, exponent: exponent + other.exponent)
            .rounded(precision)
    }

    /// The divisor must not be zero.
    func divided(by other: BigDecimal, precision: Int) -> BigDecimal {
        precondition(!other.isZero, "division by zero")
        guard !isZero else { return .zero }
        let extra = max(0, precision + 2 + other.digits.count - digits.count)
        var (quotient, rest) = Self.divide(digits + [UInt8](repeating: 0, count: extra), other.digits)
        var power = exponent - extra - other.exponent
        // What is left of the division decides a tie: one more digit keeps the rounding right.
        if rest.contains(where: { $0 != 0 }) {
            quotient.append(1)
            power -= 1
        }
        return BigDecimal(negative: isNegative != other.isNegative, digits: quotient, exponent: power).rounded(precision)
    }

    /// Division by a small whole number, for the terms of the series.
    func divided(by small: Int, precision: Int) -> BigDecimal {
        precondition(small != 0, "division by zero")
        guard !isZero else { return .zero }
        let divisor = small.magnitude
        let extra = max(0, precision + 22 - digits.count)
        var quotient: [UInt8] = []
        quotient.reserveCapacity(digits.count + extra + 1)
        var rest: UInt = 0
        for index in 0..<(digits.count + extra) {
            rest = rest * 10 + UInt(index < digits.count ? digits[index] : 0)
            quotient.append(UInt8(rest / divisor))
            rest %= divisor
        }
        var power = exponent - extra
        if rest != 0 {
            quotient.append(1)
            power -= 1
        }
        return BigDecimal(negative: isNegative != (small < 0), digits: quotient, exponent: power).rounded(precision)
    }

    /// The whole quotient towards zero and what is left, with the sign of the dividend; exact.
    func quotientAndRemainder(dividingBy other: BigDecimal) -> (quotient: BigDecimal, remainder: BigDecimal) {
        precondition(!other.isZero, "division by zero")
        if Self.compareMagnitudes(self, other) < 0 { return (.zero, self) }
        let (x, y, low) = Self.aligned(self, other)
        let (quotient, rest) = Self.divide(x, y)
        return (BigDecimal(negative: isNegative != other.isNegative, digits: quotient, exponent: 0),
                BigDecimal(negative: isNegative, digits: rest, exponent: low))
    }

    // MARK: Whole numbers as digit arrays

    private static func stripped(_ digits: [UInt8]) -> ArraySlice<UInt8> {
        digits[(digits.firstIndex(where: { $0 != 0 }) ?? digits.count)...]
    }

    private static func compareIntegers(_ a: [UInt8], _ b: [UInt8]) -> Int {
        let x = stripped(a), y = stripped(b)
        if x.count != y.count { return x.count < y.count ? -1 : 1 }
        for (p, q) in zip(x, y) where p != q { return p < q ? -1 : 1 }
        return 0
    }

    private static func sum(_ a: [UInt8], _ b: [UInt8]) -> [UInt8] {
        let count = max(a.count, b.count) + 1
        var result = [UInt8](repeating: 0, count: count)
        var carry: UInt8 = 0
        for offset in 1...count {
            let x = offset <= a.count ? a[a.count - offset] : 0
            let y = offset <= b.count ? b[b.count - offset] : 0
            let total = x + y + carry
            result[count - offset] = total % 10
            carry = total / 10
        }
        return result
    }

    /// `a - b`, with `a` not smaller than `b`.
    private static func difference(_ a: [UInt8], _ b: [UInt8]) -> [UInt8] {
        var result = a
        var borrow = 0
        for offset in 1...a.count {
            let x = Int(a[a.count - offset]) - borrow
            let y = offset <= b.count ? Int(b[b.count - offset]) : 0
            borrow = x < y ? 1 : 0
            result[a.count - offset] = UInt8(x - y + borrow * 10)
        }
        return result
    }

    /// Long division of whole numbers: one digit of the quotient for each digit of `a`.
    private static func divide(_ a: [UInt8], _ b: [UInt8]) -> (quotient: [UInt8], rest: [UInt8]) {
        let divisor = Array(stripped(b))
        let width = divisor.count + 1
        // The running rest, always `width` digits wide.
        var rest = [UInt8](repeating: 0, count: width)
        var quotient: [UInt8] = []
        quotient.reserveCapacity(a.count)
        let offset = width - divisor.count
        for digit in a {
            for index in 1..<width { rest[index - 1] = rest[index] }
            rest[width - 1] = digit
            var count: UInt8 = 0
            while true {
                // Is the rest still at least the divisor?
                var order = rest[0] != 0 ? 1 : 0
                if order == 0 {
                    for index in 0..<divisor.count where rest[index + offset] != divisor[index] {
                        order = rest[index + offset] < divisor[index] ? -1 : 1
                        break
                    }
                }
                if order < 0 { break }
                var borrow = 0
                for index in stride(from: divisor.count - 1, through: 0, by: -1) {
                    let x = Int(rest[index + offset]) - borrow
                    let y = Int(divisor[index])
                    borrow = x < y ? 1 : 0
                    rest[index + offset] = UInt8(x - y + borrow * 10)
                }
                if borrow > 0 { rest[0] -= 1 }
                count += 1
            }
            quotient.append(count)
        }
        return (quotient, rest)
    }
}
