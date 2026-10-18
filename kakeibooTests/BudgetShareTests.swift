import XCTest
import SwiftData
@testable import kakeiboo

final class BudgetShareTests: XCTestCase {
    func testSharePercentsAlwaysSumToOneHundred() {
        let shares = BudgetDefaults.sharePercents(need: 33_333, save: 33_333, income: 100_000)
        XCTAssertEqual(shares.need, 33)
        XCTAssertEqual(shares.save, 33)
        XCTAssertEqual(shares.want, 34)
        XCTAssertEqual(shares.need + shares.save + shares.want, 100)
    }

    func testSharePercentsUseRemainderForWant() {
        let shares = BudgetDefaults.sharePercents(need: 42_350, save: 75_000, income: 250_000)
        XCTAssertEqual(shares.need + shares.save + shares.want, 100)
        XCTAssertEqual(shares.want, 100 - shares.need - shares.save)
    }

    func testDefaultNeedIncludesCursorPro() {
        XCTAssertEqual(BudgetDefaults.amount(for: "Cursor Pro"), 3_187)
    }

    func testDefaultWantIncludesSubscriptions() {
        XCTAssertEqual(BudgetDefaults.amount(for: "Spotify"), 580)
        XCTAssertEqual(BudgetDefaults.amount(for: "Audible"), 1_500)
    }
}

@MainActor
final class BudgetIncomePersistenceTests: XCTestCase {
    func testApplyIncomeKeepsCustomIncomeNamesAndNeedAmounts() throws {
        let container = try ModelContainer(
            for: KakeiboSchema.all,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        SeedData.ensure(in: context)

        let period = PayPeriod.containing()
        let categories = (try context.fetch(FetchDescriptor<MoneyCategory>())).filter { !$0.isArchived }
        let food = try XCTUnwrap(categories.first { $0.name == "食費" })

        let budget = MonthlyBudget(periodKey: period.key, totalAmount: 200_000, income: 200_000)
        context.insert(budget)
        let salary = IncomeLine(name: "給与", amount: 180_000, sortOrder: 0)
        salary.budget = budget
        budget.incomeLines.append(salary)
        let side = IncomeLine(name: "副業", amount: 20_000, sortOrder: 1)
        side.budget = budget
        budget.incomeLines.append(side)
        let foodEnvelope = Envelope(amount: 9_999, category: food)
        foodEnvelope.budget = budget
        budget.envelopes.append(foodEnvelope)
        try context.save()

        BudgetDefaults.applyIncome(
            210_000,
            period: period,
            budgets: [budget],
            categories: categories,
            plans: (try context.fetch(FetchDescriptor<FixedCostPlan>())),
            savingsRecords: [],
            in: context
        )

        let names = budget.incomeLines.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
        XCTAssertEqual(names, ["給与", "副業"])
        XCTAssertEqual(budget.incomeLines.first { $0.name == "副業" }?.amount, 20_000)
        XCTAssertEqual(
            budget.envelopes.first { $0.category?.id == food.id }?.amount,
            9_999
        )
    }
}
