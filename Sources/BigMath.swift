import Foundation

/// What a calculation can fail with; the interface shows one line for each.
enum CalcError: Error, Equatable {
    case divideByZero
    case undefined
    case invalidInput
    case overflow

    var messageKey: String {
        switch self {
        case .divideByZero: return "error.divideByZero"
        case .undefined: return "error.undefined"
        case .invalidInput: return "error.invalidInput"
        case .overflow: return "error.overflow"
        }
    }
}

enum AngleUnit: Int, CaseIterable {
    case degrees, radians, grads

    /// A quarter turn in the unit.
    var quarter: Int? {
        switch self {
        case .degrees: return 90
        case .grads: return 100
        case .radians: return nil
        }
    }
}

/// The functions of the scientific mode, on `BigDecimal`. Results carry `precision` significant
/// digits; the work is done with `guardDigits` more, so a result that is exact in decimal (the
/// logarithm of 1000, the sine of 30 degrees) comes out exact.
enum BigMath {
    /// Digits every value of the calculator is kept with; the display shows 32 of them.
    static let precision = 50
    static let guardDigits = 14
    static var working: Int { precision + guardDigits }
    /// Numbers beyond ten to this power, either way, are an overflow or zero.
    static let maximumExponent = 10_000

    static let piDigits = BigDecimal("3.141592653589793238462643383279502884197169399375105820974944592307816406286208998628034825342117067982148086513282306647")!
    static var pi: BigDecimal { piDigits.rounded(working) }
    static var halfPi: BigDecimal { piDigits.divided(by: 2, precision: working) }

    private static var cachedLn10: BigDecimal?
    static var ln10: BigDecimal {
        if let cachedLn10 { return cachedLn10 }
        let value = (try? naturalLog(.ten, precision: working + 6)) ?? .zero
        cachedLn10 = value
        return value
    }

    // MARK: Exponential and logarithms

    static func exp(_ x: BigDecimal) throws -> BigDecimal { try exponential(x, precision: working).rounded(precision) }

    static func exponential(_ x: BigDecimal, precision p: Int) throws -> BigDecimal {
        if x.isZero { return .one }
        // e to 23100 is already past ten to the 10000.
        if x.magnitude10 > 5 || x.magnitude > BigDecimal(23_100) {
            if x.isNegative { return .zero }
            throw CalcError.overflow
        }
        // Halve the argument until the series is short, then square the result back.
        var halvings = 0
        var bound = x.magnitude.doubleValue
        while bound > 0.25 {
            bound /= 2
            halvings += 1
        }
        let w = p + halvings / 3 + 8
        var reduced = x
        for _ in 0..<halvings { reduced = reduced.divided(by: 2, precision: w) }
        var sum = BigDecimal.one, term = BigDecimal.one
        var k = 1
        while true {
            term = term.multiplied(by: reduced, precision: w).divided(by: k, precision: w)
            if term.isZero || term.magnitude10 < -w - 2 { break }
            sum = sum.adding(term, precision: w)
            k += 1
        }
        for _ in 0..<halvings { sum = sum.multiplied(by: sum, precision: w) }
        return sum.rounded(p)
    }

    static func ln(_ x: BigDecimal) throws -> BigDecimal { try naturalLog(x, precision: working).rounded(precision) }

    static func naturalLog(_ x: BigDecimal, precision p: Int) throws -> BigDecimal {
        guard !x.isZero, !x.isNegative else { throw CalcError.invalidInput }
        if x == .one { return .zero }
        let w = p + 8
        // A first guess from Double, then Halley's step on the exponential: each one triples the
        // number of right digits.
        let power = x.magnitude10 - 1
        let mantissa = x.scaled(byPowerOfTen: -power).doubleValue
        var y = BigDecimal(String(Foundation.log(mantissa) + Double(power) * 2.302585092994046)) ?? .zero
        for _ in 0..<8 {
            let e = try exponential(y, precision: w)
            let step = x.subtracting(e, precision: w).multiplied(by: .two, precision: w)
                .divided(by: x.adding(e, precision: w), precision: w)
            y = y.adding(step, precision: w)
            if step.isZero || step.magnitude10 < y.magnitude10 - w / 3 - 2 { break }
        }
        return y.rounded(p)
    }

