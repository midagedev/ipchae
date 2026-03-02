import CoreDomain
import XCTest

final class PricingTelemetryTests: XCTestCase {
    func testMakePaywallViewedUsesDecisionReason() {
        let decision = PricingDecision(
            allowed: false,
            needsUpgrade: true,
            reasonCode: "advanced_export_requires_plus",
            suggestedTier: .plus
        )

        let event = PricingTelemetry.makePaywallViewed(
            tier: .free,
            triggerEvent: .exportAdvancedFormat,
            decision: decision,
            projectID: "project-1"
        )

        XCTAssertEqual(event.eventType, .paywallViewed)
        XCTAssertEqual(event.reasonCode, "advanced_export_requires_plus")
        XCTAssertEqual(event.tier, .free)
        XCTAssertEqual(event.triggerEvent, .exportAdvancedFormat)
        XCTAssertEqual(event.projectID, "project-1")
    }

    func testTelemetryEventCanEncodeDecode() throws {
        let event = PricingTelemetryEvent(
            eventID: "evt-1",
            eventType: .upgradeClicked,
            tier: .free,
            triggerEvent: .createShareLink,
            reasonCode: "share_limit_reached",
            projectID: nil,
            createdAtMs: 1_700_000_000_000
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(PricingTelemetryEvent.self, from: data)

        XCTAssertEqual(decoded, event)
    }
}
