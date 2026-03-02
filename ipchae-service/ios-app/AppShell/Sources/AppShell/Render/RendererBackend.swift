import Foundation

public enum RendererBackend: String, Codable, Sendable, CaseIterable {
    case metalKit = "metal_kit"
    case realityKit = "reality_kit"
}

public struct RendererRecommendationContext: Sendable, Equatable {
    public var prefersLowLevelEditingControl: Bool
    public var needsImmersivePreview: Bool

    public init(
        prefersLowLevelEditingControl: Bool = true,
        needsImmersivePreview: Bool = false
    ) {
        self.prefersLowLevelEditingControl = prefersLowLevelEditingControl
        self.needsImmersivePreview = needsImmersivePreview
    }
}

public enum RendererRecommendationService {
    public static func recommend(_ context: RendererRecommendationContext) -> RendererBackend {
        if context.prefersLowLevelEditingControl {
            return .metalKit
        }

        if context.needsImmersivePreview {
            return .realityKit
        }

        return .metalKit
    }
}
