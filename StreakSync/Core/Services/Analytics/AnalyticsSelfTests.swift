////
////  AnalyticsSelfTests.swift (DEBUG ONLY)
////  StreakSync
////
////  Lightweight self-tests that exercise analytics calculations without a test target.
////
//
///*
// * ANALYTICSSELFTESTS - DEBUG-ONLY ANALYTICS VALIDATION AND TESTING
// * 
// * WHAT THIS FILE DOES:
// * This file provides lightweight self-tests that validate analytics calculations
// * during development without requiring a separate test target. It's like a
// * "analytics validator" that creates synthetic data and verifies that the
// * analytics system works correctly. Think of it as the "analytics quality
// * assurance tool" that ensures the analytics engine produces accurate results
// * for different scenarios and data patterns.
// * 
// * WHY IT EXISTS:
// * Analytics calculations are complex and need to be validated to ensure they
// * produce accurate results. This self-test system allows developers to quickly
// * verify that analytics work correctly during development without setting up
// * a full testing framework. It's particularly useful for catching analytics
// * bugs early in the development process.
// * 
// * IMPORTANCE TO APPLICATION:
// * - CRITICAL: This ensures analytics calculations are accurate and reliable
// * - Validates analytics logic with synthetic test data
// * - Tests different analytics scenarios and edge cases
// * - Provides quick feedback during development
// * - Ensures analytics consistency across different data patterns
// * - Helps catch analytics bugs before they reach users
// * - Supports development workflow with immediate validation
// * 
// * WHAT IT REFERENCES:
// * - Foundation: For basic data types and logging
// * - OSLog: For logging and debugging
// * - AppState: For accessing game data and analytics
// * - AnalyticsService: The analytics system being tested
// * - GameResult: Test data for analytics validation
// * 
// * WHAT REFERENCES IT:
// * - Development workflow: Developers can call this during development
// * - Analytics system: This validates the analytics calculations
// * - Debug builds: This only runs in debug mode for development
// * - Quality assurance: This ensures analytics accuracy
// * 
// * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
// * 
// * 1. TEST COVERAGE IMPROVEMENTS:
// *    - The current tests are good but could be more comprehensive
// *    - Consider adding more test scenarios and edge cases
// *    - Add tests for different game types and scoring models
// *    - Test analytics with various data patterns and volumes
// * 
// * 2. TEST DATA IMPROVEMENTS:
// *    - The current test data is good but could be more varied
// *    - Consider adding more realistic test scenarios
// *    - Add tests with different user behavior patterns
// *    - Test with historical data patterns
// * 
// * 3. TEST ORGANIZATION IMPROVEMENTS:
// *    - The current organization is good but could be more modular
// *    - Consider separating tests by analytics type or scenario
// *    - Add helper methods for common test setup
// *    - Implement test data builders for complex scenarios
// * 
// * 4. ASSERTION IMPROVEMENTS:
// *    - The current assertions are good but could be more detailed
// *    - Consider adding more specific error messages
// *    - Add assertions for edge cases and boundary conditions
// *    - Test for performance characteristics
// * 
// * 5. TESTING STRATEGIES:
// *    - Add property-based testing for analytics consistency
// *    - Implement integration tests with real data
// *    - Add performance tests for large datasets
// *    - Test with different user scenarios
// * 
// * 6. DOCUMENTATION IMPROVEMENTS:
// *    - Add detailed documentation for test scenarios
// *    - Document the expected behavior for each test
// *    - Add examples of how to add new tests
// *    - Create testing guidelines for analytics
// * 
// * 7. TESTING TOOLS:
// *    - Consider adding test coverage reporting
// *    - Implement automated test result analysis
// *    - Add test performance monitoring
// *    - Use test data generation tools
// * 
// * 8. CONTINUOUS INTEGRATION:
// *    - Ensure tests run on every commit
// *    - Add test result reporting and notifications
// *    - Implement test failure analysis
// *    - Add test performance monitoring
// * 
// * LEARNING NOTES FOR BEGINNERS:
// * - Self-tests: Tests that run during development to validate functionality
// * - Analytics validation: Ensuring analytics calculations are correct
// * - Synthetic data: Fake data created specifically for testing
// * - Debug-only code: Code that only runs during development
// * - Quality assurance: Ensuring code works correctly and reliably
// * - Test coverage: Measuring how much of the code is tested
// * - Edge cases: Unusual or extreme scenarios that need testing
// * - Assertions: Statements that verify expected behavior
// * - Test data: Data used specifically for testing purposes
// * - Development workflow: The process of developing and testing code
// */
//
//#if DEBUG
//import Foundation
//import OSLog
//
//enum AnalyticsSelfTests {
//    static func runAll(with appState: AppState) {
//        let logger = Logger(subsystem: "com.streaksync.tests", category: "AnalyticsSelfTests")
//        logger.info("▶️ Running Analytics self-tests…")
//
//        // Build synthetic results for a known game (Wordle-like attempts model)
//        guard let wordle = appState.games.first(where: { $0.name.lowercased() == "wordle" }) ?? appState.games.first else {
//            logger.warning("No games available to test")
//            return
//        }
//
//        let now = Date()
//        let day = 24 * 60 * 60.0
//        let r1 = GameResult(
//            gameId: wordle.id,
//            gameName: wordle.name,
//            date: now.addingTimeInterval(-1 * day),
//            score: 3,
//            maxAttempts: 6,
//            completed: true,
//            sharedText: "Test Wordle 1 3/6",
//            parsedData: ["puzzleNumber": "1"]
//        )
//        let r2 = GameResult(
//            gameId: wordle.id,
//            gameName: wordle.name,
//            date: now.addingTimeInterval(-2 * day),
//            score: 5,
//            maxAttempts: 6,
//            completed: true,
//            sharedText: "Test Wordle 2 5/6",
//            parsedData: ["puzzleNumber": "2"]
//        )
//        let r3 = GameResult(
//            gameId: wordle.id,
//            gameName: wordle.name,
//            date: now.addingTimeInterval(-3 * day),
//            score: nil,
//            maxAttempts: 6,
//            completed: false,
//            sharedText: "Test Wordle 3 X/6",
//            parsedData: ["puzzleNumber": "3"]
//        )
//
//        let games = appState.games
//        let streaks = appState.streaks
//        let results = [r1, r2, r3]
//
//        // Overview
//        let overview = AnalyticsComputer.computeOverview(timeRange: .week, game: nil, games: games, streaks: streaks, results: results)
//        assert(overview.totalGamesPlayed == 3, "Overview totalGamesPlayed mismatch")
//        assert(overview.totalGamesCompleted == 2, "Overview totalGamesCompleted mismatch")
//        // With r1(-1d), r2(-2d), r3(-3d), longest streak in 7-day window should be 3
//        assert(overview.longestCurrentStreak == 3, "Longest streak (week) should be 3 for three consecutive days")
//
//        // Trends
//        let trends = AnalyticsComputer.computeStreakTrends(timeRange: .week, results: results)
//        assert(!trends.isEmpty, "Trends should not be empty for non-empty results")
//
//        // Today range has no results -> longest streak 0
//        let todayOverview = AnalyticsComputer.computeOverview(timeRange: .today, game: nil, games: games, streaks: streaks, results: results)
//        assert(todayOverview.longestCurrentStreak == 0, "Longest streak (today) should be 0 when no results today")
//
//        // Month and Year should reflect available consecutive days (3)
//        let monthOverview = AnalyticsComputer.computeOverview(timeRange: .month, game: nil, games: games, streaks: streaks, results: results)
//        assert(monthOverview.longestCurrentStreak == 3, "Longest streak (month) should be 3 with three consecutive days")
//        let yearOverview = AnalyticsComputer.computeOverview(timeRange: .year, game: nil, games: games, streaks: streaks, results: results)
//        assert(yearOverview.longestCurrentStreak == 3, "Longest streak (year) should be 3 with three consecutive days")
//
//        // Per-game analytics
//        if let ga = AnalyticsComputer.computeGameAnalytics(for: wordle.id, timeRange: .week, games: games, streaks: streaks, results: results) {
//            assert(ga.personalBest == 3, "Personal best should be lowest score (3)")
//            let avg = AnalyticsComputer.computeAverageScore(for: wordle.id, in: .week, results: results)
//            assert(avg > 0.0, "Average score should be > 0")
//        }
//
//        // Achievements analytics (tiered progress)
//        let tiered = [
//            TieredAchievement(
//                category: .streakMaster,
//                requirements: [TierRequirement(tier: .bronze, threshold: 3), TierRequirement(tier: .silver, threshold: 7)],
//                progress: AchievementProgress(currentValue: 3, currentTier: .bronze, tierUnlockDates: [.bronze: now.addingTimeInterval(-3600)], lastUpdated: now)
//            )
//        ]
//        let a = Achievement(title: "First Steps", description: "", iconSystemName: "star.fill", requirement: .firstGame, unlockedDate: now.addingTimeInterval(-7200))
//        let aa = AnalyticsComputer.computeAchievementAnalytics(achievements: [a], tieredAchievements: tiered)
//        assert(aa.totalUnlocked == 1, "Unlocked achievements should be 1")
//        assert(!aa.tierDistribution.isEmpty, "Tier distribution should not be empty")
//
//        logger.info("✅ Analytics self-tests passed")
//
//        // --- Additional self-tests for streak trends ---
//        // Ensure 'today' shows active streaks when a game is played today
//        let rToday = GameResult(
//            gameId: wordle.id,
//            gameName: wordle.name,
//            date: now,
//            score: 3,
//            maxAttempts: 6,
//            completed: true,
//            sharedText: "Test Wordle Today 3/6",
//            parsedData: ["puzzleNumber": "999"]
//        )
//        let todayTrends = AnalyticsComputer.computeStreakTrends(timeRange: .today, results: results + [rToday])
//        if let last = todayTrends.last {
//            assert(last.totalActiveStreaks >= 1, "Today should report at least 1 active streak when a game is played today")
//        }
//
//        // Week peak with two different games on the same day should be at least 2
//        let secondGameId = UUID()
//        let rTodayOther = GameResult(
//            gameId: secondGameId,
//            gameName: "TestGame2",
//            date: now,
//            score: 2,
//            maxAttempts: 6,
//            completed: true,
//            sharedText: "Test Game 2 Today 2/6",
//            parsedData: [:]
//        )
//        let weekTrends = AnalyticsComputer.computeStreakTrends(timeRange: .week, results: results + [rToday, rTodayOther])
//        let peakActive = weekTrends.map { $0.totalActiveStreaks }.max() ?? 0
//        assert(peakActive >= 2, "Week peak active streaks should be at least 2 when two games were played the same day")
//
//        // --- Personal bests time-range scoping ---
//        // Old result 20 days ago should be ignored in 7-day window personal bests
//        let oldResult = GameResult(
//            gameId: wordle.id,
//            gameName: wordle.name,
//            date: now.addingTimeInterval(-20 * 24 * 60 * 60),
//            score: 1,
//            maxAttempts: 6,
//            completed: true,
//            sharedText: "Old perfect score",
//            parsedData: [:]
//        )
//        let sevenDayBests = AnalyticsComputer.computePersonalBests(timeRange: .week, game: nil, games: games, streaks: streaks, results: results + [oldResult])
//        // Best Score should not reflect the old perfect score within 7-day window
//        let hasPerfectScore = sevenDayBests.contains { $0.type == .bestScore && $0.value == 1 }
//        assert(!hasPerfectScore, "7-day best score should ignore results older than 7 days")
//        // Today personal bests should have longest streak <= 1 for Wordle when only today is played
//        let todayBests = AnalyticsComputer.computePersonalBests(timeRange: .today, game: nil, games: games, streaks: streaks, results: results + [rToday])
//        if let ls = todayBests.first(where: { $0.type == .longestStreak && ($0.game?.id == wordle.id) }) {
//            assert(ls.value <= 1, "Today's longest streak per game must be at most 1")
//        }
//    }
//}
//#endif
//
//