    static func log10(_ x: BigDecimal) throws -> BigDecimal {
        try naturalLog(x, precision: working).divided(by: ln10, precision: working).rounded(precision)
    }

    static func powerOfTen(_ x: BigDecimal) throws -> BigDecimal { try power(.ten, x) }

    // MARK: Roots and powers

    static func sqrt(_ x: BigDecimal) throws -> BigDecimal {
        guard !x.isNegative else { throw CalcError.invalidInput }
        return newtonRoot(x, degree: 2, precision: working).rounded(precision)
    }

    static func cubeRoot(_ x: BigDecimal) -> BigDecimal {
        let value = newtonRoot(x.magnitude, degree: 3, precision: working).rounded(precision)
        return x.isNegative ? value.negated : value
    }

    /// Newton's iteration for the square or the cube root of a number that is not negative.
    private static func newtonRoot(_ x: BigDecimal, degree: Int, precision w: Int) -> BigDecimal {
        guard !x.isZero else { return .zero }
        // The mantissa between 1 and ten to the degree gives the first guess.
        let magnitude = x.magnitude10 - 1
        let shift = (magnitude >= 0 ? magnitude / degree : -((-magnitude + degree - 1) / degree))
        let mantissa = x.scaled(byPowerOfTen: -shift * degree).doubleValue
        let guess = degree == 2 ? mantissa.squareRoot() : Foundation.cbrt(mantissa)
        var y = (BigDecimal(String(guess)) ?? .one).scaled(byPowerOfTen: shift)
        for _ in 0..<8 {
            let next: BigDecimal
            if degree == 2 {
                next = y.adding(x.divided(by: y, precision: w), precision: w).divided(by: 2, precision: w)
            } else {
                let square = y.multiplied(by: y, precision: w)
                next = y.multiplied(by: .two, precision: w).adding(x.divided(by: square, precision: w), precision: w)
                    .divided(by: 3, precision: w)
            }
            let step = next.subtracting(y, precision: w)
            y = next
            if step.isZero || step.magnitude10 < y.magnitude10 - w / 2 - 2 { break }
        }
        // One more step settles the last digits.
        if degree == 2 {
            y = y.adding(x.divided(by: y, precision: w), precision: w).divided(by: 2, precision: w)
        } else {
            let square = y.multiplied(by: y, precision: w)
            y = y.multiplied(by: .two, precision: w).adding(x.divided(by: square, precision: w), precision: w)
                .divided(by: 3, precision: w)
        }
        return y
    }

    static func power(_ x: BigDecimal, _ y: BigDecimal) throws -> BigDecimal {
        if y.isZero { return .one }
        if x.isZero {
            if y.isNegative { throw CalcError.divideByZero }
            return .zero
        }
        let w = working
        if y.isInteger, let count = y.intValue, count.magnitude <= 100_000 {
            var result = BigDecimal.one, base = x
            var rest = count.magnitude
            while rest > 0 {
                if rest & 1 == 1 { result = result.multiplied(by: base, precision: w) }
                rest >>= 1
                if rest > 0 { base = base.multiplied(by: base, precision: w) }
                if abs(result.magnitude10) > 3 * maximumExponent || abs(base.magnitude10) > 3 * maximumExponent {
                    // Far beyond the range either way.
                    let grows = (x.magnitude > .one) != (count < 0)
                    if grows { throw CalcError.overflow }
                    return .zero
                }
            }
            if count < 0 { result = BigDecimal.one.divided(by: result, precision: w) }
            return result.rounded(precision)
        }
        if x.isNegative {
            // A negative base only has a real power for a whole exponent.
            guard y.isInteger else { throw CalcError.invalidInput }
            let value = try power(x.magnitude, y)
            let odd = y.exponent == 0 && (y.digits.last ?? 0) % 2 == 1
            return odd ? value.negated : value
        }
        let exponent = try naturalLog(x, precision: w + 8).multiplied(by: y, precision: w + 8)
        return try exponential(exponent, precision: w).rounded(precision)
    }

