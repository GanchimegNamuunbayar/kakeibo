import SwiftUI

/// 予算ページと同じ構造: 金額は数字パッド、入力のたびに親が合計を再計算する。
struct YenFieldChurnHarness: View {
    @State var incomeText = ""
    @State var rentText = ""
    @State var foodText = ""
    @State var emergencyText = ""
    @State var focused = "収入"

    var body: some View {
        let income = Yen.parse(incomeText)
        let total = Yen.parse(rentText) + Yen.parse(foodText) + Yen.parse(emergencyText)

        VStack(alignment: .leading, spacing: 12) {
            YenDigitsField(title: "収入", text: $incomeText, isFocused: focused == "収入") {
                focused = "収入"
            }
            Text("収入 \(Yen.format(income))")
                .accessibilityIdentifier("derived-income")
            YenDigitsField(title: "家賃", text: $rentText, isFocused: focused == "家賃") {
                focused = "家賃"
            }
            YenDigitsField(title: "食費", text: $foodText, isFocused: focused == "食費") {
                focused = "食費"
            }
            YenDigitsField(title: "緊急", text: $emergencyText, isFocused: focused == "緊急") {
                focused = "緊急"
            }
            Text("合計 \(Yen.format(total))")
                .accessibilityIdentifier("derived-total")
            YenKeypad(text: focusedText)
                .frame(height: 200)
        }
        .padding()
        .hoverEffectDisabled(true)
    }

    private var focusedText: Binding<String> {
        Binding(
            get: {
                switch focused {
                case "家賃": rentText
                case "食費": foodText
                case "緊急": emergencyText
                default: incomeText
                }
            },
            set: { newValue in
                switch focused {
                case "家賃": rentText = newValue
                case "食費": foodText = newValue
                case "緊急": emergencyText = newValue
                default: incomeText = newValue
                }
            }
        )
    }
}
