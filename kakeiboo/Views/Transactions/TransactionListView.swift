import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(Session.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]
    @Query private var cardChecks: [CardCheck]
    let snapshot: BudgetSnapshot
    @State private var addingBucket: BudgetBucket?
    @State private var addingCategory: CategoryAddRequest?
    @State private var editing: Expense?
    @State private var expanded: Set<UUID> = []
    @State private var quickMode: QuickMode?
    @State private var quickAmountText = ""
    @State private var quickPayment: PaymentMethod = .card

    private enum QuickMode: Equatable {
        case replace(UUID)
        case cardActual
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PeriodHeader(period: Bindable(session).period)
                needCard
                wantCard
                otherCard
                cardCheckCard
            }
            .padding()
        }
        .navigationTitle("支出")
        .background {
            Palette.canvas
                .ignoresSafeArea()
                .onTapGesture { quickMode = nil }
        }
        .tint(Palette.accent)
        .toolbar(quickMode == nil ? .automatic : .hidden, for: .tabBar)
        .sheet(item: $addingBucket) { bucket in
            NavigationStack {
                NewCategoryEditor(bucket: bucket) { name in
                    createCategory(name: name, bucket: bucket)
                }
            }
        }
        .sheet(item: $addingCategory) { request in
            NavigationStack {
                ExpenseEditorView(
                    expense: nil,
                    lockedCategoryID: request.category.id,
                    initialDate: defaultExpenseDate
                )
            }
        }
        .sheet(item: $editing) { expense in
            NavigationStack { ExpenseEditorView(expense: expense) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if quickMode != nil {
                VStack(spacing: 8) {
                    if focusedCategory != nil {
                        Picker("支払い", selection: $quickPayment) {
                            ForEach(PaymentMethod.allCases) { method in
                                Text(method.title).tag(method)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 12)
                    }
                    if case .cardActual = quickMode {
                        YenKeypadBar(
                            title: "カードの実績",
                            text: $quickAmountText,
                            showsClear: true,
                            onSave: saveCardActual,
                            onDone: { quickMode = nil }
                        )
                    } else if let category = focusedCategory {
                        YenKeypadBar(
                            title: category.name,
                            text: $quickAmountText,
                            showsClear: true,
                            onSave: { saveQuick(category) },
                            onDone: { quickMode = nil }
                        )
                    }
                }
            }
        }
    }

    private var focusedCategory: MoneyCategory? {
        guard case .replace(let id) = quickMode else { return nil }
        return snapshot.allCategoryRows.first { $0.category.id == id }?.category
    }

    private var needCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Need", spent: snapshot.needsSpent, budget: snapshot.needsBudget)
            AllocationBar(used: snapshot.needsSpent, total: max(snapshot.needsBudget, 1))
            ForEach(needRows) { row in
                categoryRow(row)
            }
            Button("カテゴリを追加") { addingBucket = .needs }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Palette.card)
                .onTapGesture { quickMode = nil }
        }
        .hoverEffectDisabled(true)
    }

    private var wantCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Want", spent: snapshot.wantsSpent, budget: snapshot.wantsBudget)
            AllocationBar(used: snapshot.wantsSpent, total: max(snapshot.wantsBudget, 1))
            ForEach(snapshot.wantRows) { row in
                categoryRow(row, showBudget: false)
            }
            Button("カテゴリを追加") { addingBucket = .wants }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Palette.card)
                .onTapGesture { quickMode = nil }
        }
        .hoverEffectDisabled(true)
    }

    private var otherCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("その他")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(Yen.format(otherSpent))
                    .font(.headline)
                    .foregroundStyle(Palette.accent)
            }
            Text("計算には入れない")
                .font(.caption)
                .foregroundStyle(Palette.secondary)
            ForEach(snapshot.otherRows) { row in
                categoryRow(row, showBudget: false)
            }
            Button("カテゴリを追加") { addingBucket = .other }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Palette.card)
                .onTapGesture { quickMode = nil }
        }
        .hoverEffectDisabled(true)
    }

    private var cardCheckCard: some View {
        let recorded = cardRecorded
        let actual = currentCardCheck
        let difference = recorded - (actual?.actualAmount ?? 0)
        return VStack(alignment: .leading, spacing: 10) {
            Text("カードの確認")
                .font(.headline)
                .foregroundStyle(Palette.ink)
            HStack {
                Text("記録")
                Spacer()
                Text(Yen.format(recorded))
            }
            Button {
                beginCardActual()
            } label: {
                HStack {
                    Text("実績")
                    Spacer()
                    Text(actual?.hasActual == true ? Yen.format(actual?.actualAmount ?? 0) : "未入力")
                        .foregroundStyle(quickMode == .cardActual ? Palette.accent : Palette.ink)
                }
            }
            .buttonStyle(.plain)
            .yenFocusBackground(quickMode == .cardActual)
            HStack {
                Text("差")
                Spacer()
                Text(actual?.hasActual == true ? (difference == 0 ? "一致" : Yen.formatSigned(difference)) : "—")
                    .foregroundStyle(difference == 0 || actual?.hasActual != true ? Palette.accent : Palette.danger)
            }
            Text("現金 \(Yen.format(cashRecorded))")
                .font(.caption)
                .foregroundStyle(Palette.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Palette.card)
                .onTapGesture { quickMode = nil }
        }
        .hoverEffectDisabled(true)
    }

    private var needRows: [CategorySpendRow] {
        (snapshot.lumpNeedRows + snapshot.flexibleNeedRows)
            .sorted { $0.category.sortOrder < $1.category.sortOrder }
    }

    private func heading(_ title: String, spent: Int, budget: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Spacer()
            Text("\(Yen.format(spent)) / \(Yen.format(budget))")
                .font(.headline)
                .foregroundStyle(spent > budget && budget > 0 ? Palette.danger : Palette.accent)
        }
    }

    @ViewBuilder
    private func categoryRow(_ row: CategorySpendRow, showBudget: Bool = true) -> some View {
        let rows: [CategorySpendRow] = switch row.category.bucket {
        case .wants: snapshot.wantRows
        case .other: snapshot.otherRows
        default: needRows
        }
        Group {
            if row.category.tracksPurchases {
                listRow(row, showBudget: showBudget)
            } else {
                directRow(row, showBudget: showBudget)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let source = items.first.flatMap(UUID.init(uuidString:)) else { return false }
            moveCategories(source, before: row.category.id, rows: rows)
            return true
        }
    }

    private func reorderHandle(_ id: UUID) -> some View {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(Palette.secondary)
            .frame(width: 28, height: 44)
            .contentShape(Rectangle())
            .draggable(id.uuidString)
            .accessibilityLabel("並べ替え")
    }

    private func directRow(_ row: CategorySpendRow, showBudget: Bool) -> some View {
        let focused = quickMode == .replace(row.category.id)
        return HStack(spacing: 4) {
            reorderHandle(row.category.id)
            Button {
                beginDirect(row.category, spent: row.spent)
            } label: {
                HStack {
                    Label(row.category.name, systemImage: row.category.symbolName)
                    Spacer()
                    Text(showBudget ? "\(Yen.format(row.spent)) / \(Yen.format(row.allocated))" : Yen.format(row.spent))
                        .foregroundStyle(showBudget && row.remaining < 0 ? Palette.danger : Palette.ink)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(row.category.name)
            .accessibilityValue(Yen.format(row.spent))
        }
        .yenFocusBackground(focused)
    }

    private func listRow(_ row: CategorySpendRow, showBudget: Bool) -> some View {
        let isOpen = expanded.contains(row.id)
        let items = purchaseLines(for: row.category)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                reorderHandle(row.category.id)
                Button {
                    toggle(row.id)
                } label: {
                    HStack {
                        Label(row.category.name, systemImage: row.category.symbolName)
                        Spacer()
                        Text(showBudget ? "\(Yen.format(row.spent)) / \(Yen.format(row.allocated))" : Yen.format(row.spent))
                            .foregroundStyle(showBudget && row.remaining < 0 ? Palette.danger : Palette.ink)
                        Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                            .foregroundStyle(Palette.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button {
                    addingCategory = CategoryAddRequest(category: row.category)
                    expanded.insert(row.id)
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.secondary)
                .accessibilityLabel("\(row.category.name)に支出を追加")
            }

            if isOpen {
                if items.isEmpty {
                    Text("なし")
                        .font(.caption)
                        .foregroundStyle(Palette.secondary)
                } else {
                    ForEach(items) { item in
                        Button {
                            editing = item.expense
                        } label: {
                            HStack {
                                Text(item.date, format: Date.FormatStyle(date: .numeric, time: .omitted).locale(Locale(identifier: "ja_JP")))
                                    .foregroundStyle(Palette.secondary)
                                Text(item.displayName)
                                Text(item.payment.title)
                                    .font(.caption)
                                    .foregroundStyle(Palette.secondary)
                                Spacer()
                                Text(Yen.format(item.amount))
                            }
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("削除", role: .destructive) {
                                deletePurchaseLine(item)
                            }
                        }
                    }
                }
            }
        }
    }

    private var periodExpenses: [Expense] {
        expenses.filter { session.period.contains($0.date) }
    }

    private func expenses(for category: MoneyCategory) -> [Expense] {
        periodExpenses.filter { expense in
            expense.lines.contains { $0.category?.id == category.id }
        }
    }

    private func purchaseLines(for category: MoneyCategory) -> [PurchaseLineItem] {
        periodExpenses
            .flatMap { expense in
                expense.lines
                    .filter { $0.category?.id == category.id }
                    .map { PurchaseLineItem(line: $0, expense: expense) }
            }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date > rhs.date }
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
    }

    private func deletePurchaseLine(_ item: PurchaseLineItem) {
        let expense = item.expense
        if expense.lines.count <= 1 {
            modelContext.delete(expense)
        } else if let line = expense.lines.first(where: { $0.id == item.id }) {
            modelContext.delete(line)
            expense.lines.removeAll { $0.id == item.id }
        }
        try? modelContext.save()
    }

    private func toggle(_ id: UUID) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }

    private func beginDirect(_ category: MoneyCategory, spent: Int) {
        if quickMode == .replace(category.id) {
            quickMode = nil
            return
        }
        Keyboard.dismiss()
        quickPayment = expenses(for: category).first?.payment ?? .card
        quickMode = .replace(category.id)
        quickAmountText = Yen.digits(spent)
    }

    private func beginCardActual() {
        if quickMode == .cardActual {
            quickMode = nil
            return
        }
        Keyboard.dismiss()
        quickAmountText = Yen.digits(currentCardCheck?.actualAmount ?? 0)
        quickMode = .cardActual
    }

    private func moveCategories(_ source: UUID, before target: UUID, rows: [CategorySpendRow]) {
        let ids = rows.map(\.category.id)
        guard let next = ListReorder.moving(ids, source: source, before: target) else { return }
        let orders = rows.map(\.category.sortOrder).sorted()
        for (id, order) in zip(next, orders) {
            categories.first { $0.id == id }?.sortOrder = order
        }
        try? modelContext.save()
        quickMode = nil
    }

    private func createCategory(name: String, bucket: BudgetBucket) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if categories.contains(where: { !$0.isArchived && $0.bucket == bucket && $0.name == trimmed }) {
            return
        }
        let peers = categories.filter { !$0.isArchived && $0.bucket == bucket }
        let order = (peers.map(\.sortOrder).max() ?? -1) + 1
        let created = MoneyCategory(
            name: trimmed,
            kind: .variable,
            sortOrder: order,
            symbolName: bucket == .needs ? "tag.fill" : (bucket == .other ? "tray.fill" : "sparkles"),
            bucket: bucket
        )
        modelContext.insert(created)
        try? modelContext.save()
    }

    private func saveQuick(_ category: MoneyCategory) {
        guard case .replace = quickMode else { return }
        saveDirect(category)
    }

    private func saveDirect(_ category: MoneyCategory) {
        let amount = Yen.parse(quickAmountText)
        let existing = expenses(for: category)
        if amount <= 0 {
            for expense in existing {
                modelContext.delete(expense)
            }
        } else if let first = existing.first {
            if let line = first.lines.first(where: { $0.category?.id == category.id }) {
                line.amount = amount
            } else {
                let line = ExpenseLine(amount: amount, category: category)
                line.expense = first
                first.lines.append(line)
            }
            for extra in existing.dropFirst() {
                modelContext.delete(extra)
            }
            first.payment = quickPayment
        } else {
            let expense = Expense(date: defaultExpenseDate, payment: quickPayment)
            let line = ExpenseLine(amount: amount, category: category)
            line.expense = expense
            expense.lines = [line]
            modelContext.insert(expense)
        }
        try? modelContext.save()
        quickMode = nil
    }

    private func saveCardActual() {
        let amount = Yen.parse(quickAmountText)
        if let existing = currentCardCheck {
            existing.actualAmount = amount
            existing.hasActual = true
        } else {
            modelContext.insert(CardCheck(periodKey: session.period.key, actualAmount: amount, hasActual: true))
        }
        try? modelContext.save()
        quickMode = nil
    }

    private var otherSpent: Int {
        snapshot.otherRows.reduce(0) { $0 + $1.spent }
    }

    private var cardRecorded: Int {
        periodExpenses.filter { $0.payment == .card }.reduce(0) { $0 + $1.totalAmount }
    }

    private var cashRecorded: Int {
        periodExpenses.filter { $0.payment == .cash }.reduce(0) { $0 + $1.totalAmount }
    }

    private var currentCardCheck: CardCheck? {
        cardChecks.first { $0.periodKey == session.period.key }
    }

    private var defaultExpenseDate: Date {
        let now = Date()
        if session.period.contains(now) { return now }
        return session.period.endInclusive
    }
}

private struct NewCategoryEditor: View {
    @Environment(\.dismiss) private var dismiss
    let bucket: BudgetBucket
    var onCreate: (String) -> Void
    @State private var name = ""

    var body: some View {
        Form {
            TextField("名前", text: $name)
        }
        .navigationTitle(bucket == .needs ? "Needを追加" : (bucket == .other ? "その他を追加" : "Wantを追加"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("追加") {
                    onCreate(name)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct CategoryAddRequest: Identifiable {
    var id: UUID { category.id }
    let category: MoneyCategory
}

private struct PurchaseLineItem: Identifiable {
    let id: UUID
    let expense: Expense
    let date: Date
    let displayName: String
    let amount: Int
    let payment: PaymentMethod

    init(line: ExpenseLine, expense: Expense) {
        self.id = line.id
        self.expense = expense
        self.date = expense.date
        self.payment = expense.payment
        if !line.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.displayName = line.name
        } else if !expense.merchant.isEmpty {
            self.displayName = expense.merchant
        } else {
            self.displayName = "支払"
        }
        self.amount = line.amount
    }
}