    /// The `y`-th root of `x`.
    static func root(_ x: BigDecimal, _ y: BigDecimal) throws -> BigDecimal {
        guard !y.isZero else { throw CalcError.invalidInput }
        if y == .two { return try sqrt(x) }
        if y == BigDecimal(3) { return cubeRoot(x) }
        let w = working
        if x.isNegative {
            // Odd roots of negative numbers are real.
            guard y.isInteger, y.exponent == 0, (y.digits.last ?? 0) % 2 == 1 else { throw CalcError.invalidInput }
            return try root(x.magnitude, y).negated
        }
        if x.isZero {
            if y.isNegative { throw CalcError.divideByZero }
            return .zero
        }
        let exponent = try naturalLog(x, precision: w + 8).divided(by: y, precision: w + 8)
        return try exponential(exponent, precision: w).rounded(precision)
    }

    // MARK: Trigonometry

    /// Sine of an angle in radians no larger than a few turns.
    private static func sineSeries(_ x: BigDecimal, precision w: Int) -> BigDecimal {
        let square = x.multiplied(by: x, precision: w)
        var sum = x, term = x
        var k = 1
        while !term.isZero {
            term = term.multiplied(by: square, precision: w).divided(by: (k + 1) * (k + 2), precision: w).negated
            if term.magnitude10 < -w - 2 { break }
            sum = sum.adding(term, precision: w)
            k += 2
        }
        return sum
    }

    private static func cosineSeries(_ x: BigDecimal, precision w: Int) -> BigDecimal {
        let square = x.multiplied(by: x, precision: w)
        var sum = BigDecimal.one, term = BigDecimal.one
        var k = 0
        while !term.isZero {
            term = term.multiplied(by: square, precision: w).divided(by: (k + 1) * (k + 2), precision: w).negated
            if term.magnitude10 < -w - 2 { break }
            sum = sum.adding(term, precision: w)
            k += 2
        }
        return sum
    }

    /// Sine and cosine together. Degrees and grads are reduced exactly to the first quarter turn,
    /// so the round angles give round results; radians are reduced with the digits of pi.
    static func sineAndCosine(_ x: BigDecimal, unit: AngleUnit) throws -> (sine: BigDecimal, cosine: BigDecimal) {
        let w = working + 4
        if let quarter = unit.quarter {
            let turn = BigDecimal(4 * quarter)
            var angle = x.quotientAndRemainder(dividingBy: turn).remainder
            if angle.isNegative { angle = angle.adding(turn, precision: 200) }
            // Which quarter, and the angle inside it.
            let (which, inside) = angle.quotientAndRemainder(dividingBy: BigDecimal(quarter))
            let quadrant = which.intValue ?? 0
            var sine: BigDecimal, cosine: BigDecimal
            if inside.isZero {
                (sine, cosine) = (.zero, .one)
            } else {
                let radians = inside.multiplied(by: piDigits, precision: w).divided(by: 2 * quarter, precision: w)
                (sine, cosine) = (sineSeries(radians, precision: w), cosineSeries(radians, precision: w))
            }
            switch quadrant {
            case 1: (sine, cosine) = (cosine, sine.negated)
            case 2: (sine, cosine) = (sine.negated, cosine.negated)
            case 3: (sine, cosine) = (cosine.negated, sine)
            default: break
            }
            return (sine.rounded(precision), cosine.rounded(precision))
        }
        // Beyond this the digits of pi kept here no longer place the angle inside its turn.
        guard x.magnitude10 <= 40 else { throw CalcError.invalidInput }
        let digits = w + max(0, x.magnitude10) + 4
        let twoPi = piDigits.multiplied(by: .two, precision: digits)
        let turns = x.divided(by: twoPi, precision: digits).adding(BigDecimal("0.5")!, precision: digits)
        var whole = turns.truncated
        if turns.isNegative, whole != turns { whole = whole.subtracting(.one, precision: digits) }
        let angle = x.subtracting(whole.multiplied(by: twoPi, precision: digits + 40), precision: w)
        var sine = sineSeries(angle, precision: w), cosine = cosineSeries(angle, precision: w)
        // The pi key gives pi to fifty digits: what is left of its sine is the rounding, not a value.
        if x.magnitude10 >= 1 {
            if sine.magnitude10 < -(precision - 6) { sine = .zero }
            if cosine.magnitude10 < -(precision - 6) { cosine = .zero }
        }
        return (sine.rounded(precision), cosine.rounded(precision))
    }

