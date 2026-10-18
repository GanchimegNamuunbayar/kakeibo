import Foundation
import SwiftData

enum CategoryKind: String, Codable, CaseIterable, Identifiable {
    case fixed
    case variable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixed: "定額"
        case .variable: "都度"
        }
    }
}

@Model
final class MoneyCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var sortOrder: Int
    var isEmergency: Bool
    var symbolName: String
    var isArchived: Bool
    var bucketRaw: String = BudgetBucket.needs.rawValue

    init(
        id: UUID = UUID(),
        name: String,
        kind: CategoryKind,
        sortOrder: Int,
        isEmergency: Bool = false,
        symbolName: String,
        isArchived: Bool = false,
        bucket: BudgetBucket? = nil
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.sortOrder = sortOrder
        self.isEmergency = isEmergency
        self.symbolName = symbolName
        self.isArchived = isArchived
        self.bucketRaw = (bucket ?? BudgetBucket.inferred(name: name, kind: kind, isEmergency: isEmergency)).rawValue
    }

    var kind: CategoryKind {
        get { CategoryKind(rawValue: kindRaw) ?? .variable }
        set { kindRaw = newValue.rawValue }
    }

    var bucket: BudgetBucket {
        get { BudgetBucket(rawValue: bucketRaw) ?? BudgetBucket.inferred(name: name, kind: kind, isEmergency: isEmergency) }
        set { bucketRaw = newValue.rawValue }
    }

    var inputStyle: CategoryInputStyle {
        if bucket == .other { return .other }
        if bucket == .wants { return .want }
        if kind == .fixed { return .lumpSum }
        return .flexible
    }

    /// 明細を＋で積み上げるカテゴリか。false なら行タップで月1件の金額を入れる。
    var tracksPurchases: Bool {
        if bucket == .other { return true }
        switch name {
        case "食費", "日用品", "趣味", "衣類・美容", "遊び", "ギフト", "ご褒美", "その他":
            return true
        case "家賃", "健康保険", "水道", "定期券", "電気", "ガス", "通信費",
             "Cursor Pro", "Spotify", "Audible", "サブスク":
            return false
        default:
            return bucket == .wants
        }
    }
}
