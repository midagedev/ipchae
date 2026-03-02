import Foundation

public enum PricingTier: String, Codable, Sendable {
    case free
    case plus
    case team
}

public enum PricingEvent: String, Codable, Sendable {
    case createShareLink
    case exportAdvancedFormat
    case inviteCollaborator
    case restoreOldVersion
}

public struct UsageSnapshot: Codable, Sendable, Equatable {
    public var monthlyShareLinks: Int
    public var activeProjects: Int
    public var cloudStorageBytes: Int64
    public var teamMembers: Int
    public var requestedHistoryDays: Int

    public init(
        monthlyShareLinks: Int,
        activeProjects: Int,
        cloudStorageBytes: Int64,
        teamMembers: Int,
        requestedHistoryDays: Int
    ) {
        self.monthlyShareLinks = monthlyShareLinks
        self.activeProjects = activeProjects
        self.cloudStorageBytes = cloudStorageBytes
        self.teamMembers = teamMembers
        self.requestedHistoryDays = requestedHistoryDays
    }
}

public struct PricingPolicyLimits: Codable, Sendable, Equatable {
    public var maxMonthlyShareLinks: Int?
    public var maxCloudStorageBytes: Int64?
    public var maxHistoryDays: Int?
    public var allowAdvancedExport: Bool
    public var allowCollabInvite: Bool

    public init(
        maxMonthlyShareLinks: Int?,
        maxCloudStorageBytes: Int64?,
        maxHistoryDays: Int?,
        allowAdvancedExport: Bool,
        allowCollabInvite: Bool
    ) {
        self.maxMonthlyShareLinks = maxMonthlyShareLinks
        self.maxCloudStorageBytes = maxCloudStorageBytes
        self.maxHistoryDays = maxHistoryDays
        self.allowAdvancedExport = allowAdvancedExport
        self.allowCollabInvite = allowCollabInvite
    }
}

public struct PricingDecision: Sendable, Equatable {
    public var allowed: Bool
    public var needsUpgrade: Bool
    public var reasonCode: String
    public var suggestedTier: PricingTier?

    public init(allowed: Bool, needsUpgrade: Bool, reasonCode: String, suggestedTier: PricingTier?) {
        self.allowed = allowed
        self.needsUpgrade = needsUpgrade
        self.reasonCode = reasonCode
        self.suggestedTier = suggestedTier
    }
}

public struct PricingPolicyV1: Sendable {
    public let freeLimits: PricingPolicyLimits
    public let plusLimits: PricingPolicyLimits
    public let teamLimits: PricingPolicyLimits

    public init(
        freeLimits: PricingPolicyLimits,
        plusLimits: PricingPolicyLimits,
        teamLimits: PricingPolicyLimits
    ) {
        self.freeLimits = freeLimits
        self.plusLimits = plusLimits
        self.teamLimits = teamLimits
    }

    public static func defaultPolicy() -> PricingPolicyV1 {
        PricingPolicyV1(
            freeLimits: PricingPolicyLimits(
                maxMonthlyShareLinks: 30,
                maxCloudStorageBytes: 2 * 1024 * 1024 * 1024,
                maxHistoryDays: 30,
                allowAdvancedExport: false,
                allowCollabInvite: false
            ),
            plusLimits: PricingPolicyLimits(
                maxMonthlyShareLinks: nil,
                maxCloudStorageBytes: 100 * 1024 * 1024 * 1024,
                maxHistoryDays: 180,
                allowAdvancedExport: true,
                allowCollabInvite: false
            ),
            teamLimits: PricingPolicyLimits(
                maxMonthlyShareLinks: nil,
                maxCloudStorageBytes: nil,
                maxHistoryDays: nil,
                allowAdvancedExport: true,
                allowCollabInvite: true
            )
        )
    }

    public func evaluate(
        tier: PricingTier,
        event: PricingEvent,
        usage: UsageSnapshot
    ) -> PricingDecision {
        let limits = limitsForTier(tier)

        switch event {
        case .createShareLink:
            if let maxShare = limits.maxMonthlyShareLinks, usage.monthlyShareLinks >= maxShare {
                return PricingDecision(
                    allowed: false,
                    needsUpgrade: true,
                    reasonCode: "share_limit_reached",
                    suggestedTier: tier == .free ? .plus : .team
                )
            }
            return PricingDecision(allowed: true, needsUpgrade: false, reasonCode: "ok", suggestedTier: nil)

        case .exportAdvancedFormat:
            guard limits.allowAdvancedExport else {
                return PricingDecision(
                    allowed: false,
                    needsUpgrade: true,
                    reasonCode: "advanced_export_requires_plus",
                    suggestedTier: .plus
                )
            }
            return PricingDecision(allowed: true, needsUpgrade: false, reasonCode: "ok", suggestedTier: nil)

        case .inviteCollaborator:
            guard limits.allowCollabInvite else {
                return PricingDecision(
                    allowed: false,
                    needsUpgrade: true,
                    reasonCode: "collab_requires_team",
                    suggestedTier: .team
                )
            }
            return PricingDecision(allowed: true, needsUpgrade: false, reasonCode: "ok", suggestedTier: nil)

        case .restoreOldVersion:
            if let maxHistory = limits.maxHistoryDays, usage.requestedHistoryDays > maxHistory {
                return PricingDecision(
                    allowed: false,
                    needsUpgrade: true,
                    reasonCode: "history_window_exceeded",
                    suggestedTier: tier == .free ? .plus : .team
                )
            }
            return PricingDecision(allowed: true, needsUpgrade: false, reasonCode: "ok", suggestedTier: nil)
        }
    }

    private func limitsForTier(_ tier: PricingTier) -> PricingPolicyLimits {
        switch tier {
        case .free:
            freeLimits
        case .plus:
            plusLimits
        case .team:
            teamLimits
        }
    }
}
