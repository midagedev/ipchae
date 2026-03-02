import CoreDomain
import XCTest

final class StudioContractsTests: XCTestCase {
    func testSnapshotEncodeDecodeRoundTrip() throws {
        let snapshot = StudioSnapshotV1(
            projectID: "project-123",
            mode: .freeDraw,
            starterTemplateID: "tmpl-1",
            starterProportion: StarterProportion(headRatio: 1.45, bodyRatio: 1.0, legRatio: 0.75),
            brushSize: 20,
            brushStrength: 0.28,
            brushColorHex: "#3b82f6",
            drawTool: .fill,
            mirrorDraw: true,
            smoothMeshView: true,
            autoFillClosedStroke: false,
            activeView: .front,
            inputMode: .draw,
            transformPivotMode: .selection,
            gridSnapEnabled: true,
            gridSnapStep: 0.12,
            angleSnapEnabled: true,
            angleSnapDegrees: 12,
            sliceEnabled: true,
            activeSliceLayerID: "slice-layer-1",
            sliceLayers: [
                SliceLayer(
                    id: "slice-layer-1",
                    name: "Z Layer 1",
                    axis: .z,
                    depth: 0,
                    visible: true,
                    locked: false,
                    colorHex: "#3b82f6"
                )
            ],
            updatedAt: 1_700_000_000_000
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(StudioSnapshotV1.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    func testRejectsUnsupportedSchemaVersion() throws {
        let json = """
        {
          "schemaVersion": 2,
          "projectId": "project-123",
          "mode": "blank",
          "brushSize": 20,
          "brushStrength": 0.28,
          "brushColorHex": "#3b82f6",
          "drawTool": "free-draw",
          "mirrorDraw": false,
          "smoothMeshView": true,
          "autoFillClosedStroke": false,
          "activeView": "front",
          "inputMode": "draw",
          "sliceEnabled": false,
          "activeSliceLayerId": "slice-layer-1",
          "sliceLayers": [],
          "updatedAt": 1700000000000
        }
        """

        XCTAssertThrowsError(try JSONDecoder().decode(StudioSnapshotV1.self, from: Data(json.utf8)))
    }
}
