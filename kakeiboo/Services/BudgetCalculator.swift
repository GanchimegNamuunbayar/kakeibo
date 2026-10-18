import Foundation

struct FixedCostRow: Identifiable {
    let id: UUID
    let name: String
    let categoryName: String
    let planned: Int
    let actual: Int?
    let effective: Int
    let isUnmatchedActual: Bool
}

struct CategorySpendRow: Identifiable {
    let id: UUID
    let category: MoneyCategory
    let envelope: Int
    let spent: Int
    let transferNet: Int
    let coveredByEmergency: Int
    let remaining: Int

    var allocated: Int { envelope + transferNet }
}

struct BudgetSnapshot {
    let period: PayPeriod
    let hasBudget: Bool
    let totalAmount: Int
    let income: Int
    let spendingTotal: Int
    let plannedFixedTotal: Int
    let effectiveFixedTotal: Int
    let variableSpent: Int
    let livingRemaining: Int
    let fixedRows: [FixedCostRow]
    let categoryRows: [CategorySpendRow]
    let allCategoryRows: [CategorySpendRow]
    let rule: BudgetRule
    let needsBudget: Int
    let wantsBudget: Int
    let savingsTarget: Int
    let needsSpent: Int
    let wantsSpent: Int
    let actualSpending: Int
    let plannedSpending: Int

    var plannedSavings: Int {
        savingsTarget
    }

    func sharePercent(of amount: Int) -> Int {
        guard income > 0 else { return 0 }
        return Int((Double(amount) * 100 / Double(income)).rounded())
    }

    var needsSharePercent: Int { shares.need }
    var wantsSharePercent: Int { shares.want }
    var savingsSharePercent: Int { shares.save }

    private var shares: (need: Int, save: Int, want: Int) {
        BudgetDefaults.sharePercents(need: needsBudget, save: savingsTarget, income: income)
    }

    var lumpNeedRows: [CategorySpendRow] {
        allCategoryRows.filter { $0.category.inputStyle == .lumpSum }
    }

    var flexibleNeedRows: [CategorySpendRow] {
        allCategoryRows.filter { $0.category.inputStyle == .flexible }
    }

    var wantRows: [CategorySpendRow] {
        allCategoryRows.filter { $0.category.inputStyle == .want }
    }

    var otherRows: [CategorySpendRow] {
        allCategoryRows.filter { $0.category.bucket == .other }
    }
}

enum BudgetCalculator {
    static func snapshot(
        period: PayPeriod,
        budgets: [MonthlyBudget],
        categories: [MoneyCategory],
        plans: [FixedCostPlan],
        expenses: [Expense],
        transfers: [EnvelopeTransfer],
        rule: BudgetRule = .standard
    ) -> BudgetSnapshot {
        let budget = budgets.first { $0.periodKey == period.key }
        let income = budget?.spendingBudget ?? 0
        let hasBudget = budget != nil || income > 0

        let periodExpenses = expenses.filter { period.contains($0.date) }
        let includedLines = periodExpenses.flatMap { expense -> [ExpenseLine] in
            expense.excludeFromBudget ? [] : expense.lines
        }
        let periodTransfers = transfers.filter { $0.periodKey == period.key }
        let activePlans = plans.filter { $0.isActive(in: period) }
        let visibleCategories = categories
            .filter { !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }

        func envelopeAmount(for category: MoneyCategory) -> Int {
            if category.inputStyle == .lumpSum {
                let fromPlans = activePlans
                    .filter { $0.category?.id == category.id }
                    .reduce(0) { $0 + $1.amount }
                if fromPlans > 0 { return fromPlans }
                return BudgetDefaults.amount(for: category.name)
            }
            if let stored = budget?.envelopes.first(where: { $0.category?.id == category.id })?.amount {
                return stored
            }
            return BudgetDefaults.amount(for: category.name)
        }

        func transferNet(for category: MoneyCategory) -> Int {
            periodTransfers.reduce(0) { sum, transfer in
                var next = sum
                if transfer.toCategory?.id == category.id { next += transfer.amount }
                if transfer.fromCategory?.id == category.id { next -= transfer.amount }
                return next
            }
        }

        func recordedSpend(for category: MoneyCategory) -> Int {
            includedLines
                .filter { $0.category?.id == category.id }
                .reduce(0) { $0 + $1.amount }
        }

        func spent(for category: MoneyCategory) -> Int {
            if category.inputStyle == .lumpSum {
                return envelopeAmount(for: category)
            }
            return recordedSpend(for: category)
        }

        let allCategoryRows: [CategorySpendRow] = visibleCategories.map { category in
            let allocated = envelopeAmount(for: category) + transferNet(for: category)
            let used = spent(for: category)
            return CategorySpendRow(
                id: category.id,
                category: category,
                envelope: envelopeAmount(for: category),
                spent: used,
                transferNet: transferNet(for: category),
                coveredByEmergency: 0,
                remaining: allocated - used
            )
        }

        let needRows = allCategoryRows.filter { $0.category.bucket == .needs }
        let wantRows = allCategoryRows.filter { $0.category.bucket == .wants }
        let needsBudget = needRows.reduce(0) { $0 + $1.allocated }
        let needsSpent = needRows.reduce(0) { $0 + $1.spent }
        let wantsSpent = wantRows.reduce(0) { $0 + $1.spent }
        let savingsFromLines = budget?.saveLines.reduce(0) { $0 + $1.amount } ?? 0
        let savingsTarget = BudgetDefaults.resolvedSave(
            income: income,
            needBudget: needsBudget,
            storedAmount: savingsFromLines > 0 ? savingsFromLines : (budget?.savingsAmount ?? 0),
            isCustom: (budget?.hasCustomSavings ?? false) || savingsFromLines > 0
        )
        let wantsBudget = BudgetDefaults.wantBudget(income: income, needBudget: needsBudget, save: savingsTarget)
        let plannedSpending = needsBudget + wantsBudget
        let variableSpent = allCategoryRows
            .filter { $0.category.bucket != .other && $0.category.inputStyle != .lumpSum }
            .reduce(0) { $0 + $1.spent }

        let fixedRows: [FixedCostRow] = needRows.filter { $0.category.inputStyle == .lumpSum }.map { row in
            FixedCostRow(
                id: row.id,
                name: row.category.name,
                categoryName: row.category.name,
                planned: row.allocated,
                actual: row.spent,
                effective: row.spent,
                isUnmatchedActual: false
            )
        }

        return BudgetSnapshot(
            period: period,
            hasBudget: hasBudget,
            totalAmount: income,
            income: income,
            spendingTotal: plannedSpending,
            plannedFixedTotal: needsBudget - needRows.filter { $0.category.inputStyle == .flexible }.reduce(0) { $0 + $1.allocated },
            effectiveFixedTotal: needRows.filter { $0.category.inputStyle == .lumpSum }.reduce(0) { $0 + $1.spent },
            variableSpent: variableSpent,
            livingRemaining: (needsBudget - needsSpent) + (wantsBudget - wantsSpent),
            fixedRows: fixedRows,
            categoryRows: allCategoryRows.filter { $0.category.bucket != .other && $0.category.inputStyle != .lumpSum },
            allCategoryRows: allCategoryRows,
            rule: rule,
            needsBudget: needsBudget,
            wantsBudget: wantsBudget,
            savingsTarget: savingsTarget,
            needsSpent: needsSpent,
            wantsSpent: wantsSpent,
            actualSpending: needsSpent + wantsSpent,
            plannedSpending: plannedSpending
        )
    }
}
