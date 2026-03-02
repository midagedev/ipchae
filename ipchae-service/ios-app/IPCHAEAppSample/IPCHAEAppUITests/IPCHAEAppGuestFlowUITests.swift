import XCTest

@MainActor
final class IPCHAEAppGuestFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGuestFirstSessionCanDrawAndReopenStudio() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting-reset-defaults"]
        app.launch()

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Studio should auto-open for first guest session")
        XCTAssertTrue(app.staticTexts["Project Local"].waitForExistence(timeout: 5))
        dismissExternalOpenAlertIfNeeded()

        let strokeCount = app.staticTexts["studio.strokeCountHeader"]
        XCTAssertTrue(strokeCount.waitForExistence(timeout: 5), "Stroke count indicator should be visible")
        XCTAssertEqual(strokeCount.label, "Strokes 0")

        let canvas = app.otherElements["studio.canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5), "Canvas should be visible")

        let pipHandle = app.staticTexts["Move"]
        XCTAssertTrue(pipHandle.waitForExistence(timeout: 5), "PIP move handle should be visible")
        let pipDragStart = pipHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        let pipDragEnd = pipHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.85))
        pipDragStart.press(forDuration: 0.05, thenDragTo: pipDragEnd)

        XCTAssertTrue(app.staticTexts["PIP"].exists, "PIP preview should remain visible after move")

        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.35))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.65))
        start.press(forDuration: 0.05, thenDragTo: end)
        dismissExternalOpenAlertIfNeeded()

        let updatedStrokeCount = NSPredicate(format: "label != %@", "Strokes 0")
        expectation(for: updatedStrokeCount, evaluatedWith: strokeCount)
        waitForExpectations(timeout: 5)

        doneButton.tap()
        XCTAssertTrue(app.staticTexts["IPCHAE Studio"].waitForExistence(timeout: 5))

        let startStudioButton = app.buttons["지금 바로 스튜디오 시작"]
        XCTAssertTrue(startStudioButton.waitForExistence(timeout: 5))
        startStudioButton.tap()

        XCTAssertTrue(doneButton.waitForExistence(timeout: 5), "Studio should reopen from home CTA")
    }

    private func dismissExternalOpenAlertIfNeeded() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: 1) else { return }

        let cancelButtons = ["취소", "Cancel"]
        for title in cancelButtons where alert.buttons[title].exists {
            alert.buttons[title].tap()
            return
        }
    }
}
