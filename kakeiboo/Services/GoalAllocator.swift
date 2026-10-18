import Foundation

struct GoalPlan: Identifiable, Equatable {
    var id: UUID
    var name: String
    var remaining: Int
    var deadline: Date?
    var monthlyAmount: Int
    var isSurplusBucket: Bool
}

struct AllocationProposal: Equatable {
    struct Item: Identifiable, Equatable {
        var id: UUID
        var name: String
        var monthlyNeed: Int
        var proposed: Int
        var monthsLeft: Int?
        var isSurplusBucket: Bool
    }

    var periodKey: String
    var actual: Int
    var items: [Item]
    var isShort: Bool

    var proposedTotal: Int {
        items.reduce(0) { $0 + $1.proposed }
    }
}

enum GoalAllocator {
    static func monthsLeft(from period: PayPeriod, deadline: Date) -> Int {
        let deadlineDay = Calendar.tokyo.startOfDay(for: deadline)
        var cursor = period
        var count = 0
        while count < 240 {
            count += 1
            if deadlineDay < cursor.nextStart {
                return max(1, count)
            }
            cursor = cursor.next
        }
        return count
    }

    static func monthlyNeed(for plan: GoalPlan, period: PayPeriod) -> Int {
        let remaining = max(0, plan.remaining)
        if remaining == 0 { return 0 }
        if plan.monthlyAmount > 0 {
            return min(plan.monthlyAmount, remaining)
        }
        guard let deadline = plan.deadline, !plan.isSurplusBucket else { return 0 }
        let months = monthsLeft(from: period, deadline: deadline)
        return (remaining + months - 1) / months
    }

    static func propose(actual: Int, plans: [GoalPlan], period: PayPeriod) -> AllocationProposal {
        let pot = max(0, actual)
        let prepared: [AllocationProposal.Item] = plans.map { plan in
            AllocationProposal.Item(
                id: plan.id,
                name: plan.name,
                monthlyNeed: monthlyNeed(for: plan, period: period),
                proposed: 0,
                monthsLeft: plan.deadline.map { monthsLeft(from: period, deadline: $0) },
                isSurplusBucket: plan.isSurplusBucket || (plan.deadline == nil && plan.monthlyAmount == 0)
            )
        }

        let needed = prepared.filter { !$0.isSurplusBucket && $0.monthlyNeed > 0 }
        let needSum = needed.reduce(0) { $0 + $1.monthlyNeed }
        var assigned: [UUID: Int] = [:]
        var isShort = false

        if pot >= needSum {
            for item in needed {
                assigned[item.id] = item.monthlyNeed
            }
            var leftover = pot - needSum
            let surplus = prepared.filter(\.isSurplusBucket)
            if let first = surplus.first {
                assigned[first.id] = leftover
                leftover = 0
            }
        } else if needSum > 0 {
            isShort = true
            assigned = proportional(actual: pot, items: needed)
        }

        let items = prepared.map { item in
            var next = item
            next.proposed = assigned[item.id] ?? 0
            return next
        }

        return AllocationProposal(
            periodKey: period.key,
            actual: pot,
            items: items,
            isShort: isShort
        )
    }

    private static func proportional(actual: Int, items: [AllocationProposal.Item]) -> [UUID: Int] {
        let needSum = items.reduce(0) { $0 + $1.monthlyNeed }
        guard needSum > 0 else { return [:] }
        var floors = items.map { item in
            (id: item.id, value: actual * item.monthlyNeed / needSum, fraction: Double(actual * item.monthlyNeed % needSum) / Double(needSum))
        }
        var leftover = actual - floors.reduce(0) { $0 + $1.value }
        let order = floors.enumerated().sorted { lhs, rhs in
            if lhs.element.fraction == rhs.element.fraction {
                return lhs.offset < rhs.offset
            }
            return lhs.element.fraction > rhs.element.fraction
        }
        var index = 0
        while leftover > 0, !order.isEmpty {
            floors[order[index % order.count].offset].value += 1
            leftover -= 1
            index += 1
        }
        return Dictionary(uniqueKeysWithValues: floors.map { ($0.id, $0.value) })
    }
}
