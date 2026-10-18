import Foundation
import SwiftData

enum BudgetDefaults {
    struct Item {
        var name: String
        var kind: CategoryKind
        var sortOrder: Int
        var symbolName: String
        var bucket: BudgetBucket
        var amount: Int
    }

    static let needItems: [Item] = [
        Item(name: "家賃", kind: .fixed, sortOrder: 0, symbolName: "house.fill", bucket: .needs, amount: 42_350),
        Item(name: "健康保険", kind: .fixed, sortOrder: 1, symbolName: "heart.fill", bucket: .needs, amount: 2_300),
        Item(name: "水道", kind: .fixed, sortOrder: 2, symbolName: "drop.fill", bucket: .needs, amount: 3_000),
        Item(name: "定期券", kind: .fixed, sortOrder: 3, symbolName: "tram.fill", bucket: .needs, amount: 6_990),
        Item(name: "電気", kind: .variable, sortOrder: 10, symbolName: "bolt.fill", bucket: .needs, amount: 4_500),
        Item(name: "ガス", kind: .variable, sortOrder: 11, symbolName: "flame.fill", bucket: .needs, amount: 1_500),
        Item(name: "通信費", kind: .variable, sortOrder: 12, symbolName: "wifi", bucket: .needs, amount: 3_300),
        Item(name: "食費", kind: .variable, sortOrder: 13, symbolName: "fork.knife", bucket: .needs, amount: 17_000),
        Item(name: "日用品", kind: .variable, sortOrder: 14, symbolName: "cart.fill", bucket: .needs, amount: 4_000),
        Item(name: "Cursor Pro", kind: .fixed, sortOrder: 15, symbolName: "laptopcomputer", bucket: .needs, amount: 3_187),
    ]

    static let wantItems: [Item] = [
        Item(name: "Spotify", kind: .variable, sortOrder: 20, symbolName: "music.note", bucket: .wants, amount: 580),
        Item(name: "Audible", kind: .variable, sortOrder: 21, symbolName: "headphones", bucket: .wants, amount: 1_500),
        Item(name: "趣味", kind: .variable, sortOrder: 22, symbolName: "gamecontroller.fill", bucket: .wants, amount: 0),
        Item(name: "衣類・美容", kind: .variable, sortOrder: 23, symbolName: "tshirt.fill", bucket: .wants, amount: 0),
        Item(name: "遊び", kind: .variable, sortOrder: 24, symbolName: "figure.walk", bucket: .wants, amount: 0),
        Item(name: "ギフト", kind: .variable, sortOrder: 25, symbolName: "gift.fill", bucket: .wants, amount: 0),
    ]

    static var allItems: [Item] { needItems + wantItems }

    static let defaultSavePercent = 30

    static func amount(for name: String) -> Int {
        (needItems + wantItems).first { $0.name == name }?.amount ?? 0
    }

    static func defaultSave(income: Int) -> Int {
        max(0, income * defaultSavePercent / 100)
    }

    static func resolvedSave(income: Int, needBudget: Int, storedAmount: Int, isCustom: Bool) -> Int {
        let raw = isCustom ? storedAmount : defaultSave(income: income)
        return min(max(0, raw), max(0, income - needBudget))
    }

    static func sharePercents(need: Int, save: Int, income: Int) -> (need: Int, save: Int, want: Int) {
        guard income > 0 else { return (0, 0, 0) }
        let needPercent = Int((Double(need) * 100 / Double(income)).rounded(.towardZero))
        let savePercent = Int((Double(save) * 100 / Double(income)).rounded(.towardZero))
        return (needPercent, savePercent, max(0, 100 - needPercent - savePercent))
    }

    static func wantBudget(income: Int, needBudget: Int, save: Int) -> Int {
        max(0, income - needBudget - save)
    }

    static func applyIncome(
        _ income: Int,
        period: PayPeriod,
        budgets: [MonthlyBudget],
        categories: [MoneyCategory],
        plans: [FixedCostPlan],
        savingsRecords: [MonthlySavings],
        in context: ModelContext
    ) {
        let budget = budgets.first { $0.periodKey == period.key } ?? MonthlyBudget(periodKey: period.key, totalAmount: 0)
        if budgets.first(where: { $0.periodKey == period.key }) == nil {
            context.insert(budget)
        }
        budget.income = income
        budget.totalAmount = income
        updateIncomeTotal(income, on: budget, in: context)
        ensurePlans(categories: categories, plans: plans, in: context)
        if budget.envelopes.isEmpty {
            seedEnvelopes(
                on: budget,
                previous: budgets.first { $0.periodKey == period.previous.key },
                categories: categories,
                in: context
            )
        }

        let needBudget = needTotal(categories: categories, plans: plans, envelopes: budget.envelopes)
        let save = resolvedSave(
            income: income,
            needBudget: needBudget,
            storedAmount: budget.saveLines.reduce(0) { $0 + $1.amount } > 0
                ? budget.saveLines.reduce(0) { $0 + $1.amount }
                : budget.savingsAmount,
            isCustom: budget.hasCustomSavings || !budget.saveLines.isEmpty
        )
        budget.savingsAmount = save
        updateSaveTotal(save, on: budget)
        let want = wantBudget(income: income, needBudget: needBudget, save: save)
        budget.spendingTotal = needBudget + want

        if let existing = savingsRecords.first(where: { $0.periodKey == period.key }) {
            existing.plannedAmount = save
        } else {
            context.insert(MonthlySavings(periodKey: period.key, plannedAmount: save))
        }
        try? context.save()
    }

