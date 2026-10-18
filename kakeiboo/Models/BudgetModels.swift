import Foundation
import SwiftData

@Model
final class MonthlyBudget {
    @Attribute(.unique) var periodKey: String
    var totalAmount: Int
    var income: Int = 0
    var spendingTotal: Int = 0
    var savingsAmount: Int = 0
    var hasCustomSavings: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \Envelope.budget)
    var envelopes: [Envelope]
    @Relationship(deleteRule: .cascade, inverse: \IncomeLine.budget)
    var incomeLines: [IncomeLine]
    @Relationship(deleteRule: .cascade, inverse: \SaveLine.budget)
    var saveLines: [SaveLine]

    init(
        periodKey: String,
        totalAmount: Int,
        income: Int = 0,
        spendingTotal: Int = 0,
        savingsAmount: Int = 0,
        hasCustomSavings: Bool = false,
        envelopes: [Envelope] = [],
        incomeLines: [IncomeLine] = [],
        saveLines: [SaveLine] = []
    ) {
        self.periodKey = periodKey
        self.totalAmount = totalAmount
        self.income = income
        self.spendingTotal = spendingTotal
        self.savingsAmount = savingsAmount
        self.hasCustomSavings = hasCustomSavings
        self.envelopes = envelopes
        self.incomeLines = incomeLines
        self.saveLines = saveLines
    }

    var spendingBudget: Int {
        let fromLines = incomeLines.reduce(0) { $0 + $1.amount }
        if fromLines > 0 { return fromLines }
        return income > 0 ? income : totalAmount
    }
}

@Model
final class IncomeLine {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Int
    var sortOrder: Int
    var budget: MonthlyBudget?

    init(id: UUID = UUID(), name: String, amount: Int, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.amount = amount
        self.sortOrder = sortOrder
    }
}

@Model
final class CardCheck {
    @Attribute(.unique) var periodKey: String
    var actualAmount: Int
    var hasActual: Bool

    init(periodKey: String, actualAmount: Int = 0, hasActual: Bool = false) {
        self.periodKey = periodKey
        self.actualAmount = actualAmount
        self.hasActual = hasActual
    }
}

@Model
final class SaveLine {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Int
    var sortOrder: Int
    var budget: MonthlyBudget?

    init(id: UUID = UUID(), name: String, amount: Int, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.amount = amount
        self.sortOrder = sortOrder
    }
}

@Model
final class Envelope {
    @Attribute(.unique) var id: UUID
    var amount: Int
    var budget: MonthlyBudget?
    var category: MoneyCategory?

    init(id: UUID = UUID(), amount: Int, category: MoneyCategory?) {
        self.id = id
        self.amount = amount
        self.category = category
    }
}

@Model
final class EnvelopeTransfer {
    @Attribute(.unique) var id: UUID
    var periodKey: String
    var amount: Int
    var date: Date
    var note: String
    var fromCategory: MoneyCategory?
    var toCategory: MoneyCategory?

    init(
        id: UUID = UUID(),
        periodKey: String,
        amount: Int,
        fromCategory: MoneyCategory?,
        toCategory: MoneyCategory?,
        date: Date = Date(),
        note: String = ""
    ) {
        self.id = id
        self.periodKey = periodKey
        self.amount = amount
        self.fromCategory = fromCategory
        self.toCategory = toCategory
        self.date = date
        self.note = note
    }
}

@Model
final class FixedCostPlan {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Int
    var isPaused: Bool
    var startPeriodKey: String?
    var endPeriodKey: String?
    var category: MoneyCategory?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Int,
        category: MoneyCategory?,
        isPaused: Bool = false,
        startPeriodKey: String? = nil,
        endPeriodKey: String? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
        self.isPaused = isPaused
        self.startPeriodKey = startPeriodKey
        self.endPeriodKey = endPeriodKey
    }

    func isActive(in period: PayPeriod) -> Bool {
        if isPaused { return false }
        if let startPeriodKey, startPeriodKey > period.key { return false }
        if let endPeriodKey, endPeriodKey < period.key { return false }
        return true
    }
}
