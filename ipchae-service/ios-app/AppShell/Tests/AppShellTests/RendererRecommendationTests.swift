import AppShell
import XCTest

final class RendererRecommendationTests: XCTestCase {
    func testPrefersMetalKitWhenLowLevelControlNeeded() {
        let context = RendererRecommendationContext(
            prefersLowLevelEditingControl: true,
            needsImmersivePreview: true
        )

        XCTAssertEqual(RendererRecommendationService.recommend(context), .metalKit)
    }

    func testFallsBackToRealityKitForImmersivePreviewOnly() {
        let context = RendererRecommendationContext(
            prefersLowLevelEditingControl: false,
            needsImmersivePreview: true
        )

        XCTAssertEqual(RendererRecommendationService.recommend(context), .realityKit)
    }
}
