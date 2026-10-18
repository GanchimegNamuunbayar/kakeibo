import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(Session.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Query private var savingsRecords: [MonthlySavings]
    @Query private var budgets: [MonthlyBudget]
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]
    @Query(sort: \FixedCostPlan.name) private var plans: [FixedCostPlan]
    let snapshot: BudgetSnapshot
    let goals: [SavingsGoal]
    @State private var editingIncome = false
    @State private var editingSave = false
    @State private var amountText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PeriodHeader(period: Bindable(session).period)

                card {
                    Button {
                        if editingIncome {
                            editingIncome = false
                        } else {
                            amountText = Yen.digits(snapshot.income)
                            editingSave = false
                            editingIncome = true
                        }
                    } label: {
                        gridRow("収入", Yen.format(snapshot.income))
                    }
                    .buttonStyle(.plain)
                    .yenFocusBackground(editingIncome)
                    .accessibilityLabel("収入")
                    .accessibilityValue(Yen.format(snapshot.income))

                    bucketRow("Need", spent: snapshot.needsSpent, budget: snapshot.needsBudget, percent: snapshot.needsSharePercent)
                    Button {
                        if editingSave {
                            editingSave = false
                        } else {
                            amountText = Yen.digits(snapshot.savingsTarget)
                            editingIncome = false
                            editingSave = true
                        }
                    } label: {
                        bucketRow("Save", spent: displayedSavings, budget: snapshot.savingsTarget, percent: snapshot.savingsSharePercent)
                    }
                    .buttonStyle(.plain)
                    .yenFocusBackground(editingSave)
                    .accessibilityLabel("Save")
                    .accessibilityValue("\(Yen.format(displayedSavings)) / \(Yen.format(snapshot.savingsTarget))")
                    bucketRow("Want", spent: snapshot.wantsSpent, budget: snapshot.wantsBudget, percent: snapshot.wantsSharePercent)
                }

                if !goals.isEmpty {
                    card {
                        Text("ゴール")
                            .font(.headline)
                            .foregroundStyle(Palette.ink)
                        ForEach(Array(goals.prefix(3))) { goal in
                            GoalProgressRow(goal: goal)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("家計簿")
        .background {
            Palette.canvas
                .ignoresSafeArea()
                .onTapGesture {
                    editingIncome = false
                    editingSave = false
                }
        }
        .tint(Palette.accent)
        .hoverEffectDisabled(true)
        .toolbar(editingIncome || editingSave ? .hidden : .automatic, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    BudgetEditorView()
                } label: {
                    Image(systemName: "pencil.circle")
                }
                .hoverEffectDisabled(true)
                .accessibilityLabel("予算を編集")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if editingIncome || editingSave {
                YenKeypadBar(
                    title: editingSave ? "Save" : "収入",
                    text: $amountText,
                    onSave: { editingSave ? saveSavings() : saveIncome() },
                    onDone: {
                        editingIncome = false
                        editingSave = false
                    }
                )
            }
        }
    }

    private var displayedSavings: Int {
        if let current = savingsRecords.first(where: { $0.periodKey == session.period.key }), current.hasActual {
            return current.actualAmount
        }
        return snapshot.plannedSavings
    }

    private func saveIncome() {
        BudgetDefaults.applyIncome(
            Yen.parse(amountText),
            period: session.period,
            budgets: budgets,
            categories: categories,
            plans: plans,
            savingsRecords: savingsRecords,
            in: modelContext
        )
        editingIncome = false
    }

    private func saveSavings() {
        BudgetDefaults.applySave(
            Yen.parse(amountText),
            period: session.period,
            budgets: budgets,
            categories: categories,
            plans: plans,
            savingsRecords: savingsRecords,
            in: modelContext
        )
        editingSave = false
    }

    private func bucketRow(_ title: String, spent: Int, budget: Int, percent: Int) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Palette.secondary)
            Text("\(percent)%")
                .foregroundStyle(Palette.secondary)
            Spacer()
            Text("\(Yen.format(spent)) / \(Yen.format(budget))")
                .foregroundStyle(Palette.ink)
        }
        .font(.subheadline)
    }

    private func card(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Palette.card)
                .onTapGesture {
                    editingIncome = false
                    editingSave = false
                }
        }
        .hoverEffectDisabled(true)
    }

    private func gridRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Palette.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(Palette.ink)
        }
        .font(.subheadline)
    }
}

struct GoalProgressRow: View {
    let goal: SavingsGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(goal.name)
                Spacer()
                if goal.targetAmount > 0 {
                    Text("\(Yen.format(goal.currentAmount)) / \(Yen.format(goal.targetAmount))")
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondary)
                } else {
                    Text(Yen.format(goal.currentAmount))
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondary)
                }
            }
            if goal.targetAmount > 0 {
                ProgressView(value: goal.progress)
                    .tint(Palette.accent)
            }
        }
        .padding(.vertical, 2)
        .hoverEffectDisabled(true)
    }
}
