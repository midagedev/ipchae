import CoreDomain
import Foundation

@MainActor
public final class PricingGateViewModel: ObservableObject {
    @Published public private(set) var usage: UsageSnapshot
    @Published public private(set) var pendingEvent: PricingEvent?
    @Published public private(set) var pendingDecision: PricingDecision?
    @Published public var statusMessage: String = ""
    @Published public var showPaywall: Bool = false

    private let tier: PricingTier
    private let policy: PricingPolicyV1
    private let userID: String
    private let projectID: String?
    private let telemetrySink: (any PricingTelemetrySinkProtocol)?

    public init(
        userID: String,
        tier: PricingTier = .free,
        usage: UsageSnapshot = UsageSnapshot(
            monthlyShareLinks: 30,
            activeProjects: 1,
            cloudStorageBytes: 128 * 1024 * 1024,
            teamMembers: 1,
            requestedHistoryDays: 45
        ),
        policy: PricingPolicyV1 = .defaultPolicy(),
        projectID: String? = nil,
        telemetrySink: (any PricingTelemetrySinkProtocol)? = nil
    ) {
        self.userID = userID
        self.tier = tier
        self.usage = usage
        self.policy = policy
        self.projectID = projectID
        self.telemetrySink = telemetrySink
    }

    public func attemptAction(_ event: PricingEvent) async {
        pendingEvent = event
        let decision = policy.evaluate(tier: tier, event: event, usage: usage)
        pendingDecision = decision

        guard decision.allowed else {
            statusMessage = "Upgrade required: \(decision.reasonCode)"
            showPaywall = true
            await trackPaywallViewed(event: event, decision: decision)
            return
        }

        showPaywall = false
        applyUsageDelta(for: event)
        statusMessage = "Action allowed: \(event.rawValue)"
    }

    public func tapUpgrade() async {
        guard let pendingEvent, let pendingDecision else {
            return
        }

        statusMessage = "Upgrade intent tracked"

        guard let telemetrySink else {
            return
        }

        let event = PricingTelemetry.makeUpgradeClicked(
            tier: tier,
            triggerEvent: pendingEvent,
            reasonCode: pendingDecision.reasonCode,
            projectID: projectID
        )

        try? await telemetrySink.track(event: event, userID: userID)
    }

    public func dismissPaywall() {
        showPaywall = false
        statusMessage = "Paywall dismissed"
    }

    private func applyUsageDelta(for event: PricingEvent) {
        switch event {
        case .createShareLink:
            usage.monthlyShareLinks += 1
        default:
            break
        }
    }

    private func trackPaywallViewed(event: PricingEvent, decision: PricingDecision) async {
        guard let telemetrySink else {
            return
        }

        let telemetryEvent = PricingTelemetry.makePaywallViewed(
            tier: tier,
            triggerEvent: event,
            decision: decision,
            projectID: projectID
        )

        try? await telemetrySink.track(event: telemetryEvent, userID: userID)
    }
}
