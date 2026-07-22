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

        let expectedButtons = [
            app.buttons["Close settings"],
            app.buttons["settings.previewAnimation"],
            app.buttons["Refresh"],
        ]

        for element in expectedContent {
            XCTAssertTrue(
                element.waitForExistence(timeout: 2),
                "The Settings body is missing '\(element.label)'."
            )
            XCTAssertFalse(
                element.frame.isEmpty,
                "Settings content has an empty accessibility frame."
            )
        }

        for button in expectedButtons {
            XCTAssertTrue(
                button.waitForExistence(timeout: 2),
                "A Settings action is missing or inaccessible."
            )
            XCTAssertFalse(
                button.frame.isEmpty,
                "A Settings action has an empty accessibility frame."
            )
        }

        let panel = app.dialogs
            .containing(.staticText, identifier: "Settings")
            .firstMatch

        XCTAssertTrue(
            panel.waitForExistence(timeout: 2),
            "The Settings content is not attached to an app window."
        )

        for element in expectedContent {
            XCTAssertTrue(
                panel.frame.contains(element.frame),
                "Settings content '\(element.label)' at \(element.frame) is "
                    + "outside panel \(panel.frame)."
            )
        }

        for button in expectedButtons {
            XCTAssertTrue(
                panel.frame.contains(button.frame),
                "Settings action '\(button.label)' at \(button.frame) is "
                    + "outside panel \(panel.frame)."
            )
        }
    }
}
