import SwiftUI
import SwiftData

enum GoalPace {
    static func caption(for goal: SavingsGoal, period: PayPeriod) -> String? {
        if let deadline = goal.deadline {
            let remaining = goal.remainingAmount
            if remaining == 0 { return "達成" }
            let months = GoalAllocator.monthsLeft(from: period, deadline: deadline)
            let monthly = GoalAllocator.monthlyNeed(
                for: GoalPlan(
                    id: goal.id,
                    name: goal.name,
                    remaining: remaining,
                    deadline: deadline,
                    monthlyAmount: goal.monthlyAmount,
                    isSurplusBucket: false
                ),
                period: period
            )
            return "残 \(Yen.format(remaining)) ÷ \(months)ヶ月 = 毎月 \(Yen.format(monthly))"
        }
        if goal.monthlyAmount > 0 {
            return "毎月 \(Yen.format(goal.monthlyAmount))"
        }
        return nil
    }
}

struct GoalsView: View {
    @Environment(Session.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavingsGoal.sortOrder) private var goals: [SavingsGoal]
    @Query private var savingsRecords: [MonthlySavings]
    @State private var isAdding = false
    @State private var openingGoal: SavingsGoal?
    @State private var actualText = ""
    @State private var editingActual = false
    @State private var drafts: [UUID: String] = [:]
    @State private var yenFocus: UUID?

    var body: some View {
        List {
            Section {
                if goals.isEmpty {
                    Text("未登録")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(goals) { goal in
                        Button {
                            openingGoal = goal
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                GoalProgressRow(goal: goal)
                                HStack {
                                    if let deadline = goal.deadline {
                                        Text(deadline.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))
                                    }
                                    Spacer(minLength: 0)
                                }
                                .font(.caption)
                                .foregroundStyle(Palette.secondary)
                                if let pace = GoalPace.caption(for: goal, period: session.period) {
                                    Text(pace)
                                        .font(.caption)
                                        .foregroundStyle(Palette.secondary)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(goals[index])
                        }
                        try? modelContext.save()
                    }
                }
            } header: {
                Text("貯金のゴール")
            }

            Section {
                HStack {
                    Text("予想")
                    Spacer()
                    Text(Yen.format(currentSavings?.plannedAmount ?? 0))
                        .foregroundStyle(Palette.accent)
                }
                HStack {
                    Text("実績")
                    Spacer()
                    if let current = currentSavings, current.hasActual {
                        Text(Yen.format(current.actualAmount))
                    } else {
                        Text("未登録")
                            .foregroundStyle(.secondary)
                    }
                }
                Button(currentSavings?.hasActual == true ? "実績を直す" : "実績を入れる") {
                    actualText = Yen.digits(currentSavings?.actualAmount ?? 0)
                    editingActual = true
                    yenFocus = nil
                }
                HStack {
                    Text("これまでの実績")
                    Spacer()
                    Text(Yen.format(accumulatedActual))
                        .fontWeight(.semibold)
                }
                ForEach(pastRecords) { record in
                    HStack {
                        Text(PayPeriod.fromKey(record.periodKey)?.shortTitle ?? record.periodKey)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("予想 \(Yen.format(record.plannedAmount))")
                            if record.hasActual {
                                Text("実績 \(Yen.format(record.actualAmount))")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("今月の貯金")
            }

            if let current = currentSavings, current.hasActual, !proposal.items.isEmpty {
                Section {
                    ForEach(proposal.items) { item in
                        Button {
                            yenFocus = yenFocus == item.id ? nil : item.id
                            editingActual = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                    if let months = item.monthsLeft {
                                        Text("残り\(months)ヶ月 必要 \(Yen.format(item.monthlyNeed))")
                                            .font(.caption)
                                            .foregroundStyle(Palette.secondary)
                                    } else if item.isSurplusBucket {
                                        Text("余り")
                                            .font(.caption)
                                            .foregroundStyle(Palette.secondary)
                                    }
                                }
                                Spacer()
                                Text(Yen.format(Yen.parse(drafts[item.id] ?? Yen.digits(item.proposed))))
                                    .foregroundStyle(yenFocus == item.id ? Palette.accent : Palette.ink)
                            }
                            .yenFocusBackground(yenFocus == item.id)
                        }
                        .foregroundStyle(.primary)
                    }
                    if proposal.isShort {
                        Text("足りないので必要額の比率")
                            .font(.caption)
                            .foregroundStyle(Palette.secondary)
                    }
                    Button(alreadyAllocated ? "入れ直す" : "提案どおり入れる") {
                        confirmProposal()
                    }
                } header: {
                    Text("今月の分配")
                }
            }
        }
        .navigationTitle("ゴール")
        .scrollContentBackground(.hidden)
        .background {
            Palette.canvas
                .ignoresSafeArea()
                .onTapGesture {
                    editingActual = false
                    yenFocus = nil
                }
        }
        .tint(Palette.accent)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAdding = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            NavigationStack { GoalEditorView(goal: nil) }
        }
        .sheet(item: $openingGoal) { goal in
            NavigationStack {
                GoalDetailView(goal: goal)
            }
        }
        .toolbar(editingActual || yenFocus != nil ? .hidden : .automatic, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if editingActual {
                YenKeypadBar(
                    title: "今月の実績",
                    text: $actualText,
                    onSave: saveActual,
                    onDone: { editingActual = false }
                )
            } else if yenFocus != nil {
                YenKeypadBar(
                    title: goals.first { $0.id == yenFocus }?.name ?? "分配",
                    text: focusedText,
                    onSave: { yenFocus = nil },
                    onDone: { yenFocus = nil }
                )
            }
        }
        .onChange(of: proposal) { _, newValue in
            seedDrafts(from: newValue)
        }
        .onAppear {
            seedDrafts(from: proposal)
        }
    }

