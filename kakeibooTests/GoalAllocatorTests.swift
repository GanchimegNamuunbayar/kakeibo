import XCTest
@testable import kakeiboo

final class GoalAllocatorTests: XCTestCase {
    func testMonthsLeftIsAtLeastOne() {
        let period = PayPeriod.containing()
        XCTAssertEqual(GoalAllocator.monthsLeft(from: period, deadline: period.start), 1)
        XCTAssertEqual(GoalAllocator.monthsLeft(from: period, deadline: period.endInclusive), 1)
        XCTAssertEqual(GoalAllocator.monthsLeft(from: period, deadline: period.next.endInclusive), 2)
    }

    func testMonthlyNeedDividesRemaining() {
        let period = PayPeriod.containing()
        let plan = GoalPlan(
            id: UUID(),
            name: "旅行",
            remaining: 80_000,
            deadline: period.next.endInclusive,
            monthlyAmount: 0,
            isSurplusBucket: false
        )
        XCTAssertEqual(GoalAllocator.monthlyNeed(for: plan, period: period), 40_000)
    }

    func testProposalSplitsShortfallByNeed() {
        let period = PayPeriod.containing()
        let travel = GoalPlan(
            id: UUID(),
            name: "旅行",
            remaining: 80_000,
            deadline: period.next.endInclusive,
            monthlyAmount: 0,
            isSurplusBucket: false
        )
        let furniture = GoalPlan(
            id: UUID(),
            name: "家具",
            remaining: 120_000,
            deadline: period.next.next.next.next.next.endInclusive,
            monthlyAmount: 0,
            isSurplusBucket: false
        )
        let emergency = GoalPlan(
            id: UUID(),
            name: "緊急資金",
            remaining: 0,
            deadline: nil,
            monthlyAmount: 0,
            isSurplusBucket: true
        )

        let proposal = GoalAllocator.propose(
            actual: 40_000,
            plans: [travel, furniture, emergency],
            period: period
        )

        XCTAssertTrue(proposal.isShort)
        XCTAssertEqual(proposal.items.first { $0.id == travel.id }?.proposed, 26_667)
        XCTAssertEqual(proposal.items.first { $0.id == furniture.id }?.proposed, 13_333)
        XCTAssertEqual(proposal.items.first { $0.id == emergency.id }?.proposed, 0)
        XCTAssertEqual(proposal.proposedTotal, 40_000)
    }

    func testProposalSendsSurplusToEmergency() {
        let period = PayPeriod.containing()
        let travel = GoalPlan(
            id: UUID(),
            name: "旅行",
            remaining: 20_000,
            deadline: period.next.endInclusive,
            monthlyAmount: 0,
            isSurplusBucket: false
        )
        let emergency = GoalPlan(
            id: UUID(),
            name: "緊急資金",
            remaining: 0,
            deadline: nil,
            monthlyAmount: 0,
            isSurplusBucket: true
        )
        let proposal = GoalAllocator.propose(
            actual: 40_000,
            plans: [travel, emergency],
            period: period
        )
        XCTAssertFalse(proposal.isShort)
        XCTAssertEqual(proposal.items.first { $0.id == travel.id }?.proposed, 10_000)
        XCTAssertEqual(proposal.items.first { $0.id == emergency.id }?.proposed, 30_000)
    }
}
