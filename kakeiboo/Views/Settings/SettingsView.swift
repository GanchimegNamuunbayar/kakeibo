import SwiftUI
import SwiftData

struct SettingsView: View {
    let snapshot: BudgetSnapshot

    var body: some View {
        List {
            Section {
                LabeledContent("期間", value: snapshot.period.title)
                LabeledContent("収入", value: Yen.format(snapshot.income))
                LabeledContent("Need", value: "\(snapshot.needsSharePercent)%  \(Yen.format(snapshot.needsSpent)) / \(Yen.format(snapshot.needsBudget))")
                LabeledContent("Save", value: "\(snapshot.savingsSharePercent)%  \(Yen.format(snapshot.savingsTarget))")
                LabeledContent("Want", value: "\(snapshot.wantsSharePercent)%  \(Yen.format(snapshot.wantsSpent)) / \(Yen.format(snapshot.wantsBudget))")
            }
            Section {
                NavigationLink {
                    BudgetEditorView()
                } label: {
                    Label("予算", systemImage: "chart.pie.fill")
                }
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
        }
        .navigationTitle("設定")
        .scrollContentBackground(.hidden)
        .background(Palette.canvas)
        .tint(Palette.accent)
    }
}

struct FixedCostListView: View {
    @Environment(Session.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FixedCostPlan.name) private var plans: [FixedCostPlan]
    @State private var isAdding = false
    @State private var editing: FixedCostPlan?

    var body: some View {
        List {
            Section {
                if plans.isEmpty {
                    Text("未登録")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(plans) { plan in
                        Button {
                            editing = plan
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(plan.name)
                                    Spacer()
                                    Text(Yen.format(plan.amount))
                                }
                                HStack {
                                    Text(plan.category?.name ?? "未分類")
                                    if plan.isPaused {
                                        Text("停止中")
                                    } else if plan.isActive(in: session.period) {
                                        Text("今月有効")
                                    } else {
                                        Text("今月は対象外")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(plans[index])
                        }
                        try? modelContext.save()
                    }
                }
            }
        }
        .navigationTitle("定額")
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
            NavigationStack { FixedCostEditorView(plan: nil) }
        }
        .sheet(item: $editing) { plan in
            NavigationStack { FixedCostEditorView(plan: plan) }
        }
    }
}

struct FixedCostEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]
    let plan: FixedCostPlan?

    @State private var name = ""
    @State private var amount = 0
    @State private var categoryID: UUID?
    @State private var isPaused = false

    private var fixedCategories: [MoneyCategory] {
        categories.filter { $0.kind == .fixed && !$0.isArchived }
    }

    var body: some View {
        Form {
            TextField("名前", text: $name)
            YenField(title: "予定額", amount: $amount)
            Picker("カテゴリ", selection: $categoryID) {
                Text("未分類").tag(UUID?.none)
                ForEach(fixedCategories) { category in
                    Text(category.name).tag(Optional(category.id))
                }
            }
            Toggle("一時停止", isOn: $isPaused)
        }
        .navigationTitle(plan == nil ? "定額を追加" : "定額を編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    let target = plan ?? FixedCostPlan(name: "", amount: 0, category: nil)
                    if plan == nil {
                        modelContext.insert(target)
                    }
                    target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    target.amount = amount
                    target.category = categories.first { $0.id == categoryID }
                    target.isPaused = isPaused
                    try? modelContext.save()
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount <= 0)
            }
        }
        .onAppear {
            guard let plan else {
                categoryID = fixedCategories.first?.id
                return
            }
            name = plan.name
            amount = plan.amount
            categoryID = plan.category?.id
            isPaused = plan.isPaused
        }
    }
}

struct CategoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]
    @State private var isAdding = false

    var body: some View {
        List {
            Section("Need") {
                ForEach(categories.filter { $0.bucket == .needs && !$0.isArchived }) { category in
                    categoryRow(category)
                }
            }
            Section("Want") {
                ForEach(categories.filter { $0.bucket == .wants && !$0.isArchived }) { category in
                    categoryRow(category)
                }
            }
        }
        .navigationTitle("カテゴリ")
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
            NavigationStack { CategoryEditorView() }
        }
    }

    private func categoryRow(_ category: MoneyCategory) -> some View {
        Label {
            HStack {
                Text(category.name)
                Text(category.bucket.title)
                    .font(.caption)
                    .foregroundStyle(Palette.secondary)
            }
        } icon: {
            Image(systemName: category.symbolName)
        }
    }
}

struct CategoryEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [MoneyCategory]
    @State private var name = ""
    @State private var kind: CategoryKind = .variable
    @State private var bucket: BudgetBucket = .wants

    var body: some View {
        Form {
            TextField("名前", text: $name)
            Picker("種類", selection: $kind) {
                ForEach(CategoryKind.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            Picker("分け方", selection: $bucket) {
                ForEach(BudgetBucket.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
        }
        .navigationTitle("カテゴリを追加")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    let category = MoneyCategory(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        kind: kind,
                        sortOrder: (categories.map(\.sortOrder).max() ?? 0) + 1,
                        symbolName: kind == .fixed ? "building.columns.fill" : "tag.fill",
                        bucket: bucket
                    )
                    modelContext.insert(category)
                    try? modelContext.save()
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
