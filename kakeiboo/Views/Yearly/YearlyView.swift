import SwiftUI
import SwiftData

struct YearlyView: View {
    @Query private var budgets: [MonthlyBudget]
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var year = Calendar.tokyo.component(.year, from: Date())

    private static let largeThreshold = 20_000

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                yearHeader
                incomeCard
                largeCard
                managementCard
            }
            .padding()
        }
        .navigationTitle("年間")
        .background(Palette.canvas)
        .tint(Palette.accent)
    }

    private var yearHeader: some View {
        HStack {
            Button {
                year -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Palette.secondary)
            }
            Text("\(year)年")
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
            Button {
                year += 1
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Palette.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var incomeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Emoba・大学")
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text("1月からの合計 \(Yen.format(checkTotal))")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.accent)
            HStack {
                Text("Emoba")
                Spacer()
                Text(Yen.format(yearTotal("Emoba")))
            }
            HStack {
                Text("大学")
                Spacer()
                Text(Yen.format(yearTotal("大学")))
            }
            ForEach(periods) { period in
                HStack {
                    Text(period.shortTitle)
                        .foregroundStyle(Palette.secondary)
                    Spacer()
                    Text("\(Yen.format(amount("Emoba", in: period))) / \(Yen.format(amount("大学", in: period)))")
                        .foregroundStyle(Palette.ink)
                }
                .font(.caption)
            }
            Divider()
            HStack {
                Text("奨学金")
                Spacer()
                Text(Yen.format(yearTotal("奨学金")))
            }
            HStack {
                Text("学会 reimbursement")
                Spacer()
                Text(Yen.format(yearTotal("学会 reimbursement")))
            }
        }
        .font(.subheadline)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var largeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("大きな支出")
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text("2万円以上")
                .font(.caption)
                .foregroundStyle(Palette.secondary)
            if largeExpenses.isEmpty {
                Text("なし")
                    .foregroundStyle(Palette.secondary)
            } else {
                ForEach(largeExpenses) { expense in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(expense.merchant.isEmpty ? (expense.primaryCategory?.name ?? "支払") : expense.merchant)
                            Text("\(expense.date.formatted(.dateTime.month().day().locale(Locale(identifier: "ja_JP"))))  \(expense.payment.title)")
                                .font(.caption)
                                .foregroundStyle(Palette.secondary)
                        }
                        Spacer()
                        Text(Yen.format(expense.totalAmount))
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var managementCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink {
                FixedCostListView()
            } label: {
                Label("定額", systemImage: "building.columns.fill")
            }
            NavigationLink {
                CategoryListView()
            } label: {
                Label("カテゴリ", systemImage: "square.grid.2x2.fill")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var periods: [PayPeriod] {
        PayPeriod.inCalendarYear(year)
    }

    private var checkTotal: Int {
        IncomeSource.yearlyCheck.reduce(0) { $0 + yearTotal($1) }
    }

    private func yearTotal(_ name: String) -> Int {
        periods.reduce(0) { $0 + amount(name, in: $1) }
    }

    private func amount(_ name: String, in period: PayPeriod) -> Int {
        budgets.first { $0.periodKey == period.key }?.incomeLines.first { $0.name == name }?.amount ?? 0
    }

    private var largeExpenses: [Expense] {
        expenses
            .filter {
                Calendar.tokyo.component(.year, from: $0.date) == year && $0.totalAmount >= Self.largeThreshold
            }
            .sorted { $0.totalAmount > $1.totalAmount }
    }
}
