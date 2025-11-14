/*
 * ACHIEVEMENTCHECKERTESTS - ACHIEVEMENT SYSTEM VALIDATION
 * 
 * WHAT THIS FILE DOES:
 * This file tests the achievement system to make sure it works correctly. It's like a "quality
 * control inspector" that checks if achievements unlock at the right times and with the right
 * conditions. Think of it as automated testing that ensures the achievement system is fair,
 * consistent, and bug-free. It tests specific scenarios like streak milestones and consecutive
 * day tracking to make sure users get the rewards they deserve.
 * 
 * WHY IT EXISTS:
 * Testing is crucial for any app feature, especially something as important as achievements.
 * Without tests, bugs in the achievement system could cause users to miss rewards or get
 * achievements they didn't earn. This file ensures that the achievement logic works correctly
 * and that changes to the code don't break existing functionality.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: Ensures the achievement system works correctly and fairly
 * - Validates that achievements unlock at the right milestones
 * - Tests edge cases and boundary conditions
 * - Prevents regressions when code is changed
 * - Provides confidence in the achievement system's reliability
 * - Documents expected behavior through test cases
 * 
 * WHAT IT REFERENCES:
 * - XCTest: iOS testing framework for unit tests
 * - StreakSync: The main app module being tested
 * - AppState: For creating test data and app state
 * - TieredAchievementChecker: The main component being tested
 * - AchievementFactory: For creating test achievements
 * - GameResult, GameStreak: Test data models
 * 
 * WHAT REFERENCES IT:
 * - Xcode: Runs these tests during development and CI/CD
 * - Test runners: Execute these tests to validate the app
 * - Developers: Use these tests to understand expected behavior
 * - CI/CD systems: Run these tests automatically before deployment
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. TEST COVERAGE IMPROVEMENTS:
 *    - The current tests are basic - could be more comprehensive
 *    - Add tests for all achievement types and edge cases
 *    - Test achievement progress tracking and tier upgrades
 *    - Add tests for achievement unlock timing and conditions
 * 
 * 2. TEST DATA IMPROVEMENTS:
 *    - The current test data is minimal - could be more realistic
 *    - Create comprehensive test data sets
 *    - Add helper methods for creating test scenarios
 *    - Implement test data factories for different achievement types
 * 
 * 3. TEST ORGANIZATION:
 *    - The current tests are in one file - could be better organized
 *    - Consider separating into: StreakTests.swift, GameTests.swift, SpeedTests.swift
 *    - Group related tests together
 *    - Add descriptive test names and documentation
 * 
 * 4. ASSERTION IMPROVEMENTS:
 *    - The current assertions are basic - could be more specific
 *    - Add more detailed assertions for achievement progress
 *    - Test achievement metadata and unlock timestamps
 *    - Validate achievement tier progression
 * 
 * 5. TESTING STRATEGIES:
 *    - Add property-based testing for achievement logic
 *    - Implement integration tests with real data
 *    - Add performance tests for large datasets
 *    - Test achievement system under stress conditions
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for each test
 *    - Document the test scenarios and expected outcomes
 *    - Add examples of how to run and interpret tests
 *    - Create test coverage reports
 * 
 * 7. TESTING TOOLS:
 *    - Consider using additional testing frameworks
 *    - Add mocking for external dependencies
 *    - Implement test data builders
 *    - Add test utilities for common scenarios
 * 
 * 8. CONTINUOUS INTEGRATION:
 *    - Add automated test running
 *    - Implement test result reporting
 *    - Add test coverage monitoring
 *    - Set up test failure notifications
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Unit testing: Testing individual components in isolation
 * - XCTest: Apple's testing framework for iOS apps
 * - Test cases: Individual test scenarios that validate specific behavior
 * - Assertions: Statements that check if expected conditions are met
 * - Test data: Sample data used to test functionality
 * - Edge cases: Unusual or boundary conditions that might cause problems
 * - Regression testing: Ensuring changes don't break existing functionality
 * - Test coverage: How much of the code is tested by the test suite
 */

import XCTest
@testable import StreakSync

final class AchievementCheckerTests: XCTestCase {
    func testStreakMasterUnlocks() throws {
        let app = AppState()
        var ach = AchievementFactory.createStreakMasterAchievement()
        var tiered = [ach]
        let streaks = [GameStreak.empty(for: app.games.first!)]
        var s = streaks[0]
        s.currentStreak = 7
        let checker = TieredAchievementChecker()
        let result = GameResult(id: UUID(), gameId: app.games.first!.id, gameName: app.games.first!.name, score: 1, maxAttempts: 6, completed: true, date: Date(), sharedText: "", parsedData: [:])
        var current = tiered
        let _ = checker.checkAllAchievements(for: result, allResults: [result], streaks: [s], games: app.games, currentAchievements: &current)
        XCTAssertEqual(current[0].progress.currentTier, .silver)
    }
    
