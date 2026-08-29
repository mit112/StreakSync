//
//  AnalyticsViewModelPresentationTests.swift
//  StreakSyncTests
//
//  Empty-state decisions and summary-string formatting in the Analytics feature view model.
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
        XCTAssertNil(viewModel.selectedGameId)

        viewModel.selectedGame = Game.spellingBee

        XCTAssertEqual(viewModel.selectedGameDisplayName, "Spelling Bee", "Display name, not the internal name")
        XCTAssertEqual(viewModel.selectedGameId, Game.spellingBee.id)
    }

    // MARK: - Recent Activity Summary

    /// All three slots carry distinct values so a transposed tuple cannot pass.
    func test_getRecentActivitySummary_mapsOverviewFieldsToTheRightSlots() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(
            overview: AnalyticsOverview(
                totalActiveStreaks: 4,
                totalGamesPlayed: 11,
                averageCompletionRate: 0.25
            )
        )

        let summary = viewModel.getRecentActivitySummary()

        XCTAssertEqual(summary.totalGames, 11)
        XCTAssertEqual(summary.completionRate, 0.25, accuracy: 0.0001)
        XCTAssertEqual(summary.activeStreaks, 4)
    }

    func test_getRecentActivitySummary_withNoLoadedData_isAllZeros() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()

        let summary = viewModel.getRecentActivitySummary()

        XCTAssertEqual(summary.totalGames, 0)
        XCTAssertEqual(summary.completionRate, 0.0, accuracy: 0.0001)
        XCTAssertEqual(summary.activeStreaks, 0)
    }

    // MARK: - Streak Trend Summary

    /// The delta is latest-minus-previous, where "previous" is the second-to-last point.
    /// Values are 5, 2, 4 — anchoring on the FIRST point instead would report "-1".
    func test_getStreakTrendSummary_comparesTheLatestPointAgainstThePrecedingOne() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(streakTrends: [
            AnalyticsFeatureFixtures.makeTrendPoint(daysAgo: 2, totalActiveStreaks: 5),
            AnalyticsFeatureFixtures.makeTrendPoint(daysAgo: 1, totalActiveStreaks: 2),
            AnalyticsFeatureFixtures.makeTrendPoint(daysAgo: 0, totalActiveStreaks: 4)
        ])

        XCTAssertEqual(viewModel.getStreakTrendSummary(), "4 active streaks (+2)")
    }

    func test_getStreakTrendSummary_carriesTheNegativeSignOnADecline() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(streakTrends: [
            AnalyticsFeatureFixtures.makeTrendPoint(daysAgo: 2, totalActiveStreaks: 1),
            AnalyticsFeatureFixtures.makeTrendPoint(daysAgo: 1, totalActiveStreaks: 6),
            AnalyticsFeatureFixtures.makeTrendPoint(daysAgo: 0, totalActiveStreaks: 2)
        ])

        XCTAssertEqual(viewModel.getStreakTrendSummary(), "2 active streaks (-4)")
    }

    func test_getStreakTrendSummary_singlePoint_reportsNoChange() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(streakTrends: [
            AnalyticsFeatureFixtures.makeTrendPoint(daysAgo: 0, totalActiveStreaks: 3)
        ])

        XCTAssertEqual(viewModel.getStreakTrendSummary(), "3 active streaks (No change)")
    }

    func test_getStreakTrendSummary_withNoTrends_reportsNoData() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(streakTrends: [])

        XCTAssertEqual(viewModel.getStreakTrendSummary(), "No data available")
    }

    // MARK: - Rate Summaries

    /// 0.756 rounds to 76, which also proves the rate is scaled by 100 before formatting.
    func test_getCompletionRateSummary_rendersTheRateAsAWholePercent() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(
            overview: AnalyticsOverview(averageCompletionRate: 0.756)
        )

        XCTAssertEqual(viewModel.getCompletionRateSummary(), "76% completion rate")
    }

    func test_getCompletionRateSummary_withNoLoadedData_reportsNoData() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()

        XCTAssertEqual(viewModel.getCompletionRateSummary(), "No data available")
    }

    func test_getStreakConsistencySummary_rendersConsistencyAsAWholePercent() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(
            overview: AnalyticsOverview(streakConsistency: 0.5)
        )

        XCTAssertEqual(viewModel.getStreakConsistencySummary(), "50% consistency")
    }

    func test_getStreakConsistencySummary_withNoLoadedData_reportsNoData() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()

        XCTAssertEqual(viewModel.getStreakConsistencySummary(), "No data available")
    }
}
