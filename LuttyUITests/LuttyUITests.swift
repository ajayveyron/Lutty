import XCTest

final class LuttyUITests: XCTestCase {
    @MainActor
    func testHomeAndLibraryNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Choose Photo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["LUT Library"].exists)

        app.staticTexts["LUT Library"].tap()
        XCTAssertTrue(app.navigationBars["LUT Library"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Import LUT"].exists)
    }
}
