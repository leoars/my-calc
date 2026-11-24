import AppKit

// Line by line, so a crash still shows the checks before it.
setvbuf(stdout, nil, _IOLBF, 0)

// Settings go to a suite of their own, removed at the end, never to the app's.
let settingsSuite = "mycalc-tests-\(UUID().uuidString)"
AppSettings.defaults = UserDefaults(suiteName: settingsSuite)!
_ = NSApplication.shared

runBigDecimalTests()
runMathTests()
runFormatTests()
runCalculatorTests()
runProgrammerTests()
runKeyboardTests()
runWindowTests()
runLocalizationTests()
runUpdateTests()

AppSettings.defaults.removePersistentDomain(forName: settingsSuite)

print(failures == 0 ? "All tests passed." : "\(failures) test(s) failed.")
exit(failures == 0 ? 0 : 1)
