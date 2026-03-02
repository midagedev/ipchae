import Foundation

public struct EditorSpikeConfig: Sendable {
    public var strokeCount: Int
    public var pointsPerStroke: Int
    public var undoRatio: Double

    public init(strokeCount: Int = 120, pointsPerStroke: Int = 120, undoRatio: Double = 0.2) {
        self.strokeCount = max(1, strokeCount)
        self.pointsPerStroke = max(1, pointsPerStroke)
        self.undoRatio = min(max(undoRatio, 0), 0.95)
    }
}

public struct EditorSpikeResult: Sendable {
    public var strokeCount: Int
    public var pointsPerStroke: Int
    public var totalPointsBuilt: Int
    public var totalPointsRemaining: Int
    public var buildDurationMs: Double
    public var undoDurationMs: Double
    public var buildPointsPerSec: Double
    public var validationAllowed: Bool

    public init(
        strokeCount: Int,
        pointsPerStroke: Int,
        totalPointsBuilt: Int,
        totalPointsRemaining: Int,
        buildDurationMs: Double,
        undoDurationMs: Double,
        buildPointsPerSec: Double,
        validationAllowed: Bool
    ) {
        self.strokeCount = strokeCount
        self.pointsPerStroke = pointsPerStroke
        self.totalPointsBuilt = totalPointsBuilt
        self.totalPointsRemaining = totalPointsRemaining
        self.buildDurationMs = buildDurationMs
        self.undoDurationMs = undoDurationMs
        self.buildPointsPerSec = buildPointsPerSec
        self.validationAllowed = validationAllowed
    }
}

public enum EditorSpikeBenchmark {
    public static func run(config: EditorSpikeConfig) -> EditorSpikeResult {
        var strokes: [[DraftExportDot]] = []
        strokes.reserveCapacity(config.strokeCount)

        let buildStart = DispatchTime.now().uptimeNanoseconds

        for strokeIndex in 0..<config.strokeCount {
            var stroke: [DraftExportDot] = []
            stroke.reserveCapacity(config.pointsPerStroke)
            for pointIndex in 0..<config.pointsPerStroke {
                stroke.append(
                    DraftExportDot(
                        x: Double(pointIndex) * 0.01,
                        y: Double(strokeIndex) * 0.01,
                        z: sin(Double(pointIndex) * 0.03),
                        radius: 0.08,
                        depositAmount: 0.15,
                        colorHex: "#3b82f6"
                    )
                )
            }
            strokes.append(stroke)
        }

        let buildEnd = DispatchTime.now().uptimeNanoseconds

        let undoStart = DispatchTime.now().uptimeNanoseconds
        let undoCount = Int(Double(config.strokeCount) * config.undoRatio)
        for _ in 0..<undoCount where !strokes.isEmpty {
            _ = strokes.removeLast()
        }
        let undoEnd = DispatchTime.now().uptimeNanoseconds

        let dots = strokes.flatMap { $0 }
        let dotCount = dots.count
        let totalRadius = dots.reduce(0.0) { $0 + $1.radius }
        let totalDeposit = dots.reduce(0.0) { $0 + $1.depositAmount }

        let summary = DraftSummary(
            strokeCount: strokes.count,
            dotCount: dotCount,
            averageRadius: dotCount > 0 ? totalRadius / Double(dotCount) : 0,
            averageDepositAmount: dotCount > 0 ? totalDeposit / Double(dotCount) : 0,
            bounds: dotCount > 0 ? DraftBounds(minX: 0, minY: 0, minZ: -1, maxX: 3, maxY: 3, maxZ: 1) : nil,
            dots: dots
        )

        let report = ValidationService.validateDraftSummary(summary)

        let buildDurationMs = Double(buildEnd - buildStart) / 1_000_000
        let undoDurationMs = Double(undoEnd - undoStart) / 1_000_000
        let buildPointsPerSec = buildDurationMs > 0
            ? Double(config.strokeCount * config.pointsPerStroke) / (buildDurationMs / 1_000)
            : 0

        return EditorSpikeResult(
            strokeCount: config.strokeCount,
            pointsPerStroke: config.pointsPerStroke,
            totalPointsBuilt: config.strokeCount * config.pointsPerStroke,
            totalPointsRemaining: dotCount,
            buildDurationMs: buildDurationMs,
            undoDurationMs: undoDurationMs,
            buildPointsPerSec: buildPointsPerSec,
            validationAllowed: report.exportAllowed
        )
    }
}
