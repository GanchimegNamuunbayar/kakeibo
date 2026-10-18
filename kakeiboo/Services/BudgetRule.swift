import Foundation

struct BudgetRule: Equatable, Codable, Hashable {
    var needsPercent: Int
    var wantsPercent: Int

    static let standard = BudgetRule(needsPercent: 50, wantsPercent: 30)

    var savingsPercent: Int { max(0, 100 - needsPercent - wantsPercent) }
    var spendingPercent: Int { needsPercent + wantsPercent }

    func amount(percent: Int, of income: Int) -> Int {
        guard income > 0 else { return 0 }
        return income * percent / 100
    }

    var needsLabel: String { "Need \(needsPercent)" }
    var wantsLabel: String { "Want \(wantsPercent)" }
    var savingsLabel: String { "Save \(savingsPercent)" }

    func adjusting(needs: Int? = nil, wants: Int? = nil) -> BudgetRule {
        let nextNeeds = min(90, max(10, needs ?? needsPercent))
        var nextWants = min(80, max(5, wants ?? wantsPercent))
        if nextNeeds + nextWants > 95 {
            nextWants = max(5, 95 - nextNeeds)
        }
        return BudgetRule(needsPercent: nextNeeds, wantsPercent: nextWants)
    }

    static func load() -> BudgetRule {
        guard
            let data = UserDefaults.standard.data(forKey: Self.storageKey),
            let rule = try? JSONDecoder().decode(BudgetRule.self, from: data)
        else {
            return .standard
        }
        return rule.adjusting()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private static let storageKey = "budgetRule"
}

enum BudgetBucket: String, Codable, CaseIterable, Identifiable {
    case needs
    case wants
    case savings
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .needs: "Need"
        case .wants: "Want"
        case .savings: "Save"
        case .other: "その他"
        }
    }

    static func inferred(name: String, kind: CategoryKind, isEmergency: Bool) -> BudgetBucket {
        if isEmergency { return .needs }
        switch name {
        case "住居", "家賃", "光熱", "光熱費", "水道", "電気", "ガス", "通信", "通信費", "交通費", "定期券", "健康保険", "食費", "日用品", "Cursor Pro", "生活予備", "緊急":
            return .needs
        case "遊び", "ご褒美", "衣類・美容", "趣味", "ギフト", "サブスク", "Spotify", "Audible", "その他":
            return .wants
        default:
            return kind == .fixed ? .needs : .wants
        }
    }
}

enum CategoryInputStyle {
    case lumpSum
    case flexible
    case want
    case other
}

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case card
    case cash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .card: "カード"
        case .cash: "現金"
        }
    }
}

enum IncomeSource {
    static let all = ["奨学金", "Emoba", "大学", "学会 reimbursement"]
    static let yearlyCheck = ["Emoba", "大学"]
}