    static func sin(_ x: BigDecimal, unit: AngleUnit) throws -> BigDecimal { try sineAndCosine(x, unit: unit).sine }
    static func cos(_ x: BigDecimal, unit: AngleUnit) throws -> BigDecimal { try sineAndCosine(x, unit: unit).cosine }

    static func tan(_ x: BigDecimal, unit: AngleUnit) throws -> BigDecimal {
        let (sine, cosine) = try sineAndCosine(x, unit: unit)
        guard !cosine.isZero else { throw CalcError.invalidInput }
        return sine.divided(by: cosine, precision: precision)
    }

    /// The arc tangent, in radians.
    private static func arcTangent(_ x: BigDecimal, precision w: Int) -> BigDecimal {
        if x.isZero { return .zero }
        if x.isNegative { return arcTangent(x.negated, precision: w).negated }
        if x > .one {
            let inverse = arcTangent(BigDecimal.one.divided(by: x, precision: w), precision: w)
            return piDigits.divided(by: 2, precision: w).subtracting(inverse, precision: w)
        }
        // Three halvings of the angle bring the argument under a tenth.
        var reduced = x
        for _ in 0..<3 {
            let root = newtonRoot(BigDecimal.one.adding(reduced.multiplied(by: reduced, precision: w), precision: w), degree: 2, precision: w)
            reduced = reduced.divided(by: BigDecimal.one.adding(root, precision: w), precision: w)
        }
        let square = reduced.multiplied(by: reduced, precision: w)
        var sum = reduced, power = reduced
        var k = 1
        while true {
            power = power.multiplied(by: square, precision: w).negated
            k += 2
            let term = power.divided(by: k, precision: w)
            if term.isZero || term.magnitude10 < -w - 2 { break }
            sum = sum.adding(term, precision: w)
        }
        return sum.multiplied(by: BigDecimal(8), precision: w)
    }

    private static func fromRadians(_ radians: BigDecimal, unit: AngleUnit) -> BigDecimal {
        guard let quarter = unit.quarter else { return radians.rounded(precision) }
        return radians.multiplied(by: BigDecimal(2 * quarter), precision: working + 4)
            .divided(by: piDigits, precision: working + 4).rounded(precision)
    }

    static func atan(_ x: BigDecimal, unit: AngleUnit) -> BigDecimal {
        fromRadians(arcTangent(x, precision: working + 6), unit: unit)
    }

    static func asin(_ x: BigDecimal, unit: AngleUnit) throws -> BigDecimal {
        let w = working + 6
        guard x.magnitude <= .one else { throw CalcError.invalidInput }
        if x.magnitude == .one {
            let quarter = piDigits.divided(by: 2, precision: w)
            return fromRadians(x.isNegative ? quarter.negated : quarter, unit: unit)
        }
        let cosine = newtonRoot(BigDecimal.one.subtracting(x.multiplied(by: x, precision: w), precision: w), degree: 2, precision: w)
        return fromRadians(arcTangent(x.divided(by: cosine, precision: w), precision: w), unit: unit)
    }

    static func acos(_ x: BigDecimal, unit: AngleUnit) throws -> BigDecimal {
        let w = working + 6
        guard x.magnitude <= .one else { throw CalcError.invalidInput }
        if x.isZero { return fromRadians(piDigits.divided(by: 2, precision: w), unit: unit) }
        if x == .one { return .zero }
        let sine = newtonRoot(BigDecimal.one.subtracting(x.multiplied(by: x, precision: w), precision: w), degree: 2, precision: w)
        var angle = arcTangent(sine.divided(by: x.magnitude, precision: w), precision: w)
        if x.isNegative { angle = piDigits.rounded(w).subtracting(angle, precision: w) }
        return fromRadians(angle, unit: unit)
    }

    // MARK: Hyperbolic functions

