import AppShell
import CoreDomain
import XCTest

private actor MockPricingEventsStore: PricingEventsStore {
    private var insertedRows: [PricingEventInsertRow] = []

    func insert(row: PricingEventInsertRow) async throws {
        insertedRows.append(row)
    }

    func allRows() -> [PricingEventInsertRow] {
        insertedRows
    }
}

final class PricingTelemetrySinkTests: XCTestCase {
    func testInsertRowMapsTelemetryEventToSupabaseRow() throws {
        let userID = "9D6F77EC-8C6C-4313-B6FD-2816EE9EA0DF"
        let projectID = "29141D7D-B2D0-4AFA-9DDF-184D0D9D1B7A"
        let event = PricingTelemetryEvent(
            eventID: "evt-1",
            eventType: .paywallViewed,
            tier: .free,
            triggerEvent: .exportAdvancedFormat,
            reasonCode: "advanced_export_requires_plus",
            projectID: projectID,
            createdAtMs: 1_730_000_000_000
        )

        let row = try PricingEventInsertRow(event: event, userID: userID, appBuild: "1.0.0(1)")

        XCTAssertEqual(row.event_id, "evt-1")
        XCTAssertEqual(row.user_id.uuidString, userID)
        XCTAssertEqual(row.project_id?.uuidString, projectID)
        XCTAssertEqual(row.event_type, "paywall_viewed")
        XCTAssertEqual(row.tier, "free")
        XCTAssertEqual(row.trigger_event, "exportAdvancedFormat")
        XCTAssertEqual(row.reason_code, "advanced_export_requires_plus")
        XCTAssertEqual(row.payload["source"], "ios-appshell")
        XCTAssertEqual(row.payload["created_at_ms"], "1730000000000")
        XCTAssertEqual(row.payload["app_build"], "1.0.0(1)")
    }

    func testInsertRowThrowsWhenUserIDIsInvalidUUID() {
        let event = PricingTelemetryEvent(
            eventType: .upgradeClicked,
            tier: .free,
            triggerEvent: .createShareLink,
            reasonCode: "share_limit_reached"
        )

        XCTAssertThrowsError(
            try PricingEventInsertRow(event: event, userID: "user-1", appBuild: nil)
        ) { error in
            XCTAssertEqual(error as? PricingTelemetrySinkError, .invalidUserID("user-1"))
        }
    }

    func testSinkWritesRowThroughStore() async throws {
        let store = MockPricingEventsStore()
        let sink = SupabasePricingTelemetrySink(store: store, appBuild: "2026.03.02")
        let event = PricingTelemetryEvent(
            eventID: "evt-2",
            eventType: .upgradeClicked,
            tier: .free,
            triggerEvent: .createShareLink,
            reasonCode: "share_limit_reached",
            projectID: "not-a-uuid",
            createdAtMs: 1_730_000_010_000
        )
        let userID = "2D08657A-BC68-4902-9A5A-15A2ECDE357F"

        try await sink.track(event: event, userID: userID)

        let rows = await store.allRows()
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].event_id, "evt-2")
        XCTAssertEqual(rows[0].user_id.uuidString, userID)
        XCTAssertNil(rows[0].project_id)
        XCTAssertEqual(rows[0].payload["raw_project_id"], "not-a-uuid")
        XCTAssertEqual(rows[0].payload["app_build"], "2026.03.02")
    }
}
