import CoreDomain
import XCTest

final class PricingPolicyTests: XCTestCase {
    func testFreeTierBlocksAdvancedExport() {
        let policy = PricingPolicyV1.defaultPolicy()
        let usage = UsageSnapshot(
            monthlyShareLinks: 0,
            activeProjects: 2,
            cloudStorageBytes: 100_000,
            teamMembers: 1,
            requestedHistoryDays: 10
        )

        let decision = policy.evaluate(tier: .free, event: .exportAdvancedFormat, usage: usage)

        XCTAssertFalse(decision.allowed)
        XCTAssertTrue(decision.needsUpgrade)
        XCTAssertEqual(decision.suggestedTier, .plus)
    }

    func testFreeTierBlocksShareOverLimit() {
        let policy = PricingPolicyV1.defaultPolicy()
        let usage = UsageSnapshot(
            monthlyShareLinks: 30,
            activeProjects: 2,
            cloudStorageBytes: 100_000,
            teamMembers: 1,
            requestedHistoryDays: 10
        )

        let decision = policy.evaluate(tier: .free, event: .createShareLink, usage: usage)

        XCTAssertFalse(decision.allowed)
        XCTAssertEqual(decision.reasonCode, "share_limit_reached")
    }

    func testTeamTierAllowsCollabInvite() {
        let policy = PricingPolicyV1.defaultPolicy()
        let usage = UsageSnapshot(
            monthlyShareLinks: 200,
            activeProjects: 80,
            cloudStorageBytes: 50_000_000,
            teamMembers: 10,
            requestedHistoryDays: 365
        )

        let decision = policy.evaluate(tier: .team, event: .inviteCollaborator, usage: usage)

        XCTAssertTrue(decision.allowed)
        XCTAssertFalse(decision.needsUpgrade)
    }
}
