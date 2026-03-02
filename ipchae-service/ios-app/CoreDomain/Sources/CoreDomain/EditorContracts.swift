import Foundation

public struct DraftExportDot: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var z: Double
    public var radius: Double
    public var depositAmount: Double
    public var colorHex: String

    public init(x: Double, y: Double, z: Double, radius: Double, depositAmount: Double, colorHex: String) {
        self.x = x
        self.y = y
        self.z = z
        self.radius = radius
        self.depositAmount = depositAmount
        self.colorHex = colorHex
    }
}

public struct DraftBounds: Codable, Sendable, Equatable {
    public var minX: Double
    public var minY: Double
    public var minZ: Double
    public var maxX: Double
    public var maxY: Double
    public var maxZ: Double

    public init(minX: Double, minY: Double, minZ: Double, maxX: Double, maxY: Double, maxZ: Double) {
        self.minX = minX
        self.minY = minY
        self.minZ = minZ
        self.maxX = maxX
        self.maxY = maxY
        self.maxZ = maxZ
    }
}

public struct DraftSummary: Codable, Sendable, Equatable {
    public var strokeCount: Int
    public var dotCount: Int
    public var averageRadius: Double
    public var averageDepositAmount: Double
    public var bounds: DraftBounds?
    public var dots: [DraftExportDot]

    public init(
        strokeCount: Int,
        dotCount: Int,
        averageRadius: Double,
        averageDepositAmount: Double,
        bounds: DraftBounds?,
        dots: [DraftExportDot]
    ) {
        self.strokeCount = strokeCount
        self.dotCount = dotCount
        self.averageRadius = averageRadius
        self.averageDepositAmount = averageDepositAmount
        self.bounds = bounds
        self.dots = dots
    }
}