    static func sinh(_ x: BigDecimal) throws -> BigDecimal {
        let w = working
        if x.magnitude10 < 0 {
            // Near zero the two exponentials cancel; the series does not.
            let square = x.multiplied(by: x, precision: w)
            var sum = x, term = x
            var k = 1
            while !term.isZero {
                term = term.multiplied(by: square, precision: w).divided(by: (k + 1) * (k + 2), precision: w)
                if term.magnitude10 < x.magnitude10 - w - 2 { break }
                sum = sum.adding(term, precision: w)
                k += 2
            }
            return sum.rounded(precision)
        }
        let e = try exponential(x, precision: w + 4)
        if e.isZero { throw CalcError.overflow }
        return e.subtracting(BigDecimal.one.divided(by: e, precision: w + 4), precision: w + 4)
            .divided(by: 2, precision: w).rounded(precision)
    }

    static func cosh(_ x: BigDecimal) throws -> BigDecimal {
        let w = working
        let e = try exponential(x.magnitude, precision: w + 4)
        return e.adding(BigDecimal.one.divided(by: e, precision: w + 4), precision: w + 4)
            .divided(by: 2, precision: w).rounded(precision)
    }

    static func tanh(_ x: BigDecimal) throws -> BigDecimal {
        if x.magnitude > BigDecimal(200) { return x.isNegative ? BigDecimal(-1) : .one }
        return try sinh(x).divided(by: try cosh(x), precision: precision)
    }

    static func asinh(_ x: BigDecimal) throws -> BigDecimal {
        let w = working + 6
        if x.isZero { return .zero }
        let size = x.magnitude
        // For a large argument the 1 under the root no longer changes it.
        let root = size.magnitude10 > w ? size
            : newtonRoot(size.multiplied(by: size, precision: 2 * w).adding(.one, precision: 2 * w), degree: 2, precision: 2 * w)
        let value = try naturalLog(size.adding(root, precision: 2 * w), precision: 2 * w).rounded(precision)
        return x.isNegative ? value.negated : value
    }

    static func acosh(_ x: BigDecimal) throws -> BigDecimal {
        let w = working + 6
        guard x >= .one else { throw CalcError.invalidInput }
        let root = x.magnitude10 > w ? x
            : newtonRoot(x.multiplied(by: x, precision: 2 * w).subtracting(.one, precision: 2 * w), degree: 2, precision: 2 * w)
        return try naturalLog(x.adding(root, precision: 2 * w), precision: w).rounded(precision)
    }

    static func atanh(_ x: BigDecimal) throws -> BigDecimal {
        let w = working + 6
        guard x.magnitude < .one else { throw CalcError.invalidInput }
        let ratio = BigDecimal.one.adding(x, precision: 2 * w).divided(by: BigDecimal.one.subtracting(x, precision: 2 * w), precision: 2 * w)
        return try naturalLog(ratio, precision: 2 * w).divided(by: 2, precision: w).rounded(precision)
    }

    // MARK: Factorial

    /// Numerators and denominators of the Bernoulli numbers B2, B4… for Stirling's series.
    private static let bernoulli: [(String, Int)] = [
        ("1", 6), ("-1", 30), ("1", 42), ("-1", 30), ("5", 66), ("-691", 2730), ("7", 6), ("-3617", 510),
        ("43867", 798), ("-174611", 330), ("854513", 138), ("-236364091", 2730), ("8553103", 6),
        ("-23749461029", 870), ("8615841276005", 14322), ("-7709321041217", 510), ("2577687858367", 6),
        ("-26315271553053477373", 1_919_190), ("2929993913841559", 6), ("-261082718496449122051", 13530),
        ("1520097643918070802691", 1806), ("-27833269579301024235023", 690), ("596451111593912163277961", 282),
        ("-5609403368997817686249127547", 46410), ("495057205241079648212477525", 66),
        ("-801165718135489957347924991853", 1590), ("29149963634884862421418123812691", 798),
        ("-2479392929313226753685415739663229", 870),
    ]

    /// `x!`: the product for whole numbers, the gamma function of `x + 1` for the others.
    static func factorial(_ x: BigDecimal) throws -> BigDecimal {
        let w = working
        if x.isInteger {
            guard !x.isNegative else { throw CalcError.invalidInput }
            // 3249! is past ten to the 10000.
            guard let count = x.intValue, count <= 3248 else { throw CalcError.overflow }
            var product = BigDecimal.one
            if count >= 2 {
                for factor in 2...count { product = product.multiplied(by: BigDecimal(factor), precision: w) }
            }
            return product.rounded(precision)
        }
        guard x.magnitude < BigDecimal(3249) else {
            if x.isNegative { return .zero }
            throw CalcError.overflow
        }
        return try gamma(x.adding(.one, precision: w), precision: w).rounded(precision)
    }

