import SwiftUI
import SwiftData

struct RootTabView: View {
    @State private var session = Session()
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]
    @Query private var budgets: [MonthlyBudget]
    @Query(sort: \FixedCostPlan.name) private var plans: [FixedCostPlan]
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query(sort: \EnvelopeTransfer.date, order: .reverse) private var transfers: [EnvelopeTransfer]
    @Query(sort: \SavingsGoal.sortOrder) private var goals: [SavingsGoal]

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(snapshot: snapshot, goals: goals)
            }
            .tabItem { Label("ホーム", systemImage: "house.fill") }

            NavigationStack {
                TransactionListView(snapshot: snapshot)
            }
            .tabItem { Label("支出", systemImage: "yensign.circle.fill") }

            NavigationStack {
                GoalsView()
            }
            .tabItem { Label("ゴール", systemImage: "flag.fill") }

            NavigationStack {
                YearlyView()
            }
            .tabItem { Label("年間", systemImage: "calendar") }
        }
        .tint(Palette.accent)
        .hoverEffectDisabled(true)
        .toolbarBackground(Palette.canvas, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .environment(session)
        .environment(\.timeZone, TimeZone(identifier: "Asia/Tokyo") ?? .gmt)
        .environment(\.locale, Locale(identifier: "ja_JP"))
    }

    private var snapshot: BudgetSnapshot {
        let period = session.period
        return BudgetCalculator.snapshot(
            period: period,
            budgets: budgets,
            categories: categories,
            plans: plans,
            expenses: expenses,
            transfers: transfers,
            rule: session.rule
        )
    }
}
