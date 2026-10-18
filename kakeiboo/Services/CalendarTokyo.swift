import Foundation

extension Calendar {
    static var tokyo: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }
}

enum Yen {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.groupingSeparator = ","
        return formatter
    }()

    static func format(_ value: Int) -> String {
        let digits = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(digits)円"
    }

    static func formatSigned(_ value: Int) -> String {
        if value > 0 { return "+\(format(value))" }
        if value < 0 { return "-\(format(-value))" }
        return format(0)
    }

    static func parse(_ text: String) -> Int {
        Int(text.filter(\.isNumber)) ?? 0
    }

    static func digits(_ amount: Int) -> String {
        amount == 0 ? "" : String(amount)
    }

    /// 入力欄用。末尾から3桁ごとにカンマを入れる。空や 0 は "0"。
    static func groupedDigits(_ text: String) -> String {
        let raw = text.filter(\.isNumber)
        guard let value = Int(raw), value > 0 else { return "0" }
        return formatter.string(from: NSNumber(value: value)) ?? raw
    }
}
