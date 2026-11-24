import Foundation

/// How numbers reach the display: the separators of the region, grouping, 32 digits.
func runFormatTests() {
    func d(_ text: String) -> BigDecimal { BigDecimal(text)! }
    let plain = NumberFormat()
    expect(plain.string(d("1234567.891")), "1234567.891", "without grouping the digits run together")
    let american = NumberFormat(locale: Locale(identifier: "en_US"), grouping: true)
    expect(american.string(d("1234567.891")), "1,234,567.891", "en_US: comma for thousands, point for decimals")
    expect(american.string(d("-1234")) + " " + american.string(d("999")) + " " + american.string(d("0.0001234")), "-1,234 999 0.0001234",
           "the sign and the fraction stay out of the groups")
    let brazilian = NumberFormat(locale: Locale(identifier: "pt_BR"), grouping: true)
    expect(brazilian.string(d("1234567.891")), "1.234.567,891", "pt_BR: point for thousands, comma for decimals")
    let german = NumberFormat(locale: Locale(identifier: "de_DE"), grouping: true)
    expect(german.string(d("0.5")) + " " + german.string(d("1000000")), "0,5 1.000.000", "de_DE follows its region too")
    let french = NumberFormat(locale: Locale(identifier: "fr_FR"), grouping: true)
    check(french.decimalSeparator == "," && french.string(d("1234.5")).hasSuffix("234,5") && french.string(d("1234.5")).count == 7,
          "fr_FR: a space of its own between the thousands")
    let japanese = NumberFormat(locale: Locale(identifier: "ja_JP"), grouping: true)
    expect(japanese.string(d("1234.5")), "1,234.5", "ja_JP writes as en_US")
    check(NumberFormat(locale: Locale(identifier: "pt_BR"), grouping: false).string(d("1234.5")) == "1234,5", "the decimal sign does not depend on grouping")

    expect(plain.string(.zero) + " " + plain.string(d("-0.5")) + " " + plain.string(d("100")), "0 -0.5 100", "small cases")
    expect(plain.string(d("1").divided(by: d("3"), precision: 50)), "0.33333333333333333333333333333333", "32 digits of a third")
    expect(plain.string(d("2").divided(by: d("3"), precision: 50)), "0.66666666666666666666666666666667", "the 32nd digit is rounded")
    expect(plain.string(d("0.99999999999999999999999999999999999999")), "1", "what rounds to a whole number shows as one")
    expect(plain.string(d("12345678901234567890123456789012")), "12345678901234567890123456789012", "32 digits fit")
    expect(plain.string(d("123456789012345678901234567890123")), "1.2345678901234567890123456789012e+32", "33 digits go to the exponent form")
    expect(plain.string(d("1e-7")) + " " + plain.string(d("1e-40")), "0.0000001 1.e-40", "small numbers stay plain while they fit")
    expect(plain.string(d("1").divided(by: d("3000"), precision: 50)), "3.3333333333333333333333333333333e-4", "and take the exponent when they do not")
    expect(plain.string(d("1500"), scientific: true) + " " + plain.string(d("0.00025"), scientific: true), "1.5e+3 2.5e-4", "F-E shows the exponent form")
    expect(brazilian.string(d("1500"), scientific: true), "1,5e+3", "with the decimal sign of the region")

    var entry = Entry()
    entry.digits = "1234"
    entry.fraction = "500"
    expect(american.string(entry) + " " + brazilian.string(entry), "1,234.500 1.234,500", "a number being typed keeps its zeros")
    entry.fraction = ""
    expect(american.string(entry), "1,234.", "and the point just typed")
    entry.exponent = "12"
    entry.exponentIsNegative = true
    expect(plain.string(entry), "1234.e-12", "the exponent being typed")
    check(entry.value == d("1234e-12"), "what was typed is the number")

    expect(american.string(255, radix: .hex, wordSize: .qword) + " " + american.string(255, radix: .bin, wordSize: .qword) + " "
           + american.string(255, radix: .oct, wordSize: .qword) + " " + american.string(-1234567, radix: .dec, wordSize: .qword),
           "FF 1111 1111 377 -1,234,567", "the bases of the programmer mode")
    expect(american.string(-1, radix: .hex, wordSize: .word) + " " + american.string(-1, radix: .hex, wordSize: .qword) + " "
           + american.string(-1, radix: .bin, wordSize: .byte) + " " + plain.string(-2, radix: .oct, wordSize: .byte),
           "FFFF FFFF FFFF FFFF FFFF 1111 1111 376", "negative numbers show the bits of the word")
}
