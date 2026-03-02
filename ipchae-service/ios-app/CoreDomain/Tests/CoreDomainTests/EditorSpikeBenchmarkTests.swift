import CoreDomain
import XCTest

final class EditorSpikeBenchmarkTests: XCTestCase {
    func testBenchmarkReturnsPositiveThroughput() {
        let result = EditorSpikeBenchmark.run(
            config: EditorSpikeConfig(strokeCount: 20, pointsPerStroke: 50, undoRatio: 0.2)
        )

        XCTAssertEqual(result.totalPointsBuilt, 1_000)
        XCTAssertTrue(result.totalPointsRemaining > 0)
        XCTAssertTrue(result.buildPointsPerSec > 0)
        XCTAssertTrue(result.buildDurationMs >= 0)
        XCTAssertTrue(result.undoDurationMs >= 0)
    }
}
