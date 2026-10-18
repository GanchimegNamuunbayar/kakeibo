import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum Keyboard {
    static func dismiss() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

enum YenTyping {
    static func apply(key: String, to text: String) -> String {
        switch key {
        case "⌫":
            return text.isEmpty ? "" : String(text.dropLast())
        case "00":
            if text.isEmpty || text == "0" { return "0" }
            return text + "00"
        default:
            let digit = key.filter(\.isNumber)
            guard !digit.isEmpty else { return text }
            if text == "0" { return digit }
            return text + digit
        }
    }
}

/// システムキーボードを使わない金額欄。UITextField は iOS 26 で handler dropping を出すため使わない。
struct YenDigitsField: View {
    let title: String
    @Binding var text: String
    var isFocused: Bool = false
    var onFocus: (() -> Void)?

    @State private var localFocus = false

    private var focused: Bool {
        onFocus == nil ? localFocus : isFocused
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Keyboard.dismiss()
                if let onFocus {
                    onFocus()
                } else {
                    localFocus.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                    Spacer()
                    DigitsLabel(text: text.isEmpty ? "0" : text, accessibilityName: title)
                        .frame(minWidth: 80, minHeight: 24)
                        .allowsHitTesting(false)
                    Text("円")
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .foregroundStyle(focused ? Palette.accent : Palette.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(text.isEmpty ? "0" : text)

            if onFocus == nil && localFocus {
                YenKeypad(text: $text)
                    .frame(height: 200)
            }
        }
        .hoverEffectDisabled(true)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            localFocus = false
        }
    }
}

#if canImport(UIKit)
struct DigitsLabel: UIViewRepresentable {
    var text: String
    var accessibilityName: String

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.textAlignment = .right
        label.adjustsFontForContentSizeCategory = true
        label.font = .preferredFont(forTextStyle: .body)
        label.accessibilityLabel = accessibilityName
        label.isUserInteractionEnabled = false
        label.text = Yen.groupedDigits(text)
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.text = Yen.groupedDigits(text)
        uiView.accessibilityLabel = accessibilityName
    }
}

final class YenKeypadView: UIView {
    var onKey: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let keys = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["00", "0", "⌫"]]
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        for row in keys {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 8
            rowStack.distribution = .fillEqually
            for key in row {
                let button = UIButton(type: .system)
                button.setTitle(key, for: .normal)
                button.titleLabel?.font = .preferredFont(forTextStyle: .title2)
                button.accessibilityLabel = key
                button.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
                button.heightAnchor.constraint(equalToConstant: 44).isActive = true
                rowStack.addArrangedSubview(button)
            }
            stack.addArrangedSubview(rowStack)
        }
        stack.setContentHuggingPriority(.required, for: .vertical)
        stack.setContentCompressionResistancePriority(.required, for: .vertical)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 200)
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc private func tap(_ sender: UIButton) {
        onKey?(sender.accessibilityLabel ?? "")
    }
}

struct YenKeypad: UIViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> YenKeypadView {
        let view = YenKeypadView()
        view.onKey = { key in
            context.coordinator.apply(key)
        }
        return view
    }

    func updateUIView(_ uiView: YenKeypadView, context: Context) {
        context.coordinator.text = $text
        uiView.onKey = { key in
            context.coordinator.apply(key)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: YenKeypadView, context: Context) -> CGSize {
        CGSize(width: max(240, proposal.width ?? 240), height: proposal.height ?? 200)
    }

    final class Coordinator {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func apply(_ key: String) {
            text.wrappedValue = YenTyping.apply(key: key, to: text.wrappedValue)
        }
    }
}

/// 予算・ホーム・支出・ゴールで共用する数字パッド枠。項目名と書式付き金額を上段に出す。
struct YenKeypadBar: View {
    let title: String
    @Binding var text: String
    var showsClear: Bool = true
    var onSave: (() -> Void)? = nil
    var saveDisabled: Bool = false
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.secondary)
                    Text(Yen.format(Yen.parse(text)))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                }
                Spacer(minLength: 8)
                if showsClear {
                    Button("消す") { text = "" }
                        .disabled(text.isEmpty)
                }
                if let onSave {
                    Button("保存", action: onSave)
                        .disabled(saveDisabled)
                }
                Button("完了", action: onDone)
            }
            YenKeypad(text: $text)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .safeAreaPadding(.bottom)
        .background(Palette.card.ignoresSafeArea(edges: .bottom))
        .hoverEffectDisabled(true)
        .onAppear { Keyboard.dismiss() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            onDone()
        }
    }
}
#endif

