import SwiftUI
import SwiftData

struct AmountDraft: Identifiable, Equatable {
    var id: UUID
    var name: String
    var amountText: String
    var categoryID: UUID?
    var existsInStore: Bool

    var amount: Int { Yen.parse(amountText) }
}

struct BudgetEditorView: View {
    @Environment(Session.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]
    @Query private var budgets: [MonthlyBudget]
    @Query(sort: \FixedCostPlan.name) private var plans: [FixedCostPlan]
    @Query private var savingsRecords: [MonthlySavings]
    @State private var incomeDrafts: [AmountDraft] = []
    @State private var needDrafts: [AmountDraft] = []
    @State private var saveDrafts: [AmountDraft] = []
    @State private var wantDrafts: [AmountDraft] = []
    var startsWithKeypad = false
    @State private var yenFocus: YenFocus?
    @State private var didSave = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PeriodHeader(period: Bindable(session).period)

                card(title: "収入", trailing: Yen.format(income)) {
                    namedRows($incomeDrafts, kind: .income, placeholder: "収入", showsName: false, showsRemove: false, showsFixedTitle: true)
                }

                card(title: "Need", trailing: "\(needsSharePercent)%  \(Yen.format(needsAllocated))") {
                    namedRows($needDrafts, kind: .need, placeholder: "Need")
                    addButton { needDrafts.append(blankDraft()) }
                }

                card(title: "Save", trailing: "\(savingsSharePercent)%  \(Yen.format(savingsTarget))") {
                    namedRows($saveDrafts, kind: .save, placeholder: "Save", showsName: false)
                    addButton { saveDrafts.append(blankDraft()) }
                }

