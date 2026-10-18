import XCTest
import SwiftUI
import SwiftData
import UIKit
import OSLog
@testable import kakeiboo

@MainActor
final class YenInputStabilityTests: XCTestCase {
    private var retained: [Any] = []

    override func tearDown() {
        retained.removeAll()
        super.tearDown()
    }

    func testYenParseReadsDigitsOnly() {
        XCTAssertEqual(Yen.parse(""), 0)
        XCTAssertEqual(Yen.parse("250000"), 250_000)
        XCTAssertEqual(Yen.parse("12,000"), 12_000)
        XCTAssertEqual(Yen.digits(0), "")
        XCTAssertEqual(Yen.digits(250_000), "250000")
        XCTAssertEqual(Yen.groupedDigits("5100"), "5,100")
        XCTAssertEqual(Yen.groupedDigits("250000"), "250,000")
        XCTAssertEqual(Yen.groupedDigits(""), "0")
        XCTAssertEqual(ListReorder.moving(["食費", "日用品", "ガス"], source: "ガス", before: "食費"), ["ガス", "食費", "日用品"])
    }

    func testYenTypingAppliesDigitsDeleteAndClear() {
        XCTAssertEqual(YenTyping.apply(key: "2", to: ""), "2")
        XCTAssertEqual(YenTyping.apply(key: "5", to: "2"), "25")
        XCTAssertEqual(YenTyping.apply(key: "0", to: "25"), "250")
        XCTAssertEqual(YenTyping.apply(key: "⌫", to: "250"), "25")
        XCTAssertEqual(YenTyping.apply(key: "00", to: "25"), "2500")
        XCTAssertEqual(YenTyping.apply(key: "00", to: ""), "0")
        XCTAssertEqual(YenTyping.apply(key: "3", to: "0"), "3")
    }

    func testKeypadTypingIncomeDoesNotLogReceiverDataOrRecreatePad() {
        let host = makeHost(YenFieldChurnHarness())
        guard let pad = host.view.findYenKeypad() else {
            XCTFail("数字パッドが見つかりません")
            return
        }
        let original = pad
        typeKeys(["2", "5", "0", "0", "0", "0"], in: host)
        XCTAssertEqual(host.view.findYenKeypad() === original, true, "数字パッドが作り直されました")
        XCTAssertTrue(
            host.view.showsYenDigits("250,000"),
            "収入に 250000 が入っていません。表示: \(host.view.allUILabels().compactMap(\.text))"
        )
        assertNoReceiverData()
    }

    func testBudgetEditorHidesKeypadUntilIncomeIsFocused() throws {
        let host = try makeBudgetEditorHost(startsWithKeypad: false)
        XCTAssertNil(host.view.findYenKeypad(), "予算を開いた直後からパッドが出ています")
        XCTAssertNotNil(host.view.findDigitsLabel(named: "奨学金"), "奨学金の収入欄が見えません")
        XCTAssertNotNil(host.view.findDigitsLabel(named: "Emoba"), "Emobaの収入欄が見えません")
    }

    func testBudgetEditorShowsCursorProAndWantSubscriptions() throws {
        let host = try makeBudgetEditorHost(startsWithKeypad: false)
        XCTAssertEqual(host.view.findDigitsLabel(named: "Cursor Pro")?.text, "3,187")
        XCTAssertEqual(host.view.findDigitsLabel(named: "Spotify")?.text, "580")
        XCTAssertEqual(host.view.findDigitsLabel(named: "Audible")?.text, "1,500")
    }

    func testBudgetEditorIncomeUsesKeypadNotTextField() throws {
        let host = try makeBudgetEditorHost(startsWithKeypad: true)
        XCTAssertNil(
            host.view.findUITextField(labeled: "収入"),
            "収入が UITextField のままです。これが cannot add handler の原因になります"
        )
        guard let pad = host.view.findYenKeypad() else {
            XCTFail("収入を選んだあとに数字パッドが出ません")
            return
        }
        let padFrame = pad.convert(pad.bounds, to: host.view)
        XCTAssertLessThanOrEqual(
            pad.bounds.height,
            host.view.bounds.height / 2,
            "数字パッドが画面の半分以上を占めています"
        )
        XCTAssertLessThanOrEqual(
            padFrame.maxY,
            host.view.bounds.maxY,
            "数字パッドの一部がフッターに隠れています"
        )
        typeKeys(["2", "5", "0", "0", "0", "0"], in: host)
        XCTAssertTrue(
            host.view.showsYenDigits("250,000"),
            "収入に 250000 が入っていません。表示: \(host.view.allUILabels().compactMap(\.text))"
        )
        assertNoReceiverData()
    }