    private static func gamma(_ z: BigDecimal, precision w: Int) throws -> BigDecimal {
        if z < BigDecimal("0.5")! {
            // Reflection: gamma(z) gamma(1 - z) = pi / sin(pi z).
            let (_, inside) = z.quotientAndRemainder(dividingBy: .two)
            let sine = try sineAndCosine(inside.multiplied(by: BigDecimal(180), precision: 200), unit: .degrees).sine
            guard !sine.isZero else { throw CalcError.invalidInput }
            let other = try gamma(BigDecimal.one.subtracting(z, precision: w + 10), precision: w + 10)
            if other.isZero { throw CalcError.overflow }
            return piDigits.rounded(w + 10).divided(by: sine.multiplied(by: other, precision: w + 10), precision: w)
        }
        // Move the argument up to where Stirling's series converges fast, and divide back.
        var shifted = z
        var divisor = BigDecimal.one
        let p = w + 12
        while shifted < BigDecimal(45) {
            divisor = divisor.multiplied(by: shifted, precision: p)
            shifted = shifted.adding(.one, precision: p)
        }
        let logarithm = try naturalLog(shifted, precision: p)
        // ln gamma(z) = (z - 1/2) ln z - z + ln(2 pi) / 2 + sum of B2k / (2k (2k - 1) z^(2k - 1))
        var sum = shifted.subtracting(BigDecimal("0.5")!, precision: p).multiplied(by: logarithm, precision: p)
            .subtracting(shifted, precision: p)
            .adding(try naturalLog(piDigits.multiplied(by: .two, precision: p), precision: p).divided(by: 2, precision: p), precision: p)
        let inverse = BigDecimal.one.divided(by: shifted, precision: p)
        let inverseSquare = inverse.multiplied(by: inverse, precision: p)
        var power = inverse
        for (index, number) in bernoulli.enumerated() {
            let k = index + 1
            let term = BigDecimal(number.0)!.multiplied(by: power, precision: p)
                .divided(by: number.1, precision: p).divided(by: 2 * k * (2 * k - 1), precision: p)
            if term.isZero || term.magnitude10 < sum.magnitude10 - p - 2 { break }
            sum = sum.adding(term, precision: p)
            power = power.multiplied(by: inverseSquare, precision: p)
        }
        return try exponential(sum, precision: p).divided(by: divisor, precision: w)
    }

    // MARK: Parts of a number

    /// Degrees with a decimal fraction to degrees.minutes-seconds: 2.5 becomes 2.30.
    static func toDegreesMinutesSeconds(_ x: BigDecimal) -> BigDecimal {
        let p = precision
        let degrees = x.truncated
        let minutes = x.subtracting(degrees, precision: p).multiplied(by: BigDecimal(60), precision: p)
        let wholeMinutes = snapped(minutes).truncated
        let seconds = minutes.subtracting(wholeMinutes, precision: p).multiplied(by: BigDecimal(60), precision: p)
        return degrees.adding(wholeMinutes.scaled(byPowerOfTen: -2), precision: p).adding(seconds.scaled(byPowerOfTen: -4), precision: p)
    }

    /// The other way: 2.30 becomes 2.5.
    static func fromDegreesMinutesSeconds(_ x: BigDecimal) -> BigDecimal {
        let p = precision
        let degrees = x.truncated
        let rest = x.subtracting(degrees, precision: p).scaled(byPowerOfTen: 2)
        let minutes = rest.truncated
        let seconds = rest.subtracting(minutes, precision: p).scaled(byPowerOfTen: 2)
        return degrees.adding(minutes.divided(by: 60, precision: p), precision: p).adding(seconds.divided(by: 3600, precision: p), precision: p)
    }

    /// A chain like 1 / 3 × 3 ends a hair under the whole number. Before asking for the integer
    /// part, the last digits, which the display never shows, are rounded away.
    static func snapped(_ x: BigDecimal) -> BigDecimal { x.rounded(precision - 6) }
}
