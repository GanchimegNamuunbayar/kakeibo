import Foundation
import SwiftData

enum SeedData {
    static func ensure(in context: ModelContext) {
        var categories = (try? context.fetch(FetchDescriptor<MoneyCategory>())) ?? []
        if categories.isEmpty {
            categories = seedCategories(in: context)
        }
        migrate(categories)
        ensureMissingCategories(in: context, existing: categories)
        categories = (try? context.fetch(FetchDescriptor<MoneyCategory>())) ?? categories
        let plans = (try? context.fetch(FetchDescriptor<FixedCostPlan>())) ?? []
        BudgetDefaults.ensurePlans(categories: categories, plans: plans, in: context)
        ensureEmergencyFund(in: context)
        try? context.save()
    }

    private static func seedCategories(in context: ModelContext) -> [MoneyCategory] {
        BudgetDefaults.allItems.map { item in
            let category = MoneyCategory(
                name: item.name,
                kind: item.kind,
                sortOrder: item.sortOrder,
                symbolName: item.symbolName,
                bucket: item.bucket
            )
            context.insert(category)
            return category
        }
    }

    private static func migrate(_ categories: [MoneyCategory]) {
        migrateLayoutV3(categories)
        migrateLayoutV4(categories)
    }

    private static func migrateLayoutV3(_ categories: [MoneyCategory]) {
        let key = "migratedLayout.v3"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        for category in categories {
            switch category.name {
            case "住居": category.name = "家賃"
            case "通信": category.name = "通信費"
            case "交通費": category.name = "定期券"
            case "ご褒美": category.name = "衣類・美容"
            case "緊急", "生活予備", "光熱", "光熱費", "その他":
                category.isArchived = true
            default:
                break
            }
            category.isEmergency = false
            category.bucket = BudgetBucket.inferred(
                name: category.name,
                kind: category.kind,
                isEmergency: false
            )
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    private static func migrateLayoutV4(_ categories: [MoneyCategory]) {
        let key = "migratedLayout.v4"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        for category in categories where category.name == "サブスク" {
            category.isArchived = true
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    private static func ensureMissingCategories(in context: ModelContext, existing: [MoneyCategory]) {
        let names = Set(existing.filter { !$0.isArchived }.map(\.name))
        for item in BudgetDefaults.allItems where !names.contains(item.name) {
            context.insert(
                MoneyCategory(
                    name: item.name,
                    kind: item.kind,
                    sortOrder: item.sortOrder,
                    symbolName: item.symbolName,
                    bucket: item.bucket
                )
            )
        }
    }

    private static func ensureEmergencyFund(in context: ModelContext) {
        let goals = (try? context.fetch(FetchDescriptor<SavingsGoal>())) ?? []
        if let existing = goals.first(where: { $0.isEmergencyFund || $0.name == "緊急資金" }) {
            existing.isEmergencyFund = true
            existing.deadline = nil
            return
        }
        context.insert(
            SavingsGoal(
                name: "緊急資金",
                targetAmount: 0,
                deadline: nil,
                sortOrder: (goals.map(\.sortOrder).max() ?? -1) + 1,
                isEmergencyFund: true
            )
        )
    }
}

enum KakeiboSchema {
    static var all: Schema {
        Schema([
            MoneyCategory.self,
            Expense.self,
            ExpenseLine.self,
            MerchantMemory.self,
            MonthlyBudget.self,
            IncomeLine.self,
            SaveLine.self,
            Envelope.self,
            EnvelopeTransfer.self,
            FixedCostPlan.self,
            SavingsGoal.self,
            GoalAllocation.self,
            MonthlySavings.self,
            CardCheck.self,
        ])
    }
}
