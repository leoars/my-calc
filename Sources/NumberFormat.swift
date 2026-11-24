import Foundation

enum Radix: Int, CaseIterable {
    case hex = 16, dec = 10, oct = 8, bin = 2
}

enum WordSize: Int, CaseIterable {
    case qword = 64, dword = 32, word = 16, byte = 8

    var mask: UInt64 { self == .qword ? .max : (1 << UInt64(rawValue)) - 1 }
}

/// A number while it is being typed: what the person keyed, kept as text so the trailing zeros
/// and the point stay on the display.
struct Entry: Equatable {
    /// Before the point; in the programmer mode, the digits in the current base.
    var digits = "0"
    /// After the point; nil until the point is typed.
    var fraction: String?
    var isNegative = false
    /// After Exp; nil until it is pressed.
    var exponent: String?
    var exponentIsNegative = false

    var significantDigits: Int { (digits == "0" ? 0 : digits.count) + (fraction?.count ?? 0) }

    var value: BigDecimal {
        var text = (isNegative ? "-" : "") + digits + "." + (fraction ?? "")
        if let exponent { text += "e" + (exponentIsNegative ? "-" : "") + (exponent.isEmpty ? "0" : exponent) }
        return BigDecimal(text) ?? .zero
    }
}

/// How numbers are written on the display: the separators of the person's region, digit
/// grouping, and at most 32 significant digits.
struct NumberFormat: Equatable {
    static let displayDigits = 32

    var decimalSeparator = "."
    var groupingSeparator = ","
    var grouping = false

    init(decimalSeparator: String = ".", groupingSeparator: String = ",", grouping: Bool = false) {
        self.decimalSeparator = decimalSeparator
        self.groupingSeparator = groupingSeparator
        self.grouping = grouping
    }

    init(locale: Locale, grouping: Bool) {
        decimalSeparator = locale.decimalSeparator ?? "."
        groupingSeparator = locale.groupingSeparator ?? ","
        // A region may use the same sign for both; the display must not.
        if groupingSeparator == decimalSeparator || groupingSeparator.isEmpty { groupingSeparator = decimalSeparator == "," ? "." : "," }
        self.grouping = grouping
    }

    /// Digits in groups counted from the right.
    static func grouped(_ digits: String, by size: Int, separator: String) -> String {
        guard digits.count > size else { return digits }
        var result = ""
        for (offset, character) in digits.enumerated() {
            if offset > 0, (digits.count - offset) % size == 0 { result += separator }
            result.append(character)
        }
        return result
    }

    private func whole(_ digits: String, grouping: Bool) -> String {
        grouping ? Self.grouped(digits, by: 3, separator: groupingSeparator) : digits
    }

    /// The value as the display shows it. `scientific` forces the exponent form (the F-E key);
    /// it is also used when the number does not fit in 32 digits.
    func string(_ value: BigDecimal, scientific: Bool = false, grouping: Bool? = nil) -> String {
        let rounded = value.rounded(Self.displayDigits)
        guard !rounded.isZero else { return scientific ? "0" + decimalSeparator + "e+0" : "0" }
        let digits = String(decoding: rounded.digits.map { $0 + 48 }, as: UTF8.self)
        let sign = rounded.isNegative ? "-" : ""
        let point = rounded.magnitude10
        let groups = grouping ?? self.grouping
        if !scientific {
            if point > 0, point <= Self.displayDigits {
                if digits.count <= point {
                    return sign + whole(digits + String(repeating: "0", count: point - digits.count), grouping: groups)
                }
                return sign + whole(String(digits.prefix(point)), grouping: groups) + decimalSeparator + digits.dropFirst(point)
            }
            if point <= 0, digits.count - point <= Self.displayDigits {
                return sign + "0" + decimalSeparator + String(repeating: "0", count: -point) + digits
            }
        }
        let power = point - 1
        return sign + digits.prefix(1) + decimalSeparator + digits.dropFirst() + "e" + (power < 0 ? "-" : "+") + String(abs(power))
    }

    /// A number being typed.
    func string(_ entry: Entry, grouping: Bool? = nil) -> String {
        var text = (entry.isNegative ? "-" : "") + whole(entry.digits, grouping: grouping ?? self.grouping)
        if let fraction = entry.fraction { text += decimalSeparator + fraction }
        if let exponent = entry.exponent {
            if entry.fraction == nil { text += decimalSeparator }
            text += "e" + (entry.exponentIsNegative ? "-" : "+") + (exponent.isEmpty ? "0" : exponent)
        }
        return text
    }

    /// Digits of the programmer mode: hexadecimal and binary in fours, octal in threes.
    func string(digits: String, radix: Radix, negative: Bool = false, grouping: Bool? = nil) -> String {
        guard grouping ?? self.grouping else { return (negative ? "-" : "") + digits }
        switch radix {
        case .dec: return (negative ? "-" : "") + Self.grouped(digits, by: 3, separator: groupingSeparator)
        case .oct: return Self.grouped(digits, by: 3, separator: " ")
        case .hex, .bin: return Self.grouped(digits, by: 4, separator: " ")
        }
    }

    /// A whole number of the programmer mode: signed in decimal, the bits of the word otherwise.
    func string(_ value: Int64, radix: Radix, wordSize: WordSize, grouping: Bool? = nil) -> String {
        if radix == .dec {
            return string(digits: String(value.magnitude), radix: .dec, negative: value < 0, grouping: grouping)
        }
        let bits = UInt64(bitPattern: value) & wordSize.mask
        return string(digits: String(bits, radix: radix.rawValue, uppercase: true), radix: radix, grouping: grouping)
    }
}
