import Foundation

public enum PricingTelemetryEventType: String, Codable, Sendable {
    case paywallViewed = "paywall_viewed"
    case paywallDismissed = "paywall_dismissed"
    case upgradeClicked = "upgrade_clicked"
    case trialStarted = "trial_started"
    case upgradeCompleted = "upgrade_completed"
}

public struct PricingTelemetryEvent: Codable, Sendable, Equatable {
    public var eventID: String
    public var eventType: PricingTelemetryEventType
    public var tier: PricingTier
    public var triggerEvent: PricingEvent
    public var reasonCode: String
    public var projectID: String?
    public var createdAtMs: Int64

    public init(
        eventID: String = UUID().uuidString,
        eventType: PricingTelemetryEventType,
        tier: PricingTier,
        triggerEvent: PricingEvent,
        reasonCode: String,
        projectID: String? = nil,
        createdAtMs: Int64 = Int64(Date().timeIntervalSince1970 * 1_000)
    ) {
        self.eventID = eventID
        self.eventType = eventType
        self.tier = tier
        self.triggerEvent = triggerEvent
        self.reasonCode = reasonCode
        self.projectID = projectID
        self.createdAtMs = createdAtMs
    }
}

public enum PricingTelemetry {
    public static func makePaywallViewed(
        tier: PricingTier,
        triggerEvent: PricingEvent,
        decision: PricingDecision,
        projectID: String? = nil
    ) -> PricingTelemetryEvent {
        PricingTelemetryEvent(
            eventType: .paywallViewed,
            tier: tier,
            triggerEvent: triggerEvent,
            reasonCode: decision.reasonCode,
            projectID: projectID
        )
    }

    public static func makeUpgradeClicked(
        tier: PricingTier,
        triggerEvent: PricingEvent,
        reasonCode: String,
        projectID: String? = nil
    ) -> PricingTelemetryEvent {
        PricingTelemetryEvent(
            eventType: .upgradeClicked,
            tier: tier,
            triggerEvent: triggerEvent,
            reasonCode: reasonCode,
            projectID: projectID
        )
    }
}
