//
//  AnalyticsViewModelPresentationTests.swift
//  StreakSyncTests
//
//  Empty-state decisions and scope labelling in the Analytics feature view model.
//

import Foundation
@testable import StreakSync
import XCTest

@MainActor
final class AnalyticsViewModelPresentationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AnalyticsFeatureFixtures.clearSavedScope()
    }

    override func tearDown() {
        AnalyticsFeatureFixtures.clearSavedScope()
        super.tearDown()
    }

    // MARK: - Empty-State Decision (All Games)

    /// `recentActivity` is capped by the computer, so a long-range view can legitimately
    /// have totals with no recent rows. Dropping the totals check would show the empty
    /// state on top of a populated overview.
    func test_hasDataForCurrentSelection_allGames_isTrueWhenTotalsExistWithoutRecentActivity() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(
            overview: AnalyticsOverview(totalGamesPlayed: 7, recentActivity: [])
        )

        XCTAssertNil(viewModel.selectedGame, "Fixture precondition: cleared scope selects All Games")
        XCTAssertTrue(viewModel.hasDataForCurrentSelection)
    }

    func test_hasDataForCurrentSelection_allGames_isFalseWhenTheOverviewIsEmpty() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(overview: AnalyticsOverview())

        XCTAssertFalse(viewModel.hasDataForCurrentSelection)
    }

    // MARK: - Empty-State Decision (Single Game)

    /// The overview totals belong to All Games. Once a game is selected they must not
    /// be allowed to vouch for a game that has no analytics of its own.
    func test_hasDataForCurrentSelection_selectedGame_isFalseWhenThatGameHasNoAnalytics() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(
            overview: AnalyticsOverview(totalGamesPlayed: 42),
            gameAnalytics: [AnalyticsFeatureFixtures.makeGameAnalytics(game: Game.quordle, totalGamesPlayed: 42)]
        )
        viewModel.selectedGame = Game.wordle

        XCTAssertFalse(viewModel.hasDataForCurrentSelection)
    }

    func test_hasDataForCurrentSelection_selectedGame_isTrueWhenThatGameHasAnalytics() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(
            gameAnalytics: [AnalyticsFeatureFixtures.makeGameAnalytics(game: Game.wordle, totalGamesPlayed: 3)]
        )
        viewModel.selectedGame = Game.wordle

        XCTAssertTrue(viewModel.hasDataForCurrentSelection)
    }

    /// The blank-screen case: a brand-new user reaches the dashboard before any payload
    /// exists. This must report "no data" so the empty state renders rather than nothing.
    func test_hasDataForCurrentSelection_withNoLoadedData_isFalse() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()

        XCTAssertFalse(viewModel.hasDataForCurrentSelection)
    }

    // MARK: - Empty-State Copy

    func test_emptyStateMessage_namesTheSelectedGame() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        viewModel.selectedGame = Game.spellingBee

        XCTAssertEqual(viewModel.emptyStateMessage, "No data for Spelling Bee in the selected time range")
    }

    func test_emptyStateMessage_allGames_usesTheGenericCopy() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()

        XCTAssertEqual(viewModel.emptyStateMessage, "No games played in the selected time range")
    }

    func test_selectedGameDisplayName_fallsBackToAllGames() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        XCTAssertEqual(viewModel.selectedGameDisplayName, "All Games")

        viewModel.selectedGame = Game.spellingBee

        XCTAssertEqual(viewModel.selectedGameDisplayName, "Spelling Bee", "Display name, not the internal name")
    }
}
