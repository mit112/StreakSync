//
//  AnalyticsViewModelTests.swift
//  StreakSyncTests
//
//  Ranking, chart shaping, and game selection in the Analytics feature view model.
//

import Foundation
@testable import StreakSync
import XCTest

@MainActor
final class AnalyticsViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AnalyticsFeatureFixtures.clearSavedScope()
    }

    override func tearDown() {
        AnalyticsFeatureFixtures.clearSavedScope()
        super.tearDown()
    }

    // MARK: - Fixtures

    /// Three games whose ranking by games-played is deliberately different from the order
    /// they are passed in, so a test can tell a real sort from a pass-through.
    ///
    /// | game        | totalGamesPlayed |
    /// |-------------|------------------|
    /// | Wordle      | 3                |
    /// | Quordle     | 9                |
    /// | SpellingBee | 6                |
    private func mixedRankings() -> [GameAnalytics] {
        [
            AnalyticsFeatureFixtures.makeGameAnalytics(game: Game.wordle, totalGamesPlayed: 3),
            AnalyticsFeatureFixtures.makeGameAnalytics(game: Game.quordle, totalGamesPlayed: 9),
            AnalyticsFeatureFixtures.makeGameAnalytics(game: Game.spellingBee, totalGamesPlayed: 6)
        ]
    }

    // MARK: - Most Active Games

    /// Guards three things at once: the sort key is games-played, the direction is
    /// descending, and `prefix(limit)` runs AFTER the sort. Input order is Wordle,
    /// Quordle, SpellingBee — truncating first would return Wordle and Quordle.
    func test_getMostActiveGames_sortsByGamesPlayedDescending_andTruncatesAfterSorting() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(gameAnalytics: mixedRankings())

        let top = viewModel.getMostActiveGames(limit: 2)

        XCTAssertEqual(top.map(\.game.id), [Game.quordle.id, Game.spellingBee.id])
    }

    // MARK: - Streak Trend Chart Shaping

    /// The chart plots `value` on the Y axis and carries `secondaryValue` alongside it.
    /// Swapping the two would still render a plausible-looking line.
    func test_getStreakTrendChartData_mapsActiveStreaksToValueAndLongestToSecondary() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        let trends = [
            AnalyticsFeatureFixtures.makeTrendPoint(daysAgo: 1, totalActiveStreaks: 3, longestStreak: 12),
            AnalyticsFeatureFixtures.makeTrendPoint(daysAgo: 0, totalActiveStreaks: 5, longestStreak: 9)
        ]
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(streakTrends: trends)

        let points = viewModel.getStreakTrendChartData()

        XCTAssertEqual(points.map(\.value), [3, 5])
        let secondaries = points.compactMap { $0.secondaryValue }
        XCTAssertEqual(secondaries, [12, 9])
        XCTAssertEqual(points.map(\.date), trends.map(\.date), "Chart points keep the trend ordering")
        XCTAssertEqual(points.first?.label, "Active Streaks")
    }

    // MARK: - Current Game Analytics

    /// Wordle is deliberately the SECOND entry: returning `.first` unconditionally would
    /// show Quordle's numbers under Wordle's heading.
    func test_currentGameAnalytics_matchesTheSelectedGame_notTheFirstEntry() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(gameAnalytics: [
            AnalyticsFeatureFixtures.makeGameAnalytics(game: Game.quordle, totalGamesPlayed: 9),
            AnalyticsFeatureFixtures.makeGameAnalytics(game: Game.wordle, totalGamesPlayed: 3)
        ])
        viewModel.selectedGame = Game.wordle

        XCTAssertEqual(viewModel.currentGameAnalytics?.game.id, Game.wordle.id)
        XCTAssertEqual(viewModel.currentGameAnalytics?.totalGamesPlayed, 3)
    }

    func test_currentGameAnalytics_withoutASelectedGame_isNil() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(gameAnalytics: [
            AnalyticsFeatureFixtures.makeGameAnalytics(game: Game.quordle, totalGamesPlayed: 9)
        ])

        XCTAssertNil(viewModel.selectedGame, "Fixture precondition: cleared scope selects All Games")
        XCTAssertNil(viewModel.currentGameAnalytics)
    }
}
