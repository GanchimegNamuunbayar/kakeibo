import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum Palette {
    /// 60%: 画面の地。薄い violet を一段濃くして、カードとの差を出す。
    static let canvas = Color(light: UIColor(red: 0.894, green: 0.851, blue: 0.945, alpha: 1),
                              dark: UIColor(red: 0.078, green: 0.051, blue: 0.122, alpha: 1))
    static let card = Color(light: UIColor(red: 0.965, green: 0.941, blue: 0.988, alpha: 1),
                            dark: UIColor(red: 0.165, green: 0.114, blue: 0.227, alpha: 1))
    static let ink = Color(light: UIColor(red: 0.110, green: 0.063, blue: 0.196, alpha: 1),
                           dark: UIColor(red: 0.945, green: 0.922, blue: 0.980, alpha: 1))

    /// 30%: 見出し・補助テキスト・バーの下地。
    static let secondary = Color(light: UIColor(red: 0.329, green: 0.235, blue: 0.478, alpha: 1),
                                 dark: UIColor(red: 0.620, green: 0.545, blue: 0.780, alpha: 1))
    static let track = Color(light: UIColor(red: 0.329, green: 0.235, blue: 0.478, alpha: 0.22),
                             dark: UIColor(red: 0.620, green: 0.545, blue: 0.780, alpha: 0.32))

    /// 10%: 残り金額・選択中・保存だけ、さらに濃い violet。
    static let accent = Color(light: UIColor(red: 0.400, green: 0.141, blue: 0.722, alpha: 1),
                              dark: UIColor(red: 0.580, green: 0.400, blue: 0.920, alpha: 1))

    static let danger = Color(light: UIColor(red: 0.690, green: 0.220, blue: 0.310, alpha: 1),
                              dark: UIColor(red: 0.910, green: 0.478, blue: 0.541, alpha: 1))

    static let needs = accent
    static let wants = Color(light: UIColor(red: 0.545, green: 0.353, blue: 0.784, alpha: 1),
                             dark: UIColor(red: 0.710, green: 0.560, blue: 0.940, alpha: 1))
    static let savings = Color(light: UIColor(red: 0.220, green: 0.071, blue: 0.420, alpha: 1),
                               dark: UIColor(red: 0.780, green: 0.690, blue: 0.980, alpha: 1))
}

extension Color {
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct KakeiboScreen: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Palette.canvas.ignoresSafeArea())
            .tint(Palette.accent)
            .foregroundStyle(Palette.ink)
    }
}

extension View {
    func kakeiboScreen() -> some View {
        modifier(KakeiboScreen())
    }
}
