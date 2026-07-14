import XCTest

/// UI tests run against an in-memory store (-UITestMode) with onboarding skipped.
final class ForgeUITests: XCTestCase {

    private func launchApp(sampleData: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = sampleData ? ["-UITestMode", "-UITestSampleData"] : ["-UITestMode"]
        app.launch()
        return app
    }

    func testLaunchShowsAllTabs() {
        let app = launchApp()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Train"].exists)
        XCTAssertTrue(app.tabBars.buttons["Progress"].exists)
        XCTAssertTrue(app.tabBars.buttons["Schedule"].exists)
        XCTAssertTrue(app.tabBars.buttons["More"].exists)
    }

    func testCreateExerciseFlow() {
        let app = launchApp()
        app.tabBars.buttons["Train"].tap()
        let libraryLink = app.buttons["train.module.library"]
        XCTAssertTrue(libraryLink.waitForExistence(timeout: 10))
        libraryLink.tap()
        XCTAssertTrue(app.buttons["library.newExercise"].waitForExistence(timeout: 10))
        app.buttons["library.newExercise"].tap()

        let nameField = app.textFields["exercise.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        // A name that sorts to the top of the alphabetical library list, so the
        // new row is materialized on-screen (List rows are lazy).
        nameField.typeText("AAA Test Curl")
        app.buttons["exercise.save"].tap()

        // The new exercise appears at the top of the library list.
        XCTAssertTrue(app.staticTexts["AAA Test Curl"].waitForExistence(timeout: 10))
    }

    func testStartAndFinishEmptyWorkout() {
        let app = launchApp()
        app.tabBars.buttons["Train"].tap()
        let startButton = app.buttons["train.startEmpty"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        // Live workout appears with a finish button.
        let finish = app.buttons["workout.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()

        let save = app.buttons["workout.saveFinish"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        // Back on the Train tab with no active session.
        XCTAssertTrue(app.buttons["train.startEmpty"].waitForExistence(timeout: 5))
    }

    func testStartWorkoutFromTemplateAndCompleteSet() {
        let app = launchApp()
        app.tabBars.buttons["Train"].tap()
        // Seeded "Upper Body" template card has a Start pill.
        let start = app.buttons["Start"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let completeSet = app.buttons["workout.completeSet"].firstMatch
        XCTAssertTrue(completeSet.waitForExistence(timeout: 5))
        completeSet.tap()

        app.buttons["workout.finish"].tap()
        let save = app.buttons["workout.saveFinish"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
    }

    func testLogRunManually() {
        let app = launchApp()
        app.tabBars.buttons["Train"].tap()
        let runningLink = app.buttons["train.module.running"]
        XCTAssertTrue(runningLink.waitForExistence(timeout: 10))
        runningLink.tap()

        let newRun = app.buttons["running.newRun"]
        if newRun.waitForExistence(timeout: 5) {
            newRun.tap()
        } else {
            app.buttons["Log a Run"].tap()
        }

        let distance = app.textFields["run.distance"]
        XCTAssertTrue(distance.waitForExistence(timeout: 5))
        distance.tap()
        distance.typeText("5")
        let minuteField = app.textFields["Duration.m"]
        if minuteField.waitForExistence(timeout: 3) {
            minuteField.tap()
            minuteField.typeText("25")
        }
        let save = app.buttons["run.save"]
        if save.isEnabled {
            save.tap()
            XCTAssertTrue(app.navigationBars["Running"].waitForExistence(timeout: 5))
        }
    }

    func testBodyMeasurementEntry() {
        let app = launchApp()
        app.tabBars.buttons["Progress"].tap()
        let bodyLink = app.buttons["progress.body"]
        XCTAssertTrue(bodyLink.waitForExistence(timeout: 10))
        bodyLink.tap()

        let add = app.buttons["body.addEntry"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()

        let value = app.textFields["body.value"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        value.tap()
        value.typeText("78.5")
        app.buttons["body.save"].tap()

        XCTAssertTrue(app.staticTexts["78.5 kg"].waitForExistence(timeout: 5))
    }

    func testScheduleTabShowsWeek() {
        let app = launchApp()
        app.tabBars.buttons["Schedule"].tap()
        XCTAssertTrue(app.staticTexts["This Week"].waitForExistence(timeout: 5))
    }

    func testSettingsNavigation() {
        let app = launchApp()
        app.tabBars.buttons["More"].tap()
        XCTAssertTrue(app.staticTexts["Units & Defaults"].waitForExistence(timeout: 5))
        app.staticTexts["Units & Defaults"].tap()
        XCTAssertTrue(app.navigationBars["Units & Defaults"].waitForExistence(timeout: 5))
    }
}
