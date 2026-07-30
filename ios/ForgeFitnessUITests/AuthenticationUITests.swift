import XCTest

final class AuthenticationUITests: XCTestCase {
    func testAuthenticationScreenHasAccessibleControls() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        XCTAssertTrue(app.staticTexts["Forge Fitness"].waitForExistence(
            timeout: 10
        ))
        XCTAssertTrue(app.textFields["Email"].exists)
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        XCTAssertTrue(app.buttons["Sign In"].exists)
        XCTAssertTrue(app.buttons["Create Account"].exists)
    }
}
