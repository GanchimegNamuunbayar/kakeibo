import Foundation
import SwiftData

@Model
final class SavingsGoal {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetAmount: Int
    var deadline: Date?
    var sortOrder: Int
    var monthlyAmount: Int = 0
    var isEmergencyFund: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \GoalAllocation.goal)
    var allocations: [GoalAllocation]

    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Int,
        deadline: Date? = nil,
        sortOrder: Int = 0,
        allocations: [GoalAllocation] = [],
        monthlyAmount: Int = 0,
        isEmergencyFund: Bool = false
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.deadline = deadline
        self.sortOrder = sortOrder
        self.allocations = allocations
        self.monthlyAmount = monthlyAmount
        self.isEmergencyFund = isEmergencyFund
    }

    var currentAmount: Int {
        allocations.reduce(0) { $0 + $1.amount }
    }

    var remainingAmount: Int {
        max(0, targetAmount - currentAmount)
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(1, Double(currentAmount) / Double(targetAmount))
    }
}

@Model
final class MonthlySavings {
    @Attribute(.unique) var periodKey: String
    var plannedAmount: Int
    var actualAmount: Int
    var hasActual: Bool

    init(periodKey: String, plannedAmount: Int, actualAmount: Int = 0, hasActual: Bool = false) {
        self.periodKey = periodKey
        self.plannedAmount = plannedAmount
        self.actualAmount = actualAmount
        self.hasActual = hasActual
    }
}

@Model
final class GoalAllocation {
    @Attribute(.unique) var id: UUID
    var amount: Int
    var date: Date
    var note: String
    var periodKey: String = ""
    var goal: SavingsGoal?

    init(id: UUID = UUID(), amount: Int, date: Date = Date(), note: String = "", periodKey: String = "") {
        self.id = id
        self.amount = amount
        self.date = date
        self.note = note
        self.periodKey = periodKey
    }
}
