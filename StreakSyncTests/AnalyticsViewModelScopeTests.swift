//
//  AnalyticsViewModelScopeTests.swift
//  StreakSyncTests
//
//  Saved-scope restoration, reload gating, and CSV export for Analytics.
//

import Foundation
@testable import StreakSync
import XCTest

@MainActor
final class AnalyticsViewModelScopeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AnalyticsFeatureFixtures.clearSavedScope()
    }

    override func tearDown() {
        AnalyticsFeatureFixtures.clearSavedScope()
        super.tearDown()
    }

    // MARK: - Scope Restoration

    func test_init_seedsTheTimeRangeAndGameFromTheSavedScope() {
        AnalyticsScope(timeRange: .month, gameId: Game.wordle.id).save()

        let viewModel = AnalyticsFeatureFixtures.makeViewModel()

        XCTAssertEqual(viewModel.selectedTimeRange, .month)
        XCTAssertEqual(viewModel.selectedGame?.id, Game.wordle.id)
    }

    /// A scope can outlive the game it points at (removed catalog entry, restored backup).
    /// The view model must scrub the dangling id from disk, not just ignore it in memory —
    /// otherwise every future launch re-reads the same dead id.
    func test_init_scrubsAStaleGameIdFromTheSavedScope() {
        AnalyticsScope(timeRange: .month, gameId: UUID()).save()

        let viewModel = AnalyticsFeatureFixtures.makeViewModel()

        XCTAssertNil(viewModel.selectedGame)
        XCTAssertNil(viewModel.scope.gameId)
        XCTAssertNil(AnalyticsScope.loadSaved().gameId, "The dead id must be cleared on disk too")
        XCTAssertEqual(viewModel.selectedTimeRange, .month, "A stale game id must not reset the time range")
    }

    func test_loadAnalytics_persistsTheTimeRangeToTheSavedScope() async {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        XCTAssertEqual(AnalyticsScope.loadSaved().timeRange, .week, "Fixture precondition: default scope is .week")

        await viewModel.loadAnalytics(for: .month)

        XCTAssertEqual(AnalyticsScope.loadSaved().timeRange, .month)
    }

    // MARK: - Reload Gating

    /// Tapping the already-selected range in the time-range picker must not kick off
    /// another full recompute. `analyticsData` starts nil, so any reload is visible.
    func test_changeTimeRange_doesNotReloadWhenTheRangeIsUnchanged() async {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        viewModel.selectedTimeRange = .week
        viewModel.analyticsData = nil

        await viewModel.changeTimeRange(to: .week)
        XCTAssertNil(viewModel.analyticsData, "Re-selecting the current range must be a no-op")

        await viewModel.changeTimeRange(to: .month)
        XCTAssertNotNil(viewModel.analyticsData, "A different range must reload")
        XCTAssertEqual(viewModel.selectedTimeRange, .month)
    }

    // MARK: - CSV Export

    func test_exportCSV_withNoLoadedData_isEmpty() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()

        XCTAssertTrue(viewModel.exportCSV().isEmpty)
    }

    /// Pins the column order and, in the game column, the user-facing `displayName`
    /// rather than the lowercase internal `name`.
    func test_exportCSV_emitsTheHeaderAndOneRowPerResult() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        let played = Date(timeIntervalSince1970: 1_700_000_000)
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(gameAnalytics: [
            AnalyticsFeatureFixtures.makeGameAnalytics(
                game: Game.wordle,
                totalGamesPlayed: 1,
                recentResults: [AnalyticsFeatureFixtures.makeResult(game: Game.wordle, date: played, score: 4)]
            )
        ])

        let rows = viewModel.exportCSV().components(separatedBy: "\n")

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.first, "date,game,score,maxAttempts,completed")
        let stamp = ISO8601DateFormatter().string(from: played)
        XCTAssertEqual(rows.last, "\(stamp),Wordle,4,6,true")
    }

    /// A failed Wordle has no score. The column has to be blank, not "0" — zero is a
    /// legal score for the higher-is-better games and would read as a real result.
    func test_exportCSV_leavesTheScoreColumnBlankForAnUnscoredResult() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        let played = Date(timeIntervalSince1970: 1_700_000_000)
        viewModel.analyticsData = AnalyticsFeatureFixtures.makeData(gameAnalytics: [
            AnalyticsFeatureFixtures.makeGameAnalytics(
                game: Game.wordle,
                totalGamesPlayed: 1,
                recentResults: [
                    AnalyticsFeatureFixtures.makeResult(
                        game: Game.wordle,
                        date: played,
                        score: nil,
                        completed: false
                    )
                ]
            )
        ])

        let rows = viewModel.exportCSV().components(separatedBy: "\n")

        let stamp = ISO8601DateFormatter().string(from: played)
        XCTAssertEqual(rows.last, "\(stamp),Wordle,,6,false")
    }

    /// The CSV is memoised against `analyticsData.lastUpdated`. Dropping that key from
    /// the cache check would hand back the previous export after a refresh.
    func test_exportCSV_invalidatesItsCacheWhenTheDataIsReplaced() {
        let viewModel = AnalyticsFeatureFixtures.makeViewModel()
        let played = Date(timeIntervalSince1970: 1_700_000_000)
        let single = AnalyticsFeatureFixtures.makeData(gameAnalytics: [
            AnalyticsFeatureFixtures.makeGameAnalytics(
                game: Game.wordle,
                totalGamesPlayed: 1,
                recentResults: [AnalyticsFeatureFixtures.makeResult(game: Game.wordle, date: played, score: 4)]
            )
        ])
        viewModel.analyticsData = single
        let firstExport = viewModel.exportCSV()

        let pair = AnalyticsFeatureFixtures.makeData(gameAnalytics: [
            AnalyticsFeatureFixtures.makeGameAnalytics(
                game: Game.wordle,
                totalGamesPlayed: 2,
                recentResults: [
                    AnalyticsFeatureFixtures.makeResult(game: Game.wordle, date: played, score: 4),
                    AnalyticsFeatureFixtures.makeResult(game: Game.wordle, date: played, score: 2)
                ]
            )
        ])
        XCTAssertNotEqual(single.lastUpdated, pair.lastUpdated, "Precondition: the two payloads are distinguishable")
        viewModel.analyticsData = pair

        let secondExport = viewModel.exportCSV()

        XCTAssertNotEqual(firstExport, secondExport)
        XCTAssertEqual(secondExport.components(separatedBy: "\n").count, 3)
    }
}
