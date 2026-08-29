//
//  CriticalJourneyUITests.swift
//  StreakSyncUITests
//
//  UI coverage for the three journeys that have caused real regressions.
//

import XCTest

/// Share-extension import, friend-request accept, notification deep link.
///
/// All three begin outside the app — in an extension process, in Firestore, and in
/// SpringBoard — so each test enters at the first point the app itself owns, via a
/// `#if DEBUG` launch-argument seam (`UITestSupport`). What that leaves uncovered is
/// stated per test rather than glossed over.
final class CriticalJourneyUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
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

    private func openTab(named tabName: String) {
        let tab = waitForTabBar().buttons[tabName]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Tab '\(tabName)' does not exist")
        tab.tap()
    }

    /// Game cards wrap all their `Text`s in a `Button` with no `accessibilityElement`
    /// override, so SwiftUI merges them into one element with a comma-joined label.
    /// Matching `staticTexts["Wordle"]` does not work; the predicate does.
    private func gameCard(labelContaining fragment: String) -> XCUIElement {
        app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", fragment))
            .firstMatch
    }

    // MARK: - Journey 1: Share Extension import

    /// Enters at the App Group queue, one step after the Share Extension's write.
    /// Everything from there is production code: the queue read, duplicate detection,
    /// the `.gameResultReceived` route through `NotificationCoordinator`,
    /// `AppState.addGameResult`, streak recalculation, persistence, and the dashboard.
    ///
    /// NOT covered: the extension's own write and the Darwin notification that wakes
    /// the app. Both need a second process, which XCUITest cannot drive.
    @MainActor
    func testSharedResultReachesTheDashboard() {
        // --uitest-reset first: without it this test passes on any simulator that
        // still holds a Wordle result from an earlier run, which is exactly how it
        // was caught being vacuous.
        app.launchArguments += ["--uitest-reset", "--uitest-share-import", "Wordle"]
        app.launch()
        waitForTabBar()

        // Home is streak-derived, so a freshly ingested result surfaces as a played-today
        // card rather than a result row. Anything other than "Never played" for Wordle
        // means the result completed the whole pipeline and reached the UI.
        let playedWordle = gameCard(labelContaining: "Wordle")
        XCTAssertTrue(playedWordle.waitForExistence(timeout: 20), "Wordle card never appeared")

        let label = playedWordle.label
        XCTAssertFalse(
            label.contains("Never played"),
            "Wordle still reads 'Never played', so the queued result never landed: \(label)"
        )
        XCTAssertTrue(
            label.contains("Today"),
            "Wordle should read as played today after ingestion: \(label)"
        )
    }

    // MARK: - Journey 2: Notification deep link

    /// Enters at `handleURLScheme`, one step after SpringBoard hands the URL over.
    /// Covers the two regressions this path has actually had: a game deep link
    /// pushing detail onto whatever tab happened to be showing rather than Home,
    /// and the name-keyed form being posted and then silently dropped.
    ///
    /// NOT covered: the OS delivering the URL to `onOpenURL`, which is Apple's code.
    @MainActor
    func testNameKeyedDeepLinkOpensGameDetail() {
        app.launchArguments += ["--uitest-deeplink", "streaksync://game?name=Mini%20Crossword"]
        app.launch()
        waitForTabBar()

        // navigationTitle is the game's displayName, and "Play <name>" is unique to
        // the detail screen — together they pin both "we navigated" and "to the
        // right game".
        XCTAssertTrue(
            app.navigationBars["Mini Crossword"].waitForExistence(timeout: 20),
            "Deep link did not land on Mini Crossword's detail screen"
        )
        XCTAssertTrue(
            app.buttons["Play Mini Crossword"].waitForExistence(timeout: 10),
            "Landed somewhere without the game detail primary action"
        )
    }

    /// The deep link must route through Home specifically. It used to push detail onto
    /// whichever tab was already showing, which left the user on a Settings stack with
    /// a game detail on top of it.
    @MainActor
    func testGameDeepLinkRoutesToHomeNotTheVisibleTab() {
        app.launchArguments += ["--uitest-deeplink", "streaksync://game?name=Wordle"]
        app.launch()
        waitForTabBar()

        XCTAssertTrue(
            app.navigationBars["Wordle"].waitForExistence(timeout: 20),
            "Deep link did not open Wordle detail"
        )

        // Popping the pushed detail must reveal Home, not another tab's root.
        let backButton = app.navigationBars["Wordle"].buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "No back button on game detail")
        backButton.tap()

        XCTAssertTrue(
            app.navigationBars["StreakSync"].waitForExistence(timeout: 10),
            "Popping game detail did not return to Home — the link routed to the wrong tab"
        )
    }

    // MARK: - Analytics empty state

    /// The Analytics tab used to render a blank screen for anyone with no data: its
    /// content was a run of `if`s with no `else`. The fix branches on
    /// `hasDataForCurrentSelection`, but that branch lives inside a SwiftUI `body` and
    /// has no unit-test seam — both of its inputs and both of its outputs are unit
    /// tested, the branch between them needs the simulator. This is that check.
    @MainActor
    func testAnalyticsShowsAnEmptyStateRatherThanABlankScreen() {
        app.launchArguments += ["--uitest-reset"]
        app.launch()
        waitForTabBar()

        let analytics = app.buttons["View Analytics"].firstMatch
        XCTAssertTrue(analytics.waitForExistence(timeout: 20), "No way into Analytics from Home")
        analytics.tap()

        XCTAssertTrue(
            app.staticTexts["No Results Yet"].waitForExistence(timeout: 15),
            "Analytics rendered nothing for a user with no data"
        )
    }

    // MARK: - Journey 3: Friend request accept

    /// Runs against the in-memory social service, because a UI test cannot seed
    /// Firestore. Covers the reactive-state cluster this screen has regressed on
    /// before: the pending row rendering at all, and the list updating after accept
    /// rather than leaving a stale row or a stuck skeleton.
    ///
    /// NOT covered: the Firestore write itself, the bidirectional auto-accept rule,
    /// and the security rules — all of which are covered by the rules test suite.
    @MainActor
    func testAcceptingAFriendRequestUpdatesTheList() {
        app.launchArguments += ["--uitest-friend-request"]
        app.launch()

        openTab(named: "Friends")

        // The pending-request UI lives inside the Manage Friends sheet, not on the tab.
        let manageButton = app.descendants(matching: .any)
            .matching(identifier: "friends.manage.button")
            .firstMatch
        let manageControl = manageButton.exists ? manageButton : app.buttons["Manage friends"].firstMatch
        XCTAssertTrue(manageControl.waitForExistence(timeout: 15), "No way into Manage Friends")
        manageControl.tap()

        XCTAssertTrue(
            app.staticTexts["Add a Friend"].waitForExistence(timeout: 15),
            "Manage Friends sheet did not load"
        )

        // The Pending Requests section is absent entirely when there are none, so its
        // presence is the assertion that the seeded request rendered.
        XCTAssertTrue(
            app.staticTexts["Pending Requests"].waitForExistence(timeout: 10),
            "Seeded friend request did not render"
        )

        let accept = app.buttons["Accept"].firstMatch
        XCTAssertTrue(accept.waitForExistence(timeout: 10), "No Accept control on the pending row")
        accept.tap()

        // Accepting must clear the section — a row that survives its own accept is the
        // stale-state bug this screen has shipped before.
        let pendingHeader = app.staticTexts["Pending Requests"]
        let disappeared = pendingHeader.waitForNonExistence(timeout: 15)
        XCTAssertTrue(disappeared, "Pending Requests section survived accepting the only request")
    }
}