    private var currentSavings: MonthlySavings? {
        savingsRecords.first { $0.periodKey == session.period.key }
    }

    private var pastRecords: [MonthlySavings] {
        savingsRecords
            .filter { $0.periodKey != session.period.key }
            .sorted { $0.periodKey > $1.periodKey }
    }

    private var accumulatedActual: Int {
        savingsRecords.filter(\.hasActual).reduce(0) { $0 + $1.actualAmount }
    }

    private var proposal: AllocationProposal {
        GoalAllocator.propose(
            actual: currentSavings?.hasActual == true ? (currentSavings?.actualAmount ?? 0) : 0,
            plans: goals.map { goal in
                GoalPlan(
                    id: goal.id,
                    name: goal.name,
                    remaining: goal.targetAmount > 0 ? goal.remainingAmount : 0,
                    deadline: goal.deadline,
                    monthlyAmount: goal.monthlyAmount,
                    isSurplusBucket: goal.deadline == nil && goal.monthlyAmount == 0
                )
            },
            period: session.period
        )
    }

    private var alreadyAllocated: Bool {
        goals.contains { goal in
            goal.allocations.contains { $0.periodKey == session.period.key }
        }
    }

    private func seedDrafts(from proposal: AllocationProposal) {
        var next: [UUID: String] = [:]
        for item in proposal.items {
            next[item.id] = drafts[item.id] ?? Yen.digits(item.proposed)
        }
        drafts = next
    }

    private var focusedText: Binding<String> {
        Binding(
            get: {
                if editingActual { return actualText }
                if let focus = yenFocus {
                    return drafts[focus] ?? ""
                }
                return ""
            },
            set: { newValue in
                if editingActual {
                    actualText = newValue
                } else if let focus = yenFocus {
                    drafts[focus] = newValue
                }
            }
        )
    }

    private func saveActual() {
        let amount = Yen.parse(actualText)
        if let existing = currentSavings {
            existing.actualAmount = amount
            existing.hasActual = true
        } else {
            modelContext.insert(
                MonthlySavings(
                    periodKey: session.period.key,
                    plannedAmount: 0,
                    actualAmount: amount,
                    hasActual: true
                )
            )
        }
        try? modelContext.save()
        editingActual = false
        drafts = [:]
    }

