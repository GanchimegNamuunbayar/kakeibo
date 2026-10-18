import Foundation
import SwiftData

@Model
final class Expense {
    @Attribute(.unique) var id: UUID
    var date: Date
    var merchant: String
    var note: String
    var excludeFromBudget: Bool
    var paymentRaw: String = PaymentMethod.card.rawValue
    @Relationship(deleteRule: .cascade, inverse: \ExpenseLine.expense)
    var lines: [ExpenseLine]

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        merchant: String = "",
        note: String = "",
        excludeFromBudget: Bool = false,
        payment: PaymentMethod = .card,
        lines: [ExpenseLine] = []
    ) {
        self.id = id
        self.date = date
        self.merchant = merchant
        self.note = note
        self.excludeFromBudget = excludeFromBudget
        self.paymentRaw = payment.rawValue
        self.lines = lines
    }

    var payment: PaymentMethod {
        get { PaymentMethod(rawValue: paymentRaw) ?? .card }
        set { paymentRaw = newValue.rawValue }
    }

    var totalAmount: Int {
        lines.reduce(0) { $0 + $1.amount }
    }

    var primaryCategory: MoneyCategory? {
        lines.sorted { $0.amount > $1.amount }.first?.category
    }
}

@Model
final class ExpenseLine {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Int
    var expense: Expense?
    var category: MoneyCategory?
    var settlesPlan: FixedCostPlan?

    init(
        id: UUID = UUID(),
        name: String = "",
        amount: Int,
        category: MoneyCategory? = nil,
        settlesPlan: FixedCostPlan? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
        self.settlesPlan = settlesPlan
    }
}

@Model
final class MerchantMemory {
    @Attribute(.unique) var merchantKey: String
    var merchant: String
    var category: MoneyCategory?
    var updatedAt: Date

    init(merchant: String, category: MoneyCategory?) {
        self.merchantKey = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        self.merchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        self.category = category
        self.updatedAt = Date()
    }
}