extension View {
    /// 数字パッド選択中の行を背景で示す。
    func yenFocusBackground(_ focused: Bool) -> some View {
        padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                focused ? Palette.accent.opacity(0.14) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
    }
}

struct YenField: View {
    let title: String
    @Binding var amount: Int
    @State private var text = ""
    @State private var seeded = false

    var body: some View {
        YenDigitsField(
            title: title,
            text: Binding(
                get: { text },
                set: { newValue in
                    if text != newValue {
                        text = newValue
                    }
                    let parsed = Yen.parse(newValue)
                    if amount != parsed {
                        amount = parsed
                    }
                }
            )
        )
        .onAppear {
            if !seeded {
                text = Yen.digits(amount)
                seeded = true
            }
        }
    }
}

struct PeriodHeader: View {
    @Binding var period: PayPeriod

    var body: some View {
        HStack {
            Button {
                period = period.previous
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Palette.secondary)
            }
            VStack(spacing: 2) {
                Text(period.shortTitle)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Text(period.title)
                    .font(.caption)
                    .foregroundStyle(Palette.secondary)
            }
            .frame(maxWidth: .infinity)
            Button {
                period = period.next
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Palette.secondary)
            }
        }
        .buttonStyle(.plain)
        .hoverEffectDisabled(true)
    }
}

enum ListReorder {
    static func moving<T: Equatable>(_ items: [T], source: T, before target: T) -> [T]? {
        guard source != target,
              let from = items.firstIndex(of: source),
              items.contains(target) else { return nil }
        var next = items
        next.remove(at: from)
        let destination = next.firstIndex(of: target) ?? next.endIndex
        next.insert(source, at: destination)
        return next
    }
}

struct RuleBar: View {
    let needsUsed: Int
    let needsTotal: Int
    let wantsUsed: Int
    let wantsTotal: Int
    let savingsUsed: Int
    let savingsTotal: Int
    let needsWeight: Int
    let wantsWeight: Int
    let savingsWeight: Int

    var body: some View {
        GeometryReader { geo in
            let total = CGFloat(max(needsWeight + wantsWeight + savingsWeight, 1))
            let gap: CGFloat = 3
            let usable = max(0, geo.size.width - gap * 2)
            HStack(spacing: gap) {
                segment(used: needsUsed, total: needsTotal, width: usable * CGFloat(needsWeight) / total, color: Palette.needs)
                segment(used: wantsUsed, total: wantsTotal, width: usable * CGFloat(wantsWeight) / total, color: Palette.wants)
                segment(used: savingsUsed, total: savingsTotal, width: usable * CGFloat(savingsWeight) / total, color: Palette.savings)
            }
        }
        .frame(height: 12)
        .hoverEffectDisabled(true)
        .accessibilityLabel("必要 \(Yen.format(needsUsed)) / \(Yen.format(needsTotal))、余裕 \(Yen.format(wantsUsed)) / \(Yen.format(wantsTotal))、貯金 \(Yen.format(savingsUsed)) / \(Yen.format(savingsTotal))")
    }

    private func segment(used: Int, total: Int, width: CGFloat, color: Color) -> some View {
        let fill = total > 0 ? min(1, max(0, Double(used) / Double(total))) : (used > 0 ? 1 : 0)
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(color.opacity(0.22))
            Capsule()
                .fill(used > total && total > 0 ? Palette.danger : color)
                .frame(width: max(width * fill, used > 0 ? 4 : 0))
        }
        .frame(width: max(width, 1), height: 12)
    }
}

struct AllocationBar: View {
    let used: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return used > 0 ? 1 : 0 }
        return min(1, max(0, Double(used) / Double(total)))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.track)
                Capsule()
                    .fill(used > total ? Palette.danger : Palette.accent)
                    .frame(width: max(6, geo.size.width * progress))
            }
        }
        .frame(height: 8)
        .hoverEffectDisabled(true)
    }
}
