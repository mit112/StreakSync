//
//  AnalyticsFeatureFixtures.swift
//  StreakSyncTests
//
//  Shared builders for Analytics feature view-model tests.
//

import Foundation
@testable import StreakSync

/// Fixtures for `AnalyticsViewModel` tests.
///
/// Every `GameResult` here is built from a real catalog game so the score always
/// satisfies that game's scoring model — `GameResult.init` asserts on a mismatch in
/// Debug and takes down the whole test host when it trips.
enum AnalyticsFeatureFixtures {
    /// A view model backed by an in-memory `AppState` — no Firestore, no UserDefaults writes
    /// beyond the analytics scope key, which the tests clear in `setUp`/`tearDown`.
    @MainActor
    static func makeViewModel() -> AnalyticsViewModel {
        let appState = AppState(persistenceService: MockPersistenceService())
        return AnalyticsViewModel(analyticsService: AnalyticsService(appState: appState))
    }

    /// Removes the persisted `AnalyticsScope` so a fresh view model starts at
    /// `.week` / All Games regardless of what a previous test or the real app left behind.
    static func clearSavedScope() {
        UserDefaults.standard.removeObject(forKey: AnalyticsScope.userDefaultsKey)
    }

    // MARK: - Model Builders

    /// `GameStreak.init` clamps `maxStreak` up to `currentStreak`, so callers must pass
    /// `currentStreak <= maxStreak` for the two values to stay distinct.
    static func makeStreak(
        game: Game,
        currentStreak: Int,
        maxStreak: Int,
        totalGamesPlayed: Int,
        lastPlayedDate: Date? = Date()
    ) -> GameStreak {
        GameStreak(
            gameId: game.id,
            gameName: game.name,
            currentStreak: currentStreak,
            maxStreak: maxStreak,
            totalGamesPlayed: totalGamesPlayed,
            totalGamesCompleted: totalGamesPlayed,
            lastPlayedDate: lastPlayedDate,
            streakStartDate: lastPlayedDate
        )
    }

    static func makeGameAnalytics(
        game: Game,
        currentStreak: Int = 0,
        maxStreak: Int = 0,
        totalGamesPlayed: Int = 0,
        recentResults: [GameResult] = []
    ) -> GameAnalytics {
        GameAnalytics(
            game: game,
            streak: makeStreak(
                game: game,
                currentStreak: currentStreak,
                maxStreak: maxStreak,
                totalGamesPlayed: totalGamesPlayed
            ),
            recentResults: recentResults
        )
    }

    static func makeData(
        overview: AnalyticsOverview = AnalyticsOverview(),
        streakTrends: [StreakTrendPoint] = [],
        gameAnalytics: [GameAnalytics] = []
    ) -> AnalyticsData {
        AnalyticsData(
            overview: overview,
            streakTrends: streakTrends,
            gameAnalytics: gameAnalytics
        )
    }

    /// `maxAttempts` defaults to 6, which is legal for Wordle's `.lowerAttempts` model
    /// (scores 1...6) and unconstrained for the `.higherIsBetter` games.
    static func makeResult(
        game: Game,
        date: Date,
        score: Int?,
        maxAttempts: Int = 6,
        completed: Bool = true
    ) -> GameResult {
        GameResult(
            gameId: game.id,
            gameName: game.name,
            date: date,
            score: score,
            maxAttempts: maxAttempts,
            completed: completed,
            sharedText: "Fixture result"
        )
    }

    static func makeTrendPoint(
        daysAgo: Int,
        totalActiveStreaks: Int,
        longestStreak: Int = 0,
        gamesPlayed: Int = 0,
        gamesCompleted: Int = 0
    ) -> StreakTrendPoint {
        let today = Calendar.current.startOfDay(for: Date())
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        return StreakTrendPoint(
            date: date,
            totalActiveStreaks: totalActiveStreaks,
            longestStreak: longestStreak,
            gamesPlayed: gamesPlayed,
            gamesCompleted: gamesCompleted
        )
    }
}
