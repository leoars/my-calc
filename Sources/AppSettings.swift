import Foundation

/// What the app keeps between launches. The tests point `defaults` at a suite of their own.
enum AppSettings {
    static var defaults = UserDefaults.standard

    static let modeKey = "Mode"
    static let digitGroupingKey = "DigitGrouping"
    static let historyKey = "ShowHistory"
    static let angleUnitKey = "AngleUnit"
    static let windowOriginKey = "WindowTopLeft"

    static func bool(_ key: String, default value: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? value : defaults.bool(forKey: key)
    }
}