    private func confirmProposal() {
        for goal in goals {
            for allocation in goal.allocations where allocation.periodKey == session.period.key {
                modelContext.delete(allocation)
            }
        }
        for item in proposal.items {
            let amount = Yen.parse(drafts[item.id] ?? Yen.digits(item.proposed))
            guard amount > 0, let goal = goals.first(where: { $0.id == item.id }) else { continue }
            let allocation = GoalAllocation(
                amount: amount,
                note: session.period.shortTitle,
                periodKey: session.period.key
            )
            allocation.goal = goal
            goal.allocations.append(allocation)
        }
        try? modelContext.save()
        yenFocus = nil
    }
}

struct GoalEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var goals: [SavingsGoal]
    let goal: SavingsGoal?

    @State private var name: String
    @State private var targetAmount: Int
    @State private var deadline: Date
    @State private var hasDeadline: Bool
    @State private var monthlyAmount: Int

    init(goal: SavingsGoal?) {
        self.goal = goal
        _name = State(initialValue: goal?.name ?? "")
        _targetAmount = State(initialValue: goal?.targetAmount ?? 0)
        _deadline = State(initialValue: goal?.deadline ?? Date())
        _hasDeadline = State(initialValue: goal?.deadline != nil)
        _monthlyAmount = State(initialValue: goal?.monthlyAmount ?? 0)
    }

    var body: some View {
        Form {
            TextField("目的", text: $name)
            YenField(title: "金額", amount: $targetAmount)
            Toggle("期限", isOn: $hasDeadline)
            if hasDeadline {
                DatePicker("期限", selection: $deadline, displayedComponents: .date)
            }
            YenField(title: "毎月", amount: $monthlyAmount)
        }
        .navigationTitle(goal == nil ? "貯金ゴール" : "ゴールを編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let goal {
            goal.name = trimmed
            goal.targetAmount = targetAmount
            goal.deadline = hasDeadline ? deadline : nil
            goal.monthlyAmount = monthlyAmount
        } else {
            let created = SavingsGoal(
                name: trimmed,
                targetAmount: targetAmount,
                deadline: hasDeadline ? deadline : nil,
                sortOrder: (goals.map(\.sortOrder).max() ?? -1) + 1,
                monthlyAmount: monthlyAmount
            )
            modelContext.insert(created)
        }
        try? modelContext.save()
        dismiss()
    }
}

struct GoalDetailView: View {
    @Environment(Session.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var goal: SavingsGoal
    @State private var amount = 0
    @State private var note = ""
    @State private var isEditing = false

    var body: some View {
        Form {
            Section("進捗") {
                GoalProgressRow(goal: goal)
                if let deadline = goal.deadline {
                    LabeledContent("期限", value: deadline.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))
                }
                if let pace = GoalPace.caption(for: goal, period: session.period) {
                    Text(pace)
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondary)
                }
            }
            Section("振り分け") {
                YenField(title: "金額", amount: $amount)
                TextField("メモ", text: $note)
                Button("足す") {
                    add(amount)
                }
                .disabled(amount <= 0)
                Button("取り崩す") {
                    add(-amount)
                }
                .disabled(amount <= 0 || amount > goal.currentAmount)
            }
            Section("履歴") {
                if goal.allocations.isEmpty {
                    Text("なし")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(goal.allocations.sorted { $0.date > $1.date }) { allocation in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(Yen.formatSigned(allocation.amount))
                                if !allocation.note.isEmpty {
                                    Text(allocation.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(allocation.date, format: Date.FormatStyle(date: .numeric, time: .omitted).locale(Locale(identifier: "ja_JP")))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        let items = goal.allocations.sorted { $0.date > $1.date }
                        for index in offsets {
                            modelContext.delete(items[index])
                        }
                        try? modelContext.save()
                    }
                }
            }
        }
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("編集") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack { GoalEditorView(goal: goal) }
        }
    }

    private func add(_ value: Int) {
        let allocation = GoalAllocation(amount: value, note: note)
        allocation.goal = goal
        goal.allocations.append(allocation)
        note = ""
        amount = 0
        try? modelContext.save()
    }
}
