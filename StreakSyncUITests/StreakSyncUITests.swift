//
//  StreakSyncUITests.swift
//  StreakSyncUITests
//
//  Smoke tests verifying core navigation and UI presence.
//

import XCTest

final class StreakSyncUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch

    func testAppLaunchesSuccessfully() {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    // MARK: - Tab Navigation

    func testAllFourTabsExist() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        XCTAssertTrue(tabBar.buttons["Home"].exists, "Home tab missing")
        XCTAssertTrue(tabBar.buttons["Awards"].exists, "Awards tab missing")
        XCTAssertTrue(tabBar.buttons["Friends"].exists, "Friends tab missing")
        XCTAssertTrue(tabBar.buttons["Settings"].exists, "Settings tab missing")
    }

    func testTabSwitching() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["Awards"].tap()
        // Verify we navigated away from Home
        XCTAssertTrue(tabBar.buttons["Awards"].isSelected)

        tabBar.buttons["Friends"].tap()
        XCTAssertTrue(tabBar.buttons["Friends"].isSelected)

        tabBar.buttons["Settings"].tap()
        XCTAssertTrue(tabBar.buttons["Settings"].isSelected)

        tabBar.buttons["Home"].tap()
        XCTAssertTrue(tabBar.buttons["Home"].isSelected)
    }

    // MARK: - Dashboard (Home Tab)

    func testDashboardShowsContent() {
        // Home tab should show some content after launch
        let homeContent = app.scrollViews.firstMatch
        XCTAssertTrue(homeContent.waitForExistence(timeout: 5),
                      "Dashboard scroll view should appear")
    }

    // MARK: - Settings Tab

    func testSettingsTabShowsSections() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Settings"].tap()

        // Settings should contain an Account row
        let settingsContent = app.scrollViews.firstMatch
        XCTAssertTrue(settingsContent.waitForExistence(timeout: 5),
                      "Settings content should appear")
    }

    // MARK: - Awards Tab

    func testAwardsTabLoads() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Awards"].tap()

        // Awards grid should appear
        let content = app.scrollViews.firstMatch
        XCTAssertTrue(content.waitForExistence(timeout: 5),
                      "Awards content should appear")
    }

    // MARK: - Friends Tab

    func testFriendsTabLoads() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Friends"].tap()

        // Friends tab should show content (leaderboard or sign-in prompt)
        let exists = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'friend'")).firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(exists, "Friends tab should show content")
    }
}
