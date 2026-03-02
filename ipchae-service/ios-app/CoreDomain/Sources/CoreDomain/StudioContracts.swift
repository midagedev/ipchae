import Foundation

public enum SnapshotDecodeError: Error {
    case unsupportedSchemaVersion(Int)
}

public enum StartMode: String, Codable, Sendable {
    case blank = "blank"
    case freeDraw = "free-draw"
    case starter = "starter"
}

public enum DrawTool: String, Codable, Sendable {
    case freeDraw = "free-draw"
    case fill = "fill"
    case erase = "erase"
}

public enum ViewID: String, Codable, Sendable {
    case front = "front"
    case right = "right"
    case top = "top"
    case left = "left"
    case back = "back"
}

public enum InputMode: String, Codable, Sendable {
    case draw = "draw"
    case pan = "pan"
}

public enum SliceAxis: String, Codable, Sendable {
    case x = "x"
    case y = "y"
    case z = "z"
}

public enum PivotMode: String, Codable, Sendable {
    case object = "object"
    case selection = "selection"
    case world = "world"
}

public struct SliceLayer: Codable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var axis: SliceAxis
    public var depth: Double
    public var visible: Bool
    public var locked: Bool
    public var colorHex: String

    public init(
        id: String,
        name: String,
        axis: SliceAxis,
        depth: Double,
        visible: Bool,
        locked: Bool,
        colorHex: String
    ) {
        self.id = id
        self.name = name
        self.axis = axis
        self.depth = depth
        self.visible = visible
        self.locked = locked
        self.colorHex = colorHex
    }
}

public struct StarterProportion: Codable, Sendable, Equatable {
    public var headRatio: Double
    public var bodyRatio: Double
    public var legRatio: Double

    public init(headRatio: Double, bodyRatio: Double, legRatio: Double) {
        self.headRatio = headRatio
        self.bodyRatio = bodyRatio
        self.legRatio = legRatio
    }
}

public struct StudioSnapshotV1: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public var projectID: String
    public var mode: StartMode
    public var starterTemplateID: String?
    public var starterProportion: StarterProportion?
    public var brushSize: Double
    public var brushStrength: Double
    public var brushColorHex: String
    public var drawTool: DrawTool
    public var mirrorDraw: Bool
    public var smoothMeshView: Bool
    public var autoFillClosedStroke: Bool
    public var activeView: ViewID
    public var inputMode: InputMode
    public var transformPivotMode: PivotMode?
    public var gridSnapEnabled: Bool?
    public var gridSnapStep: Double?
    public var angleSnapEnabled: Bool?
    public var angleSnapDegrees: Double?
    public var sliceEnabled: Bool
    public var activeSliceLayerID: String
    public var sliceLayers: [SliceLayer]
    public var updatedAt: Int64

    public init(
        schemaVersion: Int = 1,
        projectID: String,
        mode: StartMode,
        starterTemplateID: String? = nil,
        starterProportion: StarterProportion? = nil,
        brushSize: Double,
        brushStrength: Double,
        brushColorHex: String,
        drawTool: DrawTool,
        mirrorDraw: Bool,
        smoothMeshView: Bool,
        autoFillClosedStroke: Bool,
        activeView: ViewID,
        inputMode: InputMode,
        transformPivotMode: PivotMode? = nil,
        gridSnapEnabled: Bool? = nil,
        gridSnapStep: Double? = nil,
        angleSnapEnabled: Bool? = nil,
        angleSnapDegrees: Double? = nil,
        sliceEnabled: Bool,
        activeSliceLayerID: String,
        sliceLayers: [SliceLayer],
        updatedAt: Int64
    ) {
        self.schemaVersion = schemaVersion
        self.projectID = projectID
        self.mode = mode
        self.starterTemplateID = starterTemplateID
        self.starterProportion = starterProportion
        self.brushSize = brushSize
        self.brushStrength = brushStrength
        self.brushColorHex = brushColorHex
        self.drawTool = drawTool
        self.mirrorDraw = mirrorDraw
        self.smoothMeshView = smoothMeshView
        self.autoFillClosedStroke = autoFillClosedStroke
        self.activeView = activeView
        self.inputMode = inputMode
        self.transformPivotMode = transformPivotMode
        self.gridSnapEnabled = gridSnapEnabled
        self.gridSnapStep = gridSnapStep
        self.angleSnapEnabled = angleSnapEnabled
        self.angleSnapDegrees = angleSnapDegrees
        self.sliceEnabled = sliceEnabled
        self.activeSliceLayerID = activeSliceLayerID
        self.sliceLayers = sliceLayers
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case projectID = "projectId"
        case mode
        case starterTemplateID = "starterTemplateId"
        case starterProportion
        case brushSize
        case brushStrength
        case brushColorHex
        case drawTool
        case mirrorDraw
        case smoothMeshView
        case autoFillClosedStroke
        case activeView
        case inputMode
        case transformPivotMode
        case gridSnapEnabled
        case gridSnapStep
        case angleSnapEnabled
        case angleSnapDegrees
        case sliceEnabled
        case activeSliceLayerID = "activeSliceLayerId"
        case sliceLayers
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == 1 else {
            throw SnapshotDecodeError.unsupportedSchemaVersion(version)
        }

        schemaVersion = version
        projectID = try container.decode(String.self, forKey: .projectID)
        mode = try container.decode(StartMode.self, forKey: .mode)
        starterTemplateID = try container.decodeIfPresent(String.self, forKey: .starterTemplateID)
        starterProportion = try container.decodeIfPresent(StarterProportion.self, forKey: .starterProportion)
        brushSize = try container.decode(Double.self, forKey: .brushSize)
        brushStrength = try container.decode(Double.self, forKey: .brushStrength)
        brushColorHex = try container.decode(String.self, forKey: .brushColorHex)
        drawTool = try container.decode(DrawTool.self, forKey: .drawTool)
        mirrorDraw = try container.decode(Bool.self, forKey: .mirrorDraw)
        smoothMeshView = try container.decode(Bool.self, forKey: .smoothMeshView)
        autoFillClosedStroke = try container.decode(Bool.self, forKey: .autoFillClosedStroke)
        activeView = try container.decode(ViewID.self, forKey: .activeView)
        inputMode = try container.decode(InputMode.self, forKey: .inputMode)
        transformPivotMode = try container.decodeIfPresent(PivotMode.self, forKey: .transformPivotMode)
        gridSnapEnabled = try container.decodeIfPresent(Bool.self, forKey: .gridSnapEnabled)
        gridSnapStep = try container.decodeIfPresent(Double.self, forKey: .gridSnapStep)
        angleSnapEnabled = try container.decodeIfPresent(Bool.self, forKey: .angleSnapEnabled)
        angleSnapDegrees = try container.decodeIfPresent(Double.self, forKey: .angleSnapDegrees)
        sliceEnabled = try container.decode(Bool.self, forKey: .sliceEnabled)
        activeSliceLayerID = try container.decode(String.self, forKey: .activeSliceLayerID)
        sliceLayers = try container.decode([SliceLayer].self, forKey: .sliceLayers)
        updatedAt = try container.decode(Int64.self, forKey: .updatedAt)
    }
}
