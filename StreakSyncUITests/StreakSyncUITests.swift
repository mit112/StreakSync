//
//  StreakSyncUITests.swift
//  StreakSyncUITests
//
//  Smoke-flow UI tests for core app navigation.
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

    // MARK: - Helpers

    @discardableResult
    private func waitForTabBar(timeout: TimeInterval = 20) -> XCUIElement {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: timeout), "Tab bar did not appear")
        return tabBar
    }

    @discardableResult
    private func openTab(named tabName: String) -> XCUIElement {
        let tabBar = waitForTabBar()
        let tab = tabBar.buttons[tabName]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Tab '\(tabName)' does not exist")
        tab.tap()
        return tab
    }

    private func manageFriendsControl() -> XCUIElement {
        let byIdentifier = app.descendants(matching: .any)
            .matching(identifier: "friends.manage.button")
            .firstMatch
        if byIdentifier.exists {
            return byIdentifier
        }
        return app.buttons["Manage friends"].firstMatch
    }

    // MARK: - Launch and Baseline Presence

    @MainActor
    func testAppLaunchesToTabLayout() {
        _ = waitForTabBar()
    }

    // MARK: - Tab Navigation

    @MainActor
    func testAllCoreTabsExistAndAreHittable() {
        let tabBar = waitForTabBar()

        let home = tabBar.buttons["Home"]
        let awards = tabBar.buttons["Awards"]
        let friends = tabBar.buttons["Friends"]
        let settings = tabBar.buttons["Settings"]

        XCTAssertTrue(home.exists, "Home tab missing")
        XCTAssertTrue(awards.exists, "Awards tab missing")
        XCTAssertTrue(friends.exists, "Friends tab missing")
        XCTAssertTrue(settings.exists, "Settings tab missing")

        XCTAssertTrue(home.isHittable, "Home tab not hittable")
        XCTAssertTrue(awards.isHittable, "Awards tab not hittable")
        XCTAssertTrue(friends.isHittable, "Friends tab not hittable")
        XCTAssertTrue(settings.isHittable, "Settings tab not hittable")
    }

    @MainActor
    func testTabSwitchingShowsContentContainers() {
        let tabBar = waitForTabBar()

        tabBar.buttons["Awards"].tap()
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5), "Awards content missing")

        tabBar.buttons["Friends"].tap()
        let friendsContentExists = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'friend'")).firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(friendsContentExists, "Friends content missing")

        tabBar.buttons["Settings"].tap()
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5), "Settings content missing")

        tabBar.buttons["Home"].tap()
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5), "Home content missing")
    }

    // MARK: - Shake/Fuzz Navigation

    @MainActor
    func testRapidTabSwitchingStress() {
        let tabBar = waitForTabBar()
        let sequence = ["Home", "Awards", "Friends", "Settings", "Home", "Friends", "Awards", "Settings", "Home"]

        for tabName in sequence {
            let tab = tabBar.buttons[tabName]
            XCTAssertTrue(tab.exists, "Missing tab during stress run: \(tabName)")
            tab.tap()
        }

        XCTAssertTrue(tabBar.exists, "Tab bar disappeared after rapid switching")
    }

    // MARK: - Phase 2: Settings Deep Navigation

    @MainActor
    func testSettingsSubscreensOpenAndReturn() {
        openTab(named: "Settings")

        let notificationsRow = app.staticTexts["Notifications"].firstMatch
        XCTAssertTrue(notificationsRow.waitForExistence(timeout: 8), "Notifications row missing")
        notificationsRow.tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 8), "Notifications screen did not open")
        app.buttons["Done"].firstMatch.tap()

        let appearanceRow = app.staticTexts["Appearance"].firstMatch
        XCTAssertTrue(appearanceRow.waitForExistence(timeout: 8), "Appearance row missing")
        appearanceRow.tap()
        XCTAssertTrue(app.navigationBars["Appearance"].waitForExistence(timeout: 8), "Appearance screen did not open")
        app.buttons["Done"].firstMatch.tap()

        let dataRow = app.staticTexts["Data & Privacy"].firstMatch
        XCTAssertTrue(dataRow.waitForExistence(timeout: 8), "Data & Privacy row missing")
        dataRow.tap()
        XCTAssertTrue(app.navigationBars["Data & Privacy"].waitForExistence(timeout: 8), "Data & Privacy screen did not open")
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8), "Failed to return to Settings root")
    }

    @MainActor
    func testNotificationScreenStateRendersInAnyPermissionMode() {
        openTab(named: "Settings")

        let notificationsRow = app.staticTexts["Notifications"].firstMatch
        XCTAssertTrue(notificationsRow.waitForExistence(timeout: 8), "Notifications row missing")
        notificationsRow.tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 8), "Notifications screen did not open")

        let hasDeniedState = app.staticTexts["Notifications Disabled"].firstMatch.waitForExistence(timeout: 4)
        let hasConfiguredState = app.staticTexts["Daily Reminder"].firstMatch.waitForExistence(timeout: 4)
        XCTAssertTrue(hasDeniedState || hasConfiguredState, "Notifications screen rendered neither disabled nor configured state")
    }

    // MARK: - Phase 2: Friends Entry Flow

    @MainActor
    func testFriendsManageSheetOpensAndCloses() {
        openTab(named: "Friends")

        let manageButton = manageFriendsControl()
        XCTAssertTrue(manageButton.waitForExistence(timeout: 8), "Manage friends button missing")
        XCTAssertTrue(manageButton.isHittable, "Manage friends button exists but is not hittable")
        manageButton.tap()

        let manageTitleVisible = app.navigationBars["Manage Friends"].firstMatch.waitForExistence(timeout: 15)
        let doneVisible = app.buttons["Done"].firstMatch.waitForExistence(timeout: 15)
        let addFriendSectionVisible = app.staticTexts["Add a Friend"].firstMatch.waitForExistence(timeout: 15)
        XCTAssertTrue(manageTitleVisible || doneVisible || addFriendSectionVisible, "Manage Friends sheet did not open")
        XCTAssertTrue(addFriendSectionVisible, "Manage Friends sections did not load")

        app.buttons["Done"].firstMatch.tap()
        XCTAssertFalse(app.navigationBars["Manage Friends"].waitForExistence(timeout: 3), "Manage Friends sheet did not close")
    }

    // MARK: - Phase 2: Combined Stress

    @MainActor
    func testCrossFeatureNavigationStress() {
        openTab(named: "Settings")
        let notificationsRow = app.staticTexts["Notifications"].firstMatch
        XCTAssertTrue(notificationsRow.waitForExistence(timeout: 8))
        notificationsRow.tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 8))
        app.buttons["Done"].firstMatch.tap()

        openTab(named: "Friends")
        let manageButton = manageFriendsControl()
        XCTAssertTrue(manageButton.waitForExistence(timeout: 8))
        XCTAssertTrue(manageButton.isHittable)
        manageButton.tap()
        let manageTitleVisible = app.navigationBars["Manage Friends"].firstMatch.waitForExistence(timeout: 15)
        let doneVisible = app.buttons["Done"].firstMatch.waitForExistence(timeout: 15)
        let addFriendSectionVisible = app.staticTexts["Add a Friend"].firstMatch.waitForExistence(timeout: 15)
        XCTAssertTrue(manageTitleVisible || doneVisible || addFriendSectionVisible)
        app.buttons["Done"].firstMatch.tap()

        openTab(named: "Awards")
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5))

        openTab(named: "Home")
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
