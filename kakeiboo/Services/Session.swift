import Foundation
import Observation

@Observable
final class Session {
    var period: PayPeriod = .containing()
    var rule: BudgetRule = .load() {
        didSet { rule.save() }
    }
}