    func testDailyDevoteeCountsConsecutiveDays() throws {
        let app = AppState()
        var ach = AchievementFactory.createDailyDevoteeAchievement()
        var tiered = [ach]
        let checker = TieredAchievementChecker()
        let gid = app.games.first!.id
        let now = Date()
        let cal = Calendar.current
        let r0 = GameResult(id: UUID(), gameId: gid, gameName: "Test", score: 1, maxAttempts: 6, completed: true, date: now, sharedText: "", parsedData: [:])
        let r1 = GameResult(id: UUID(), gameId: gid, gameName: "Test", score: 1, maxAttempts: 6, completed: true, date: cal.date(byAdding: .day, value: -1, to: now)!, sharedText: "", parsedData: [:])
        var current = tiered
        let _ = checker.checkAllAchievements(for: r0, allResults: [r1, r0], streaks: [], games: app.games, currentAchievements: &current)
        XCTAssertNotNil(current.first!.progress.currentTier)
    }
    
    func testVarietyPlayerCountsAllTimeUniqueAcrossDays() throws {
        let app = AppState()
        var ach = AchievementFactory.createVarietyPlayerAchievement()
        var tiered = [ach]
        let checker = TieredAchievementChecker()
        let cal = Calendar.current
        let now = Date()
        let g1 = app.games[0]; let g2 = app.games[1]; let g3 = app.games[2]
        let r1 = GameResult(id: UUID(), gameId: g1.id, gameName: g1.name, score: 1, maxAttempts: 6, completed: true, date: cal.date(byAdding: .day, value: -2, to: now)!, sharedText: "r1", parsedData: [:])
        let r2 = GameResult(id: UUID(), gameId: g2.id, gameName: g2.name, score: 1, maxAttempts: 6, completed: true, date: cal.date(byAdding: .day, value: -1, to: now)!, sharedText: "r2", parsedData: [:])
        let r3 = GameResult(id: UUID(), gameId: g3.id, gameName: g3.name, score: 1, maxAttempts: 6, completed: true, date: now, sharedText: "r3", parsedData: [:])
        var current = tiered
        let _ = checker.checkAllAchievements(for: r3, allResults: [r1, r2, r3], streaks: [], games: app.games, currentAchievements: &current)
        XCTAssertEqual(current[0].progress.currentValue, 3)
    }
    
    func testVarietyPlayerMonotonicDoesNotDecrease() throws {
        let app = AppState()
        var ach = AchievementFactory.createVarietyPlayerAchievement()
        var tiered = [ach]
        let checker = TieredAchievementChecker()
        let cal = Calendar.current
        let now = Date()
        let g1 = app.games[0]; let g2 = app.games[1]; let g3 = app.games[2]
        let r1 = GameResult(id: UUID(), gameId: g1.id, gameName: g1.name, score: 1, maxAttempts: 6, completed: true, date: cal.date(byAdding: .day, value: -2, to: now)!, sharedText: "r1", parsedData: [:])
        let r2 = GameResult(id: UUID(), gameId: g2.id, gameName: g2.name, score: 1, maxAttempts: 6, completed: true, date: cal.date(byAdding: .day, value: -1, to: now)!, sharedText: "r2", parsedData: [:])
        var current = tiered
        // First compute with three unique games
        let r3 = GameResult(id: UUID(), gameId: g3.id, gameName: g3.name, score: 1, maxAttempts: 6, completed: true, date: now, sharedText: "r3", parsedData: [:])
        let _ = checker.checkAllAchievements(for: r3, allResults: [r1, r2, r3], streaks: [], games: app.games, currentAchievements: &current)
        XCTAssertEqual(current[0].progress.currentValue, 3)
        // Next day only one game (should not decrease progress)
        let nextDay = cal.date(byAdding: .day, value: 1, to: now)!
        let r4 = GameResult(id: UUID(), gameId: g1.id, gameName: g1.name, score: 1, maxAttempts: 6, completed: true, date: nextDay, sharedText: "r4", parsedData: [:])
        let _ = checker.checkAllAchievements(for: r4, allResults: [r1, r2, r3, r4], streaks: [], games: app.games, currentAchievements: &current)
        XCTAssertEqual(current[0].progress.currentValue, 3)
    }
    
    func testVarietyPlayerUsesUnionWithCachedSetOnRecalc() throws {
        let app = AppState()
        // Prepare results for 2 unique games
        let g1 = app.games[0]; let g2 = app.games[1]; let gExtra = app.games[3]
        let now = Date()
        let r1 = GameResult(id: UUID(), gameId: g1.id, gameName: g1.name, score: 1, maxAttempts: 6, completed: true, date: now, sharedText: "r1", parsedData: [:])
        let r2 = GameResult(id: UUID(), gameId: g2.id, gameName: g2.name, score: 1, maxAttempts: 6, completed: true, date: now, sharedText: "r2", parsedData: [:])
        app.recentResults = [r1, r2]
        // Simulate cached unique set containing an extra historical game
        app._uniqueGamesEver = [g1.id, g2.id, gExtra.id]
        // Recompute achievements
        app.recalculateAllTieredAchievementProgress()
        // Find variety player and ensure union count (3) is applied
        let varAch = app.tieredAchievements.first { $0.category == .varietyPlayer }
        XCTAssertNotNil(varAch)
        XCTAssertEqual(varAch?.progress.currentValue, 3)
    }
}


