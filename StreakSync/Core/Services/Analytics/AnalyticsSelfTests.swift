//
//  AnalyticsSelfTests.swift (DEBUG ONLY)
//  StreakSync
//
//  Lightweight self-tests that exercise analytics calculations without a test target.
//

#if DEBUG
import Foundation
import OSLog

enum AnalyticsSelfTests {
    static func runAll(with appState: AppState) {
        let logger = Logger(subsystem: "com.streaksync.tests", category: "AnalyticsSelfTests")
        logger.info("▶️ Running Analytics self-tests…")

        // Build synthetic results for a known game (Wordle-like attempts model)
        guard let wordle = appState.games.first(where: { $0.name.lowercased() == "wordle" }) ?? appState.games.first else {
            logger.warning("No games available to test")
            return
        }

        let now = Date()
        let day = 24 * 60 * 60.0
        let r1 = GameResult(
            gameId: wordle.id,
            gameName: wordle.name,
            date: now.addingTimeInterval(-1 * day),
            score: 3,
            maxAttempts: 6,
            completed: true,
            sharedText: "Test Wordle 1 3/6",
            parsedData: ["puzzleNumber": "1"]
        )
        let r2 = GameResult(
            gameId: wordle.id,
            gameName: wordle.name,
            date: now.addingTimeInterval(-2 * day),
            score: 5,
            maxAttempts: 6,
            completed: true,
            sharedText: "Test Wordle 2 5/6",
            parsedData: ["puzzleNumber": "2"]
        )
        let r3 = GameResult(
            gameId: wordle.id,
            gameName: wordle.name,
            date: now.addingTimeInterval(-3 * day),
            score: nil,
            maxAttempts: 6,
            completed: false,
            sharedText: "Test Wordle 3 X/6",
            parsedData: ["puzzleNumber": "3"]
        )

        let games = appState.games
        let streaks = appState.streaks
        let results = [r1, r2, r3]

        // Overview
        let overview = AnalyticsComputer.computeOverview(timeRange: .week, game: nil, games: games, streaks: streaks, results: results)
        assert(overview.totalGamesPlayed == 3, "Overview totalGamesPlayed mismatch")
        assert(overview.totalGamesCompleted == 2, "Overview totalGamesCompleted mismatch")

        // Trends
        let trends = AnalyticsComputer.computeStreakTrends(timeRange: .week, results: results)
        assert(!trends.isEmpty, "Trends should not be empty for non-empty results")

        // Per-game analytics
        if let ga = AnalyticsComputer.computeGameAnalytics(for: wordle.id, timeRange: .week, games: games, streaks: streaks, results: results) {
            assert(ga.personalBest == 3, "Personal best should be lowest score (3)")
            let avg = AnalyticsComputer.computeAverageScore(for: wordle.id, in: .week, results: results)
            assert(avg > 0.0, "Average score should be > 0")
        }

        // Achievements analytics (tiered progress)
        let tiered = [
            TieredAchievement(
                category: .streakMaster,
                requirements: [TierRequirement(tier: .bronze, threshold: 3), TierRequirement(tier: .silver, threshold: 7)],
                progress: AchievementProgress(currentValue: 3, currentTier: .bronze, tierUnlockDates: [.bronze: now.addingTimeInterval(-3600)], lastUpdated: now)
            )
        ]
        let a = Achievement(title: "First Steps", description: "", iconSystemName: "star.fill", requirement: .firstGame, unlockedDate: now.addingTimeInterval(-7200))
        let aa = AnalyticsComputer.computeAchievementAnalytics(achievements: [a], tieredAchievements: tiered)
        assert(aa.totalUnlocked == 1, "Unlocked achievements should be 1")
        assert(!aa.tierDistribution.isEmpty, "Tier distribution should not be empty")

        logger.info("✅ Analytics self-tests passed")
    }
}
#endif


