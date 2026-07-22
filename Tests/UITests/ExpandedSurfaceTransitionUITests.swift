import XCTest

@MainActor
final class ExpandedSurfaceTransitionUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testDashboardToSettingsKeepsFullBodyVisible() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo"]
        app.launch()

        let settingsButton = app.buttons["Open settings"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 5),
            "The expanded dashboard did not expose its Settings button."
        )
        settingsButton.click()

        let expectedContent = [
            app.staticTexts["Settings"],
            app.staticTexts["Notifications"],
            app.staticTexts["Quiet mode"],
            app.staticTexts["Urgent alerts in Quiet Mode"],
            app.staticTexts["Privacy mode"],
            app.staticTexts["Completion feedback"],
            app.staticTexts["Completion effect"],
            app.staticTexts["While Codex is active"],
            app.staticTexts["Preview animation"],
            app.staticTexts["Source"],
        ]

        for element in expectedContent {
            XCTAssertTrue(
                element.waitForExistence(timeout: 2),
                "The Settings body is missing expected content."
            )
            XCTAssertFalse(
                element.frame.isEmpty,
                "Settings content has an empty accessibility frame."
            )
        }

        let panel = app.windows
            .containing(.staticText, identifier: "Settings")
            .firstMatch

        XCTAssertTrue(
            panel.waitForExistence(timeout: 2),
            "The Settings content is not attached to an app window."
        )

        for element in expectedContent {
            XCTAssertTrue(
                panel.frame.contains(element.frame),
                "Settings content is detached from or clipped outside its panel."
            )
        }
    }
}
