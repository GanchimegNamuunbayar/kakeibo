import SwiftUI
import SwiftData

struct ExpenseEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]
    @Query(sort: \FixedCostPlan.name) private var plans: [FixedCostPlan]
    @Query(sort: \MerchantMemory.updatedAt, order: .reverse) private var memories: [MerchantMemory]

    let expense: Expense?
    var lockedCategoryID: UUID? = nil
    var initialDate: Date? = nil

    @State private var date = Date()
    @State private var merchant = ""
    @State private var note = ""
    @State private var excludeFromBudget = false
    @State private var payment: PaymentMethod = .card
    @State private var lines: [DraftLine] = [DraftLine()]
    @State private var focusedLine: UUID?
    @State private var amountText = ""
    @FocusState private var textFocus: UUID?

    private var period: PayPeriod { PayPeriod.containing(date) }
    private var locksCategory: Bool { lockedCategoryID != nil }

    var body: some View {
        Form {
            Section("基本") {
                DatePicker("日付", selection: $date, displayedComponents: .date)
                TextField("店名・サービス名", text: $merchant)
                    .focused($textFocus, equals: merchantField)
                if !merchantSuggestions.isEmpty && !merchant.isEmpty {
                    ForEach(merchantSuggestions, id: \.self) { name in
                        Button(name) {
                            applyMerchant(name)
                        }
                    }
                }
                TextField("メモ", text: $note)
                    .focused($textFocus, equals: noteField)
                Picker("支払い", selection: $payment) {
                    ForEach(PaymentMethod.allCases) { method in
                        Text(method.title).tag(method)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("予算外", isOn: $excludeFromBudget)
            }

            Section("品目") {
                ForEach($lines) { $line in
                    lineEditor($line)
                }
                .onDelete { offsets in
                    let removed = offsets.map { lines[$0].id }
                    lines.remove(atOffsets: offsets)
                    if let focusedLine, removed.contains(focusedLine) {
                        self.focusedLine = nil
                    }
                    if lines.isEmpty {
                        lines = [DraftLine(categoryID: lockedCategoryID)]
                    }
                }
                Button("品目を追加") {
                    var extra = DraftLine()
                    extra.categoryID = lockedCategoryID ?? lines.last?.categoryID
                    lines.append(extra)
                }
                LabeledContent("合計", value: Yen.format(draftTotal))
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let focusedLine {
                YenKeypadBar(
                    title: "金額",
                    text: amountBinding(for: focusedLine),
                    onDone: { self.focusedLine = nil }
                )
            }
        }
        .onChange(of: textFocus) { _, newValue in
            if newValue != nil { focusedLine = nil }
        }
        .navigationTitle(expense == nil ? "支出を追加" : "支出を編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(draftTotal <= 0 || lines.contains(where: { $0.amount < 0 }))
            }
        }
        .onAppear(perform: load)
    }

    @ViewBuilder
    private func lineEditor(_ line: Binding<DraftLine>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("品名", text: line.name)
                .focused($textFocus, equals: line.wrappedValue.id)
            Button {
                beginAmount(line.wrappedValue)
            } label: {
                HStack {
                    Text("金額")
                    Spacer()
                    Text(Yen.format(line.wrappedValue.amount))
                        .foregroundStyle(focusedLine == line.wrappedValue.id ? Palette.accent : Palette.ink)
                }
            }
            .buttonStyle(.plain)
            .yenFocusBackground(focusedLine == line.wrappedValue.id)
            if !locksCategory {
                Picker("カテゴリ", selection: line.categoryID) {
                    Text("未分類").tag(Optional<UUID>.none)
                    ForEach(categories.filter { !$0.isArchived && $0.inputStyle != .lumpSum }) { category in
                        Text("\(category.bucket.title) / \(category.name)").tag(Optional(category.id))
                    }
                }
            }
            if let category = categories.first(where: { $0.id == line.wrappedValue.categoryID }), category.kind == .fixed {
                Picker("充当", selection: line.planID) {
                    Text("なし").tag(Optional<UUID>.none)
                    ForEach(plans.filter { $0.category?.id == category.id && $0.isActive(in: period) }) { plan in
                        Text("\(plan.name) \(Yen.format(plan.amount))").tag(Optional(plan.id))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var merchantField: UUID { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! }
    private var noteField: UUID { UUID(uuidString: "00000000-0000-0000-0000-000000000002")! }

    private func beginAmount(_ line: DraftLine) {
        if focusedLine == line.id {
            focusedLine = nil
            return
        }
        textFocus = nil
        Keyboard.dismiss()
        amountText = Yen.digits(line.amount)
        focusedLine = line.id
    }

    private func amountBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { amountText },
            set: { newValue in
                amountText = newValue
                if let index = lines.firstIndex(where: { $0.id == id }) {
                    lines[index].amount = Yen.parse(newValue)
                }
            }
        )
    }

    private var draftTotal: Int {
        lines.reduce(0) { $0 + $1.amount }
    }

    private var merchantSuggestions: [String] {
        let key = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return [] }
        return memories
            .map(\.merchant)
            .filter { $0.localizedCaseInsensitiveContains(key) && $0 != merchant }
            .uniqued()
            .prefix(5)
            .map { $0 }
    }

    private func applyMerchant(_ name: String) {
        merchant = name
        guard !locksCategory else { return }
        if let memory = memories.first(where: { $0.merchant == name }), let category = memory.category {
            lines[0].categoryID = category.id
        }
    }

    private func load() {
        if let expense {
            date = expense.date
            merchant = expense.merchant
            note = expense.note
            excludeFromBudget = expense.excludeFromBudget
            payment = expense.payment
            let drafts = expense.lines.map { line in
                DraftLine(
                    id: line.id,
                    name: line.name,
                    amount: line.amount,
                    categoryID: line.category?.id,
                    planID: line.settlesPlan?.id
                )
            }
            lines = drafts.isEmpty ? [DraftLine(categoryID: lockedCategoryID)] : drafts
            return
        }

        if let initialDate {
            date = initialDate
        }
        lines = [DraftLine(categoryID: lockedCategoryID)]
    }

    private func save() {
        let target = expense ?? Expense()
        if expense == nil {
            modelContext.insert(target)
        }
        target.date = date
        target.merchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        target.note = note
        target.excludeFromBudget = excludeFromBudget
        target.payment = payment

        for line in target.lines {
            modelContext.delete(line)
        }
        target.lines = []

        for draft in lines where draft.amount > 0 {
            let categoryID = lockedCategoryID ?? draft.categoryID
            let category = categories.first { $0.id == categoryID }
            let plan = plans.first { $0.id == draft.planID } ?? matchingPlan(for: category)
            let line = ExpenseLine(
                name: draft.name,
                amount: draft.amount,
                category: category,
                settlesPlan: plan
            )
            line.expense = target
            target.lines.append(line)
        }

        if !target.merchant.isEmpty, let category = target.primaryCategory {
            if let memory = memories.first(where: { $0.merchantKey == target.merchant }) {
                memory.category = category
                memory.updatedAt = Date()
            } else {
                modelContext.insert(MerchantMemory(merchant: target.merchant, category: category))
            }
        }

        try? modelContext.save()
        dismiss()
    }

    private func matchingPlan(for category: MoneyCategory?) -> FixedCostPlan? {
        guard let category, category.kind == .fixed else { return nil }
        let matches = plans.filter { $0.category?.id == category.id && $0.isActive(in: period) }
        return matches.count == 1 ? matches[0] : nil
    }
}

struct DraftLine: Identifiable {
    var id = UUID()
    var name = ""
    var amount = 0
    var categoryID: UUID?
    var planID: UUID?
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
