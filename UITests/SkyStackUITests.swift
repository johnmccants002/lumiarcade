import XCTest

final class SkyStackUITests: XCTestCase {
    @MainActor
    func testLaunchPerformance() {
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTApplicationLaunchMetric()], options: options) { XCUIApplication().launch() }
    }

    @MainActor
    func testArcadotInitialsSaveReloadIsolationAndRestart() {
        let app = XCUIApplication()
        let id = "TEST" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let url = "https://play.lumiarcade.com/g/sky-stack/" + id
        app.launchArguments = ["-LumiArcadeInvocationURL", url, "-SkyStackGameOverPreview"]
        app.launch()
        XCTAssertTrue(app.buttons["saveScore"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["finalScore"].label, "4")
        XCTAssertEqual(app.staticTexts["arcadotIdentity"].label, "ARCADOT #" + id)
        XCTAssertEqual(app.keyboards.count, 0)
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let starting = (0..<3).map { app.staticTexts["initial\($0)"].value as? String ?? "" }.joined()
        XCTAssertEqual(starting.count, 3)
        var expected = Array(starting)
        if expected.count == 3,
           let first = alphabet.firstIndex(of: expected[0]),
           let last = alphabet.firstIndex(of: expected[2]) {
            expected[0] = alphabet[(first + 2) % 36]
            expected[2] = alphabet[(last + 35) % 36]
        }
        let expectedRow = "Rank 1, \(String(expected)), 4 points"
        app.buttons["initialUp0"].tap()
        app.buttons["initialUp0"].tap()
        app.buttons["initialDown2"].tap()
        let entry = XCTAttachment(screenshot: app.screenshot())
        entry.name = "Arcade initials"
        entry.lifetime = .keepAlways
        add(entry)
        app.buttons["saveScore"].tap()
        XCTAssertTrue(app.buttons["playAgain"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.otherElements["leaderboardRow0"].label, expectedRow)
        let board = XCTAttachment(screenshot: app.screenshot())
        board.name = "Arcadot leaderboard"
        board.lifetime = .keepAlways
        add(board)
        app.buttons["playAgain"].tap()
        XCTAssertTrue(app.staticTexts["TAP TO STACK"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["liveScore"].label, "0")
        app.terminate()
        app.launchArguments = ["-LumiArcadeInvocationURL", url, "-SkyStackPreviewScore", "0"]
        app.launch()
        XCTAssertTrue(app.buttons["playAgain"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.otherElements["leaderboardRow0"].label, expectedRow)
        XCTAssertFalse(app.buttons["saveScore"].exists)
        app.terminate()
        app.launchArguments = ["-LumiArcadeInvocationURL", url + "B", "-SkyStackPreviewScore", "0"]
        app.launch()
        XCTAssertTrue(app.buttons["playAgain"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["leaderboardRow0"].exists)
    }

    @MainActor
    func testFiveRowsFitCompactResults() {
        let app = XCUIApplication()
        let id = "TABLE" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let url = "https://play.lumiarcade.com/g/sky-stack/" + id
        for score in [10, 20, 30, 40, 50] {
            app.launchArguments = ["-LumiArcadeInvocationURL", url, "-SkyStackPreviewScore", "\(score)"]
            app.launch()
            XCTAssertTrue(app.buttons["saveScore"].waitForExistence(timeout: 5))
            app.buttons["saveScore"].tap()
            XCTAssertTrue(app.buttons["playAgain"].waitForExistence(timeout: 5))
            if score == 50 {
                XCTAssertTrue(app.otherElements["leaderboardRow4"].isHittable)
                XCTAssertTrue(app.buttons["playAgain"].isHittable)
                XCTAssertFalse(app.otherElements["leaderboardRow5"].exists)
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "Five-score leaderboard"
                screenshot.lifetime = .keepAlways
                add(screenshot)
            }
            app.terminate()
        }
    }

    @MainActor
    func testFullAppArcadeLaunchAndRelaunch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Lumi Arcade"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Arcade"].exists)
        XCTAssertTrue(app.tabBars.buttons["Leaderboards"].exists)
        XCTAssertTrue(app.tabBars.buttons["Profile"].exists)
        app.buttons["play-sky-stack"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["TAP TO STACK"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["liveScore"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)).tap()
        XCTAssertFalse(app.staticTexts["TAP TO STACK"].exists)
        XCTAssertEqual(app.staticTexts["liveScore"].label, "1")
        app.buttons["exitGame"].tap()
        XCTAssertTrue(app.navigationBars["Lumi Arcade"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Lumi Arcade"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["CONTINUE PLAYING"].exists)
    }

    @MainActor
    func testPulseArcadotRoutesToPulseResults() {
        let app = XCUIApplication()
        let id = "PULSE" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        app.launchArguments = ["-LumiArcadeInvocationURL", "https://play.lumiarcade.com/g/pulse/" + id,
                               "-PulsePreviewScore", "4"]
        app.launch()
        XCTAssertTrue(app.buttons["saveScore"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["finalScore"].label, "4")
        XCTAssertEqual(app.staticTexts["arcadotIdentity"].label, "ARCADOT #" + id)
        XCTAssertTrue(app.staticTexts["PULSE"].exists)
        XCTAssertEqual(app.keyboards.count, 0)
    }

    @MainActor
    func testPulseGameplayTapStartsAndAcceptsRepeatedPulses() {
        let app = XCUIApplication()
        app.launchArguments = ["-LumiArcadeInvocationURL", "https://play.lumiarcade.com/play?game=pulse"]
        app.launch()
        XCTAssertTrue(app.staticTexts["pulseInstruction"].waitForExistence(timeout: 5))
        let gameplay = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
        gameplay.tap()
        XCTAssertFalse(app.staticTexts["pulseInstruction"].exists)
        XCTAssertTrue(app.staticTexts["liveScore"].waitForExistence(timeout: 1))
        for _ in 0..<2 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
            gameplay.tap()
        }
        XCTAssertFalse(app.staticTexts["finalScore"].exists)
    }

    @MainActor
    func testNecklaceSwitchPersistsThroughAssignmentCacheFallback() {
        let app = XCUIApplication()
        let id = "SWITCH" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let url = "https://play.lumiarcade.com/a/" + id
        app.launchArguments = ["-LumiArcadeInvocationURL", url,
                               "-LumiArcadeAssignmentGame", "pulse"]
        app.launch()
        XCTAssertTrue(app.staticTexts["pulseInstruction"].waitForExistence(timeout: 5))
        app.buttons["switchGame"].tap()
        XCTAssertTrue(app.buttons["Switch Games"].waitForExistence(timeout: 2))
        app.buttons["Switch Games"].tap()
        XCTAssertTrue(app.buttons["select-sky-stack"].waitForExistence(timeout: 3))
        app.buttons["select-sky-stack"].tap()
        XCTAssertTrue(app.staticTexts["TAP TO STACK"].waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = ["-LumiArcadeInvocationURL", url,
                               "-LumiArcadeAssignmentUnavailable"]
        app.launch()
        XCTAssertTrue(app.staticTexts["TAP TO STACK"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["switchGame"].exists)

        app.buttons["switchGame"].tap()
        XCTAssertTrue(app.buttons["Switch Games"].waitForExistence(timeout: 2))
        app.buttons["Switch Games"].tap()
        XCTAssertTrue(app.buttons["select-pulse"].waitForExistence(timeout: 3))
        app.buttons["select-pulse"].tap()
        XCTAssertTrue(app.buttons["retryAssignment"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["playOnce"].exists)
        app.buttons["playOnce"].tap()
        XCTAssertTrue(app.staticTexts["pulseInstruction"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSavedScoreSwitchOpensSelectorWithoutRunEndConfirmation() {
        let app = XCUIApplication()
        let id = "SAVED" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        app.launchArguments = [
            "-LumiArcadeInvocationURL", "https://play.lumiarcade.com/g/sky-stack/" + id,
            "-SkyStackPreviewScore", "7"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["saveScore"].waitForExistence(timeout: 5))
        app.buttons["saveScore"].tap()
        XCTAssertTrue(app.buttons["playAgain"].waitForExistence(timeout: 5))

        app.buttons["switchGame"].tap()
        XCTAssertTrue(app.buttons["select-pulse"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Switch Games"].exists)
    }

    @MainActor
    func testOfflineNecklaceWithoutCacheAllowsSessionOnlyPlay() {
        let app = XCUIApplication()
        let id = "OFFLINE" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        app.launchArguments = ["-LumiArcadeInvocationURL", "https://play.lumiarcade.com/a/" + id,
                               "-LumiArcadeAssignmentUnavailable"]
        app.launch()
        XCTAssertTrue(app.buttons["select-pulse"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["select-sky-stack"].exists)
        app.buttons["select-pulse"].tap()
        XCTAssertTrue(app.staticTexts["pulseInstruction"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDifferentNecklacesKeepIndependentCachedAssignments() {
        let app = XCUIApplication()
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let pulseURL = "https://play.lumiarcade.com/a/P" + suffix
        let stackURL = "https://play.lumiarcade.com/a/S" + suffix

        app.launchArguments = ["-LumiArcadeInvocationURL", pulseURL,
                               "-LumiArcadeAssignmentGame", "pulse"]
        app.launch()
        XCTAssertTrue(app.staticTexts["pulseInstruction"].waitForExistence(timeout: 5))
        app.terminate()

        app.launchArguments = ["-LumiArcadeInvocationURL", stackURL,
                               "-LumiArcadeAssignmentGame", "sky-stack"]
        app.launch()
        XCTAssertTrue(app.staticTexts["TAP TO STACK"].waitForExistence(timeout: 5))
        app.terminate()

        app.launchArguments = ["-LumiArcadeInvocationURL", pulseURL,
                               "-LumiArcadeAssignmentUnavailable"]
        app.launch()
        XCTAssertTrue(app.staticTexts["pulseInstruction"].waitForExistence(timeout: 5))
        app.terminate()

        app.launchArguments = ["-LumiArcadeInvocationURL", stackURL,
                               "-LumiArcadeAssignmentUnavailable"]
        app.launch()
        XCTAssertTrue(app.staticTexts["TAP TO STACK"].waitForExistence(timeout: 5))
    }
}
