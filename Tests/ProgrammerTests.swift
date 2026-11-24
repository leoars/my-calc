import Foundation

/// The programmer mode: whole numbers of a word size, in four bases.
func runProgrammerTests() {
    func programmer(_ script: String, radix: Radix = .dec, word: WordSize = .qword, show: Radix? = nil) -> String {
        let calculator = Calculator(mode: .programmer)
        calculator.setWordSize(word)
        calculator.setRadix(radix)
        calculator.run(script)
        if let show { calculator.setRadix(show) }
        return calculator.shown
    }
    expect(programmer("FF", radix: .hex, show: .dec) + " " + programmer("255", show: .hex) + " " + programmer("255", show: .oct) + " " + programmer("255", show: .bin),
           "255 FF 377 11111111", "one number in the four bases")
    expect(programmer("1010", radix: .bin, show: .dec) + " " + programmer("777", radix: .oct, show: .dec) + " " + programmer("7FFFFFFFFFFFFFFF", radix: .hex, show: .dec),
           "10 511 9223372036854775807", "and typed in each of them")
    expect(programmer("19A", radix: .oct) + " " + programmer("123", radix: .bin) + " " + programmer("1A", radix: .dec), "1 1 1",
           "a digit that the base does not have is not typed")
    expect(programmer("1 neg", show: .hex) + " " + programmer("1 neg", word: .dword, show: .hex) + " " + programmer("1 neg", word: .word, show: .hex)
           + " " + programmer("1 neg", word: .byte, show: .bin), "FFFFFFFFFFFFFFFF FFFFFFFF FFFF 11111111", "negative numbers are two's complement of the word")
    expect(programmer("FF", radix: .hex, word: .byte, show: .dec) + " " + programmer("FFFF", radix: .hex, word: .word, show: .dec) + " "
           + programmer("80000000", radix: .hex, word: .dword, show: .dec), "-1 -1 -2147483648", "the top bit is the sign")
    expect(programmer("999", word: .byte) + " " + programmer("12345678901234567890") + " " + programmer("FFF", radix: .hex, word: .byte),
           "99 1234567890123456789 FF", "no more is typed than the word holds")
    expect(programmer("127 + 1 =", word: .byte) + " " + programmer("9223372036854775807 + 1 =") + " " + programmer("100 * 3 =", word: .byte),
           "-128 -9223372036854775808 44", "arithmetic wraps around in the word")
    expect(programmer("7 / 2 =") + " " + programmer("7 neg / 2 =") + " " + programmer("7 mod 3 =") + " " + programmer("7 neg mod 3 ="),
           "3 -3 1 -1", "division drops the fraction, towards zero")
    expect(programmer("5 / 0 =") + programmer("0 / 0 =") + programmer("5 mod 0 ="), "[divideByZero][undefined][undefined]", "division by zero")
    expect(programmer("12 and 10 =") + " " + programmer("12 or 3 =") + " " + programmer("12 xor 10 =") + " " + programmer("0 not") + " "
           + programmer("F0", radix: .hex, word: .byte, show: nil).isEmpty.description, "8 15 6 -1 false", "And, Or, Xor and Not")
    expect(programmer("12 nand 10 =") + " " + programmer("12 nor 3 =") + " " + programmer("F0 nand FF", radix: .hex, word: .byte).isEmpty.description
           + " " + programmer("F0 nor F =", radix: .hex, word: .byte), "-9 -16 false 0", "Nand and Nor")
    expect(programmer("F0 not", radix: .hex, word: .byte), "F", "Not within the word")
    expect(programmer("1 lsh 4 =") + " " + programmer("256 rsh 4 =") + " " + programmer("16 neg rsh 2 =") + " " + programmer("1 lsh 7 =", word: .byte)
           + " " + programmer("1 lsh 8 =", word: .byte) + " " + programmer("1 lsh 64 ="), "16 16 -4 -128 0 0", "the shifts; to the right the sign is kept")
    expect(programmer("81 rol", radix: .hex, word: .byte) + " " + programmer("81 ror", radix: .hex, word: .byte) + " " + programmer("1 ror", show: .hex),
           "3 C0 8000000000000000", "the rotations go around the word")
    expect(programmer("1 + 2 * 3 =") + " " + programmer("( 1 + 2 ) * 3 =") + " " + programmer("6 or 1 and 3 =") + " " + programmer("1 lsh 2 + 1 ="),
           "7 9 7 5", "precedence and parentheses, as in the scientific mode")
    expect(programmer("2 . 5") + " " + programmer("9 sqrt") + " " + programmer("50 %") + " " + programmer("4 1/x"), "25 9 50 4",
           "the point, the root, the percent and the reciprocal do nothing here")

    let calculator = Calculator(mode: .programmer)
    calculator.run("5")
    check(calculator.bits == 5, "the bits of the number being typed")
    calculator.toggleBit(1)
    expect(calculator.shown, "7", "a click on a bit turns it on")
    calculator.toggleBit(0)
    calculator.toggleBit(63)
    expect(calculator.shown, "-9223372036854775802", "the top bit makes the number negative")
    calculator.setWordSize(.byte)
    expect(calculator.shown + " " + String(calculator.bits), "6 6", "a smaller word keeps the low bits")
    calculator.toggleBit(8)
    expect(calculator.shown, "6", "a bit beyond the word is not there")
    calculator.toggleBit(7)
    expect(calculator.shown, "-122", "the top bit of the byte")
    calculator.setRadix(.hex)
    calculator.setWordSize(.qword)
    expect(calculator.shown, "FFFFFFFFFFFFFF86", "a larger word extends the sign")
    calculator.run("MS C MR")
    expect(calculator.shown, "FFFFFFFFFFFFFF86", "the memory works here too")
    check(calculator.accepts(digit: 15) && !Calculator(mode: .programmer).accepts(digit: 10) && !Calculator().accepts(digit: 10),
          "A to F are digits only in hexadecimal")
    calculator.setMode(.standard)
    expect(calculator.shown, "-122", "leaving the mode keeps the number")
    check(calculator.history.isEmpty, "the programmer mode keeps no history")
    let grouped = Calculator(mode: .programmer, format: NumberFormat(grouping: true))
    grouped.setRadix(.hex)
    grouped.run("12345678")
    expect(grouped.shown + "|" + grouped.copyText, "1234 5678|12345678", "hexadecimal digits group in fours")
}