    static func applySave(
        _ amount: Int,
        period: PayPeriod,
        budgets: [MonthlyBudget],
        categories: [MoneyCategory],
        plans: [FixedCostPlan],
        savingsRecords: [MonthlySavings],
        in context: ModelContext
    ) {
        let budget = budgets.first { $0.periodKey == period.key } ?? MonthlyBudget(periodKey: period.key, totalAmount: 0)
        if budgets.first(where: { $0.periodKey == period.key }) == nil {
            context.insert(budget)
        }
        let needBudget = needTotal(categories: categories, plans: plans, envelopes: budget.envelopes)
        let save = resolvedSave(
            income: budget.spendingBudget,
            needBudget: needBudget,
            storedAmount: amount,
            isCustom: true
        )
        budget.hasCustomSavings = true
        budget.savingsAmount = save
        updateSaveTotal(save, on: budget)
        budget.spendingTotal = needBudget + wantBudget(income: budget.spendingBudget, needBudget: needBudget, save: save)
        if let existing = savingsRecords.first(where: { $0.periodKey == period.key }) {
            existing.plannedAmount = save
        } else {
            context.insert(MonthlySavings(periodKey: period.key, plannedAmount: save))
        }
        try? context.save()
    }

    static func ensurePlans(categories: [MoneyCategory], plans: [FixedCostPlan], in context: ModelContext) {
        for item in needItems where item.kind == .fixed {
            let category = categories.first { $0.name == item.name && !$0.isArchived }
            let exists = plans.contains { $0.category?.id == category?.id && !$0.isPaused }
            if !exists, let category {
                context.insert(FixedCostPlan(name: item.name, amount: item.amount, category: category))
            }
        }
    }

    private static func updateIncomeTotal(_ income: Int, on budget: MonthlyBudget, in _: ModelContext) {
        let lines = budget.incomeLines.sorted { $0.sortOrder < $1.sortOrder }
        if lines.isEmpty {
            guard income > 0 else { return }
            let line = IncomeLine(name: "収入", amount: income)
            line.budget = budget
            budget.incomeLines.append(line)
            return
        }
        if lines.count == 1 {
            lines[0].amount = income
            return
        }
        let rest = lines.dropFirst().reduce(0) { $0 + $1.amount }
        lines[0].amount = max(0, income - rest)
    }

    private static func updateSaveTotal(_ save: Int, on budget: MonthlyBudget) {
        let lines = budget.saveLines.sorted { $0.sortOrder < $1.sortOrder }
        if lines.isEmpty {
            guard save > 0 else { return }
            let line = SaveLine(name: "Save", amount: save)
            line.budget = budget
            budget.saveLines.append(line)
            return
        }
        if lines.count == 1 {
            lines[0].amount = save
            return
        }
        let rest = lines.dropFirst().reduce(0) { $0 + $1.amount }
        lines[0].amount = max(0, save - rest)
    }

    private static func seedEnvelopes(
        on budget: MonthlyBudget,
        previous: MonthlyBudget?,
        categories: [MoneyCategory],
        in _: ModelContext
    ) {
        let targets = categories.filter { !$0.isArchived && $0.inputStyle != .lumpSum }
        for category in targets {
            let amount = previous?.envelopes.first { $0.category?.id == category.id }?.amount
                ?? amount(for: category.name)
            let envelope = Envelope(amount: amount, category: category)
            envelope.budget = budget
            budget.envelopes.append(envelope)
        }
    }

    private static func needTotal(categories: [MoneyCategory], plans: [FixedCostPlan], envelopes: [Envelope]) -> Int {
        let lumps = categories.filter { !$0.isArchived && $0.inputStyle == .lumpSum }
        let lumpTotal = lumps.reduce(0) { sum, category in
            sum + plans.filter { $0.category?.id == category.id && !$0.isPaused }.reduce(0) { $0 + $1.amount }
        }
        let flexibleTotal = envelopes
            .filter { $0.category?.inputStyle == .flexible }
            .reduce(0) { $0 + $1.amount }
        return lumpTotal + flexibleTotal
    }
}
