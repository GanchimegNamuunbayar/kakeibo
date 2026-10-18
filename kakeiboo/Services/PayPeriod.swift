import Foundation

struct PayPeriod: Hashable, Identifiable {
    static let payday = 20

    let start: Date

    var id: String { key }

    var key: String {
        Self.keyDateFormatter.string(from: start)
    }

    var nextStart: Date {
        Calendar.tokyo.date(byAdding: .month, value: 1, to: start) ?? start
    }

    var endInclusive: Date {
        Calendar.tokyo.date(byAdding: .day, value: -1, to: nextStart) ?? start
    }

    var previous: PayPeriod {
        PayPeriod(start: Calendar.tokyo.date(byAdding: .month, value: -1, to: start) ?? start)
    }

    var next: PayPeriod {
        PayPeriod(start: nextStart)
    }

    func contains(_ date: Date) -> Bool {
        date >= start && date < nextStart
    }

    var daysRemaining: Int {
        let calendar = Calendar.tokyo
        let today = calendar.startOfDay(for: Date())
        let last = calendar.startOfDay(for: endInclusive)
        let remaining = calendar.dateComponents([.day], from: today, to: last).day ?? 0
        return max(0, remaining + 1)
    }

    var totalDays: Int {
        let calendar = Calendar.tokyo
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: endInclusive)
        return (calendar.dateComponents([.day], from: first, to: last).day ?? 0) + 1
    }

    var hasEnded: Bool {
        Date() >= nextStart
    }

    var title: String {
        "\(Self.displayFormatter.string(from: start))〜\(Self.displayFormatter.string(from: endInclusive))"
    }

    var shortTitle: String {
        "\(Self.monthFormatter.string(from: start))の給料月"
    }

    static func containing(_ date: Date = Date()) -> PayPeriod {
        let calendar = Calendar.tokyo
        let day = calendar.component(.day, from: date)
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = payday
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.nanosecond = 0
        let thisPayday = calendar.date(from: components) ?? date
        if day >= payday {
            return PayPeriod(start: thisPayday)
        }
        let previousPayday = calendar.date(byAdding: .month, value: -1, to: thisPayday) ?? thisPayday
        return PayPeriod(start: previousPayday)
    }

    static func inCalendarYear(_ year: Int) -> [PayPeriod] {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = payday
        components.hour = 0
        components.minute = 0
        components.second = 0
        let calendar = Calendar.tokyo
        guard let january = calendar.date(from: components) else { return [] }
        var period = PayPeriod(start: january)
        var result: [PayPeriod] = []
        while calendar.component(.year, from: period.start) == year {
            result.append(period)
            period = period.next
        }
        return result
    }

    static func fromKey(_ key: String) -> PayPeriod? {
        guard let start = keyDateFormatter.date(from: key) else { return nil }
        return PayPeriod(start: start)
    }

    private static let keyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.tokyo
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.tokyo
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.tokyo
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()
}