                card(title: "Want", trailing: "\(wantsSharePercent)%  \(Yen.format(wantsBudget))") {
                    namedRows($wantDrafts, kind: .want, placeholder: "Want")
                    addButton { wantDrafts.append(blankDraft()) }
                    if wantAllocated != wantsBudget {
                        Text("内訳 \(Yen.format(wantAllocated))")
                            .font(.footnote)
                            .foregroundStyle(Palette.secondary)
                    }
                }

                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.immediately)
        .background {
            Palette.canvas
                .ignoresSafeArea()
                .onTapGesture { yenFocus = nil }
        }
        .overlay(alignment: .top) {
            if didSave {
                Text("保存しました")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Palette.card, in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: didSave)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if yenFocus != nil {
                YenKeypadBar(
                    title: focusedFieldTitle,
                    text: focusedYenText,
                    onDone: { yenFocus = nil }
                )
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .hoverEffectDisabled(true)
        .navigationTitle("予算")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
            }
        }
        .onAppear {
            load()
            if startsWithKeypad, let first = incomeDrafts.first {
                yenFocus = .income(first.id)
            }
        }
        .onChange(of: session.period.key) { _, _ in
            load()
        }
    }

    private func card(title: String, trailing: String?, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.headline)
                        .foregroundStyle(Palette.accent)
                }
            }
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Palette.card)
                .onTapGesture { yenFocus = nil }
        }
    }

    private func addButton(_ action: @escaping () -> Void) -> some View {
        Button("追加", action: action)
    }

    private func blankDraft() -> AmountDraft {
        AmountDraft(id: UUID(), name: "", amountText: "", existsInStore: false)
    }

    private func namedRows(
        _ drafts: Binding<[AmountDraft]>,
        kind: LineKind,
        placeholder: String,
        showsName: Bool = true,
        showsRemove: Bool = true,
        showsFixedTitle: Bool = false
    ) -> some View {
        ForEach(drafts) { $draft in
            namedRow(
                draft: $draft,
                kind: kind,
                placeholder: placeholder,
                showsName: showsName,
                showsRemove: showsRemove,
                showsFixedTitle: showsFixedTitle
            )
        }
    }

    private func namedRow(
        draft: Binding<AmountDraft>,
        kind: LineKind,
        placeholder: String,
        showsName: Bool,
        showsRemove: Bool = true,
        showsFixedTitle: Bool = false
    ) -> some View {
        let id = draft.wrappedValue.id
        let focused = yenFocus == kind.focus(id)
        let canReorder = kind == .need || kind == .want
        return HStack(alignment: .center, spacing: 8) {
            if canReorder {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(Palette.secondary)
                    .frame(width: 28, height: 44)
                    .contentShape(Rectangle())
                    .draggable(id.uuidString)
                    .accessibilityLabel("並べ替え")
            }
            if showsFixedTitle {
                Text(draft.wrappedValue.name)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if showsName {
                TextField("名前", text: draft.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: 44)
            }
            amountButton(
                title: draft.wrappedValue.name.isEmpty ? placeholder : draft.wrappedValue.name,
                text: draft.wrappedValue.amountText,
                focused: focused,
                showsTitle: false,
                onClear: {
                    updateAmount(id: id, kind: kind, text: "")
                }
            ) {
                Keyboard.dismiss()
                yenFocus = focused ? nil : kind.focus(id)
            }
            if showsRemove {
                Button {
                    if focused { yenFocus = nil }
                    switch kind {
                    case .income: incomeDrafts.removeAll { $0.id == id }
                    case .need: needDrafts.removeAll { $0.id == id }
                    case .save: saveDrafts.removeAll { $0.id == id }
                    case .want: wantDrafts.removeAll { $0.id == id }
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(Palette.secondary)
                }
                .buttonStyle(.plain)
                .hoverEffectDisabled(true)
            }
        }
        .yenFocusBackground(focused)
        .dropDestination(for: String.self) { items, _ in
            guard canReorder, let source = items.first.flatMap(UUID.init(uuidString:)) else { return false }
            moveDraft(kind: kind, source: source, target: id)
            return true
        }
    }

    private func moveDraft(kind: LineKind, source: UUID, target: UUID) {
        func apply(_ drafts: inout [AmountDraft], base: Int) {
            let current = drafts
            let ids = current.map(\.id)
            guard let next = ListReorder.moving(ids, source: source, before: target) else { return }
            drafts = next.compactMap { id in current.first { $0.id == id } }
            let linked = drafts.compactMap(\.categoryID)
            let orders = linked.compactMap { id in categories.first { $0.id == id }?.sortOrder }.sorted()
            for (id, order) in zip(linked, orders) where !orders.isEmpty {
                categories.first { $0.id == id }?.sortOrder = order
            }
            if orders.isEmpty {
                for (offset, id) in linked.enumerated() {
                    categories.first { $0.id == id }?.sortOrder = base + offset
                }
            }
        }
        switch kind {
        case .need:
            apply(&needDrafts, base: 0)
        case .want:
            apply(&wantDrafts, base: 1_000)
        case .income, .save:
            break
        }
        try? modelContext.save()
        yenFocus = nil
    }

    private func amountButton(
        title: String,
        text: String,
        focused: Bool,
        showsTitle: Bool = true,
        onClear: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 4) {
            Button(action: action) {
                HStack {
                    if showsTitle {
                        Text(title)
                        Spacer()
                    }
                    DigitsLabel(text: text.isEmpty ? "0" : text, accessibilityName: title)
                        .frame(minWidth: 80, minHeight: 24)
                        .allowsHitTesting(false)
                    Text("円")
                        .foregroundStyle(Palette.secondary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .foregroundStyle(focused ? Palette.accent : Palette.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(text.isEmpty ? "0" : text)

            if onClear != nil, !text.isEmpty {
                Button {
                    onClear?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Palette.secondary)
                        .frame(width: 36, height: 44)
                }
                .buttonStyle(.plain)
                .hoverEffectDisabled(true)
                .accessibilityLabel("消す")
            }
        }
        .hoverEffectDisabled(true)
    }

    private var focusedFieldTitle: String {
        switch yenFocus {
        case .income(let id):
            let name = incomeDrafts.first { $0.id == id }?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? "収入" : name
        case .need(let id):
            let name = needDrafts.first { $0.id == id }?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? "Need" : name
        case .save:
            return "Save"
        case .want(let id):
            let name = wantDrafts.first { $0.id == id }?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? "Want" : name
        case nil:
            return ""
        }
    }

    private enum LineKind {
        case income, need, save, want

        func focus(_ id: UUID) -> YenFocus {
            switch self {
            case .income: .income(id)
            case .need: .need(id)
            case .save: .save(id)
            case .want: .want(id)
            }
        }
    }

    private enum YenFocus: Hashable {
        case income(UUID)
        case need(UUID)
        case save(UUID)
        case want(UUID)
    }

    private var focusedYenText: Binding<String> {
        Binding(
            get: {
                switch yenFocus {
                case .income(let id): amountText(id, in: incomeDrafts)
                case .need(let id): amountText(id, in: needDrafts)
                case .save(let id): amountText(id, in: saveDrafts)
                case .want(let id): amountText(id, in: wantDrafts)
                case nil: ""
                }
            },
            set: { newValue in
                switch yenFocus {
                case .income(let id): updateAmount(id: id, kind: .income, text: newValue)
                case .need(let id): updateAmount(id: id, kind: .need, text: newValue)
                case .save(let id): updateAmount(id: id, kind: .save, text: newValue)
                case .want(let id): updateAmount(id: id, kind: .want, text: newValue)
                case nil: break
                }
            }
        )
    }

    private func amountText(_ id: UUID, in drafts: [AmountDraft]) -> String {
        drafts.first { $0.id == id }?.amountText ?? ""
    }

    private func updateAmount(id: UUID, kind: LineKind, text: String) {
        switch kind {
        case .income: setAmount(&incomeDrafts, id: id, text: text)
        case .need: setAmount(&needDrafts, id: id, text: text)
        case .save: setAmount(&saveDrafts, id: id, text: text)
        case .want: setAmount(&wantDrafts, id: id, text: text)
        }
    }

    private func setAmount(_ drafts: inout [AmountDraft], id: UUID, text: String) {
        if let index = drafts.firstIndex(where: { $0.id == id }) {
            drafts[index].amountText = text
        }
    }

    private var income: Int {
        incomeDrafts.reduce(0) { $0 + $1.amount }
    }

    private var needsAllocated: Int {
        needDrafts.reduce(0) { $0 + $1.amount }
    }

    private var savingsTarget: Int {
        BudgetDefaults.resolvedSave(
            income: income,
            needBudget: needsAllocated,
            storedAmount: saveDrafts.reduce(0) { $0 + $1.amount },
            isCustom: true
        )
    }

    private var wantsBudget: Int {
        BudgetDefaults.wantBudget(income: income, needBudget: needsAllocated, save: savingsTarget)
    }

    private var wantAllocated: Int {
        wantDrafts.reduce(0) { $0 + $1.amount }
    }

    private var shares: (need: Int, save: Int, want: Int) {
        BudgetDefaults.sharePercents(need: needsAllocated, save: savingsTarget, income: income)
    }

    private var needsSharePercent: Int { shares.need }
    private var wantsSharePercent: Int { shares.want }
    private var savingsSharePercent: Int { shares.save }

    private var currentBudget: MonthlyBudget? {
        budgets.first { $0.periodKey == session.period.key }
    }

    private var previousBudget: MonthlyBudget? {
        budgets.first { $0.periodKey == session.period.previous.key }
    }

    private func load() {
        loadIncomeDrafts()
        loadNeedDrafts()
        loadSaveDrafts()
        loadWantDrafts()
    }

    private func loadIncomeDrafts() {
        let source = currentBudget ?? previousBudget
        let lines = source?.incomeLines ?? []
        let storedHere = source?.periodKey == session.period.key
        let legacy = lines.filter { !IncomeSource.all.contains($0.name) }.reduce(0) { $0 + $1.amount }
        incomeDrafts = IncomeSource.all.enumerated().map { index, name in
            let line = lines.first { $0.name == name }
            let fallback = index == 0 && lines.allSatisfy { !IncomeSource.all.contains($0.name) }
                ? (legacy > 0 ? legacy : (source?.spendingBudget ?? 0))
                : 0
            return AmountDraft(
                id: line?.id ?? UUID(),
                name: name,
                amountText: Yen.digits(line?.amount ?? fallback),
                existsInStore: storedHere && line != nil
            )
        }
    }

    private func loadNeedDrafts() {
        let needCategories = categories
            .filter { !$0.isArchived && $0.bucket == .needs }
            .sorted { $0.sortOrder < $1.sortOrder }
        if needCategories.isEmpty {
            needDrafts = BudgetDefaults.needItems.map { item in
                AmountDraft(
                    id: UUID(),
                    name: item.name,
                    amountText: Yen.digits(item.amount),
                    existsInStore: false
                )
            }
            return
        }
        needDrafts = needCategories.map { category in
            AmountDraft(
                id: category.id,
                name: category.name,
                amountText: Yen.digits(needAmount(for: category)),
                categoryID: category.id,
                existsInStore: true
            )
        }
    }

    private func needAmount(for category: MoneyCategory) -> Int {
        if category.inputStyle == .lumpSum {
            if let plan = plans.first(where: { $0.category?.id == category.id && $0.isActive(in: session.period) }) {
                return plan.amount
            }
            return BudgetDefaults.amount(for: category.name)
        }
        return currentBudget?.envelopes.first { $0.category?.id == category.id }?.amount
            ?? previousBudget?.envelopes.first { $0.category?.id == category.id }?.amount
            ?? BudgetDefaults.amount(for: category.name)
    }

    private func loadSaveDrafts() {
        let source = currentBudget ?? previousBudget
        let lines = (source?.saveLines ?? []).sorted { $0.sortOrder < $1.sortOrder }
        if !lines.isEmpty {
            saveDrafts = lines.map { line in
                AmountDraft(
                    id: line.id,
                    name: line.name,
                    amountText: Yen.digits(line.amount),
                    existsInStore: source?.periodKey == session.period.key
                )
            }
            return
        }
        let amount = BudgetDefaults.resolvedSave(
            income: income,
            needBudget: needsAllocated,
            storedAmount: source?.savingsAmount ?? 0,
            isCustom: source?.hasCustomSavings ?? false
        )
        saveDrafts = [
            AmountDraft(id: UUID(), name: "", amountText: Yen.digits(amount), existsInStore: false)
        ]
    }

    private func loadWantDrafts() {
        let wantCategories = categories
            .filter { !$0.isArchived && $0.bucket == .wants }
            .sorted { $0.sortOrder < $1.sortOrder }
        if wantCategories.isEmpty {
            wantDrafts = BudgetDefaults.wantItems.map { item in
                AmountDraft(
                    id: UUID(),
                    name: item.name,
                    amountText: Yen.digits(item.amount),
                    existsInStore: false
                )
            }
            return
        }
        wantDrafts = wantCategories.map { category in
            AmountDraft(
                id: category.id,
                name: category.name,
                amountText: Yen.digits(wantAmount(for: category)),
                categoryID: category.id,
                existsInStore: true
            )
        }
    }

    private func wantAmount(for category: MoneyCategory) -> Int {
        currentBudget?.envelopes.first { $0.category?.id == category.id }?.amount
            ?? previousBudget?.envelopes.first { $0.category?.id == category.id }?.amount
            ?? BudgetDefaults.amount(for: category.name)
    }

    private func save() {
        yenFocus = nil
        let budget = currentBudget ?? MonthlyBudget(periodKey: session.period.key, totalAmount: 0, income: 0)
        if currentBudget == nil {
            modelContext.insert(budget)
        }
        archiveRemovedCategories(keeping: needDrafts, bucket: .needs)
        archiveRemovedCategories(keeping: wantDrafts, bucket: .wants)
        saveNeedDrafts(on: budget)
        saveWantDrafts(on: budget)
        budget.income = income
        budget.totalAmount = income
        budget.spendingTotal = needsAllocated + wantsBudget
        budget.savingsAmount = savingsTarget
        budget.hasCustomSavings = true
        replaceIncomeLines(on: budget)
        replaceSaveLines(on: budget)
        if let existing = savingsRecords.first(where: { $0.periodKey == session.period.key }) {
            existing.plannedAmount = savingsTarget
        } else {
            modelContext.insert(MonthlySavings(periodKey: session.period.key, plannedAmount: savingsTarget))
        }
        try? modelContext.save()
        load()
        showSavedMessage()
    }

    private func showSavedMessage() {
        didSave = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            didSave = false
        }
    }

    private func replaceIncomeLines(on budget: MonthlyBudget) {
        for line in budget.incomeLines {
            modelContext.delete(line)
        }
        budget.incomeLines = []
        for (index, draft) in incomeDrafts.enumerated() {
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let line = IncomeLine(
                name: IncomeSource.all.contains(name) ? name : (IncomeSource.all.indices.contains(index) ? IncomeSource.all[index] : name),
                amount: draft.amount,
                sortOrder: index
            )
            line.budget = budget
            budget.incomeLines.append(line)
        }
    }

    private func replaceSaveLines(on budget: MonthlyBudget) {
        for line in budget.saveLines {
            modelContext.delete(line)
        }
        budget.saveLines = []
        for (index, draft) in saveDrafts.enumerated() {
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty && draft.amount == 0 { continue }
            let line = SaveLine(
                name: name.isEmpty ? "Save" : name,
                amount: draft.amount,
                sortOrder: index
            )
            line.budget = budget
            budget.saveLines.append(line)
        }
    }

    private func saveNeedDrafts(on budget: MonthlyBudget) {
        var keptIDs: Set<UUID> = []
        var order = 0
        for draft in needDrafts {
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty && draft.amount == 0 { continue }
            let displayName = name.isEmpty ? "Need" : name
            let category = upsertCategory(
                named: displayName,
                bucket: .needs,
                kind: existingKind(for: draft) ?? .variable,
                categoryID: draft.categoryID
            )
            category.sortOrder = order
            order += 1
            keptIDs.insert(category.id)
            if category.inputStyle == .lumpSum {
                if let plan = plans.first(where: { $0.category?.id == category.id && $0.isActive(in: session.period) }) {
                    plan.name = displayName
                    plan.amount = draft.amount
                } else {
                    modelContext.insert(FixedCostPlan(name: displayName, amount: draft.amount, category: category))
                }
            } else if let envelope = budget.envelopes.first(where: { $0.category?.id == category.id }) {
                envelope.amount = draft.amount
            } else {
                let envelope = Envelope(amount: draft.amount, category: category)
                envelope.budget = budget
                budget.envelopes.append(envelope)
            }
        }
        for envelope in budget.envelopes where envelope.category?.bucket == .needs {
            if let id = envelope.category?.id, !keptIDs.contains(id) {
                modelContext.delete(envelope)
            }
        }
    }

    private func saveWantDrafts(on budget: MonthlyBudget) {
        var keptIDs: Set<UUID> = []
        var order = 1_000
        for draft in wantDrafts {
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty && draft.amount == 0 { continue }
            let displayName = name.isEmpty ? "Want" : name
            let category = upsertCategory(
                named: displayName,
                bucket: .wants,
                kind: .variable,
                categoryID: draft.categoryID
            )
            category.sortOrder = order
            order += 1
            keptIDs.insert(category.id)
            if let envelope = budget.envelopes.first(where: { $0.category?.id == category.id }) {
                envelope.amount = draft.amount
            } else {
                let envelope = Envelope(amount: draft.amount, category: category)
                envelope.budget = budget
                budget.envelopes.append(envelope)
            }
        }
        for envelope in budget.envelopes where envelope.category?.bucket == .wants {
            if let id = envelope.category?.id, !keptIDs.contains(id) {
                modelContext.delete(envelope)
            }
        }
    }

    private func archiveRemovedCategories(keeping drafts: [AmountDraft], bucket: BudgetBucket) {
        let keptIDs = Set(drafts.compactMap(\.categoryID))
        let keptNames = Set(drafts.map { draft in
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return name
        }.filter { !$0.isEmpty })
        for category in categories where !category.isArchived && category.bucket == bucket {
            if keptIDs.contains(category.id) || keptNames.contains(category.name) { continue }
            category.isArchived = true
            for plan in plans where plan.category?.id == category.id {
                modelContext.delete(plan)
            }
        }
    }

    private func existingKind(for draft: AmountDraft) -> CategoryKind? {
        guard let categoryID = draft.categoryID else { return nil }
        return categories.first { $0.id == categoryID }?.kind
    }

    private func upsertCategory(
        named name: String,
        bucket: BudgetBucket,
        kind: CategoryKind,
        categoryID: UUID?
    ) -> MoneyCategory {
        if let categoryID, let existing = categories.first(where: { $0.id == categoryID }) {
            existing.name = name
            existing.bucket = bucket
            return existing
        }
        if let existing = categories.first(where: { $0.name == name && !$0.isArchived && $0.bucket == bucket }) {
            return existing
        }
        let created = MoneyCategory(
            name: name,
            kind: kind,
            sortOrder: nextSortOrder,
            symbolName: bucket == .needs ? "tag.fill" : "sparkles",
            bucket: bucket
        )
        modelContext.insert(created)
        return created
    }

    private var nextSortOrder: Int {
        (categories.map(\.sortOrder).max() ?? -1) + 1
    }
}