    func testHomeDoesNotShowHeroRemainingAmount() throws {
        let snapshot = BudgetSnapshot(
            period: .containing(),
            hasBudget: true,
            totalAmount: 250_000,
            income: 250_000,
            spendingTotal: 200_000,
            plannedFixedTotal: 80_000,
            effectiveFixedTotal: 80_000,
            variableSpent: 12_000,
            livingRemaining: 158_000,
            fixedRows: [],
            categoryRows: [],
            allCategoryRows: [],
            rule: .standard,
            needsBudget: 125_000,
            wantsBudget: 75_000,
            savingsTarget: 50_000,
            needsSpent: 12_000,
            wantsSpent: 0,
            actualSpending: 12_000,
            plannedSpending: 200_000
        )
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: KakeiboSchema.all, configurations: configuration)
        let session = Session()
        retained.append(container)
        retained.append(session)
        let host = makeHost(
            HomeView(snapshot: snapshot, goals: [])
                .modelContainer(container)
                .environment(session)
        )
        let texts = host.view.allUILabels().compactMap(\.text)
        XCTAssertFalse(texts.contains("あと"), "ホームの大きい残り表示が残っています: \(texts)")
        XCTAssertFalse(
            host.view.allUILabels().contains { $0.font.pointSize >= 30 && ($0.text?.contains("円") == true) },
            "ホームに大きい金額表示が残っています"
        )
    }

    private func typeKeys(_ keys: [String], in host: UIViewController) {
        host.view.layoutIfNeeded()
        spin(0.15)
        guard let pad = host.view.findYenKeypad() else {
            XCTFail("数字パッドが見つかりません")
            return
        }
        for key in keys {
            guard pad.onKey != nil else {
                XCTFail("数字パッドの入力が繋がっていません")
                return
            }
            pad.onKey?(key)
            host.view.layoutIfNeeded()
            spin(0.03)
        }
    }

    private func assertNoReceiverData() {
        guard let store = try? OSLogStore(scope: .currentProcessIdentifier) else { return }
        let position = store.position(date: Date().addingTimeInterval(-4))
        let hits = ((try? store.getEntries(at: position)) ?? AnySequence([]))
            .map(\.composedMessage)
            .filter { $0.contains("ReceiverData") }
        XCTAssertTrue(hits.isEmpty, "入力中に SwiftUI TextField のログが出ました:\n\(hits.joined(separator: "\n"))")
    }

    private func makeBudgetEditorHost(startsWithKeypad: Bool = false) throws -> UIHostingController<AnyView> {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: KakeiboSchema.all, configurations: configuration)
        SeedData.ensure(in: container.mainContext)
        let session = Session()
        retained.append(container)
        retained.append(session)
        return makeHost(
            AnyView(
                NavigationStack {
                    BudgetEditorView(startsWithKeypad: startsWithKeypad)
                }
                .modelContainer(container)
                .environment(session)
                .hoverEffectDisabled(true)
            )
        )
    }

    @discardableResult
    private func makeHost<Content: View>(_ root: Content) -> UIHostingController<Content> {
        let host = UIHostingController(rootView: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        retained.append(window)
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()
        spin(0.15)
        return host
    }

    private func spin(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
}

private extension UIView {
    func findYenKeypad() -> YenKeypadView? {
        if let pad = self as? YenKeypadView { return pad }
        for subview in subviews {
            if let pad = subview.findYenKeypad() { return pad }
        }
        return nil
    }

    func findUIButton(labeled label: String) -> UIButton? {
        allUIButtons().first { $0.accessibilityLabel == label || $0.title(for: .normal) == label }
    }

    func findUITextField(labeled label: String) -> UITextField? {
        allUITextFields().first { $0.accessibilityLabel == label }
    }

    func findDigitsLabel(named name: String) -> UILabel? {
        allUILabels().first { $0.accessibilityLabel == name }
    }

    func showsYenDigits(_ digits: String) -> Bool {
        allUILabels().contains { $0.text == digits }
    }

    func allUIButtons() -> [UIButton] {
        var buttons: [UIButton] = []
        if let button = self as? UIButton { buttons.append(button) }
        for subview in subviews {
            buttons.append(contentsOf: subview.allUIButtons())
        }
        return buttons
    }

    func allUITextFields() -> [UITextField] {
        var fields: [UITextField] = []
        if let field = self as? UITextField { fields.append(field) }
        for subview in subviews {
            fields.append(contentsOf: subview.allUITextFields())
        }
        return fields
    }

    func allUILabels() -> [UILabel] {
        var labels: [UILabel] = []
        if let label = self as? UILabel { labels.append(label) }
        for subview in subviews {
            labels.append(contentsOf: subview.allUILabels())
        }
        return labels
    }
}
