import CoreDomain
import XCTest

final class ValidationServiceTests: XCTestCase {
    private func makeSummary(overrides: (inout DraftSummary) -> Void = { _ in }) -> DraftSummary {
        var summary = DraftSummary(
            strokeCount: 1,
            dotCount: 24,
            averageRadius: 0.12,
            averageDepositAmount: 0.08,
            bounds: DraftBounds(minX: -1, minY: -1, minZ: -1, maxX: 1, maxY: 1, maxZ: 1),
            dots: []
        )
        overrides(&summary)
        return summary
    }

    func testBlocksExportForEmptyMesh() {
        let report = ValidationService.validateDraftSummary(makeSummary { $0.dotCount = 0 })
        XCTAssertFalse(report.exportAllowed)
        XCTAssertTrue(report.errors.contains(where: { $0.code == .emptyMesh }))
    }

    func testAllowsExportForStableSummary() {
        let report = ValidationService.validateDraftSummary(makeSummary())
        XCTAssertTrue(report.exportAllowed)
        XCTAssertTrue(report.errors.isEmpty)
    }
}
