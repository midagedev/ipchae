import CoreDomain
import Foundation
import Supabase

public enum PricingTelemetrySinkError: Error, LocalizedError, Equatable, Sendable {
    case invalidUserID(String)

    public var errorDescription: String? {
        switch self {
        case .invalidUserID(let rawID):
            return "Invalid user UUID: \(rawID)"
        }
    }
}

public struct PricingEventInsertRow: Encodable, Equatable, Sendable {
    public var event_id: String
    public var user_id: UUID
    public var event_type: String
    public var tier: String
    public var trigger_event: String
    public var reason_code: String
    public var project_id: UUID?
    public var payload: [String: String]

    public init(
        event_id: String,
        user_id: UUID,
        event_type: String,
        tier: String,
        trigger_event: String,
        reason_code: String,
        project_id: UUID?,
        payload: [String: String]
    ) {
        self.event_id = event_id
        self.user_id = user_id
        self.event_type = event_type
        self.tier = tier
        self.trigger_event = trigger_event
        self.reason_code = reason_code
        self.project_id = project_id
        self.payload = payload
    }

    public init(
        event: PricingTelemetryEvent,
        userID: String,
        appBuild: String?
    ) throws {
        guard let parsedUserID = UUID(uuidString: userID) else {
            throw PricingTelemetrySinkError.invalidUserID(userID)
        }

        let parsedProjectID = event.projectID.flatMap(UUID.init(uuidString:))
        var payload: [String: String] = [
            "source": "ios-appshell",
            "created_at_ms": String(event.createdAtMs),
        ]

        if let appBuild {
            payload["app_build"] = appBuild
        }

        if let rawProjectID = event.projectID, parsedProjectID == nil {
            payload["raw_project_id"] = rawProjectID
        }

        self.init(
            event_id: event.eventID,
            user_id: parsedUserID,
            event_type: event.eventType.rawValue,
            tier: event.tier.rawValue,
            trigger_event: event.triggerEvent.rawValue,
            reason_code: event.reasonCode,
            project_id: parsedProjectID,
            payload: payload
        )
    }
}

public protocol PricingEventsStore: Sendable {
    func insert(row: PricingEventInsertRow) async throws
}

public actor SupabasePricingEventsStore: PricingEventsStore {
    private let client: SupabaseClient
    private let tableName: String

    public init(environment: AppEnvironment, tableName: String = "pricing_events") {
        self.client = SupabaseClient(
            supabaseURL: environment.supabaseURL,
            supabaseKey: environment.supabaseAnonKey
        )
        self.tableName = tableName
    }

    public init(client: SupabaseClient, tableName: String = "pricing_events") {
        self.client = client
        self.tableName = tableName
    }

    public func insert(row: PricingEventInsertRow) async throws {
        _ = try await client
            .from(tableName)
            .insert(row)
            .execute()
    }
}

public protocol PricingTelemetrySinkProtocol: Sendable {
    func track(event: PricingTelemetryEvent, userID: String) async throws
}

public actor SupabasePricingTelemetrySink: PricingTelemetrySinkProtocol {
    private let store: any PricingEventsStore
    private let appBuild: String?

    public init(
        environment: AppEnvironment,
        tableName: String = "pricing_events",
        appBuild: String? = nil
    ) {
        self.store = SupabasePricingEventsStore(environment: environment, tableName: tableName)
        self.appBuild = appBuild
    }

    public init(store: any PricingEventsStore, appBuild: String? = nil) {
        self.store = store
        self.appBuild = appBuild
    }

    public func track(event: PricingTelemetryEvent, userID: String) async throws {
        let row = try PricingEventInsertRow(event: event, userID: userID, appBuild: appBuild)
        try await store.insert(row: row)
    }
}
