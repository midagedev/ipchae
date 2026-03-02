import AppShell
import CoreDomain
import XCTest

private actor MockPricingTelemetrySink: PricingTelemetrySinkProtocol {
    private var events: [PricingTelemetryEvent] = []
    private var userIDs: [String] = []

    func track(event: PricingTelemetryEvent, userID: String) async throws {
        events.append(event)
        userIDs.append(userID)
    }

    func recordedEvents() -> [PricingTelemetryEvent] {
        events
    }

    func recordedUserIDs() -> [String] {
        userIDs
    }
}

@MainActor
final class PricingGateViewModelTests: XCTestCase {
    private let validUserID = "2D08657A-BC68-4902-9A5A-15A2ECDE357F"

    func testBlockedActionShowsPaywallAndTracksPaywallViewed() async {
        let sink = MockPricingTelemetrySink()
        let viewModel = PricingGateViewModel(userID: validUserID, telemetrySink: sink)

        await viewModel.attemptAction(.exportAdvancedFormat)

        XCTAssertTrue(viewModel.showPaywall)
        XCTAssertEqual(viewModel.pendingDecision?.reasonCode, "advanced_export_requires_plus")

        let events = await sink.recordedEvents()
        let userIDs = await sink.recordedUserIDs()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.eventType, .paywallViewed)
        XCTAssertEqual(events.first?.triggerEvent, .exportAdvancedFormat)
        XCTAssertEqual(userIDs.first, validUserID)
    }

    func testAllowedActionDoesNotShowPaywall() async {
        let sink = MockPricingTelemetrySink()
        let usage = UsageSnapshot(
            monthlyShareLinks: 29,
            activeProjects: 1,
            cloudStorageBytes: 128 * 1024 * 1024,
            teamMembers: 1,
            requestedHistoryDays: 10
        )
        let viewModel = PricingGateViewModel(userID: validUserID, usage: usage, telemetrySink: sink)

        await viewModel.attemptAction(.createShareLink)

        XCTAssertFalse(viewModel.showPaywall)
        XCTAssertEqual(viewModel.usage.monthlyShareLinks, 30)
        XCTAssertTrue(viewModel.statusMessage.contains("allowed"))
        let events = await sink.recordedEvents()
        XCTAssertEqual(events.count, 0)
    }

    func testUpgradeTapTracksUpgradeClickedEvent() async {
        let sink = MockPricingTelemetrySink()
        let viewModel = PricingGateViewModel(userID: validUserID, telemetrySink: sink)

        await viewModel.attemptAction(.createShareLink)
        await viewModel.tapUpgrade()

        let events = await sink.recordedEvents()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].eventType, .paywallViewed)
        XCTAssertEqual(events[1].eventType, .upgradeClicked)
        XCTAssertEqual(events[1].reasonCode, "share_limit_reached")
    }
}
