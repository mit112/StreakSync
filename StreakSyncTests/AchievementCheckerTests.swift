import XCTest
@testable import StreakSync

@MainActor
final class AchievementCheckerTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    private let checker = TieredAchievementChecker()
    
    private func makeResult(
        gameId: UUID = UUID(),
        gameName: String = "Test",
        date: Date = Date(),
        score: Int = 1,
        maxAttempts: Int = 6,
        completed: Bool = true
    ) -> GameResult {
        GameResult(id: UUID(), gameId: gameId, gameName: gameName, date: date, score: score, maxAttempts: maxAttempts, completed: completed, sharedText: "Test result", parsedData: [:])
    }
    
    private func dayOffset(_ days: Int, from base: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: base)!
    }
    
    private func hourOffset(_ hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
    }
    
    private func makeStreak(for game: Game, currentStreak: Int) -> GameStreak {
        GameStreak(
            gameId: game.id,
            gameName: game.name,
            currentStreak: currentStreak,
            maxStreak: currentStreak,
            totalGamesPlayed: currentStreak,
            totalGamesCompleted: currentStreak,
            lastPlayedDate: Date(),
            streakStartDate: Date()
        )
    }
    
    // MARK: - Streak Master
    
    func testStreakMasterUnlocksSilverAt7() {
        let app = AppState()
        let game = app.games.first!
        let streak = makeStreak(for: game, currentStreak: 7)
        var achievements = [AchievementFactory.createStreakMasterAchievement()]
        let result = makeResult(gameId: game.id, gameName: game.name)
        
        let unlocks = checker.checkAllAchievements(for: result, allResults: [result], streaks: [streak], games: app.games, currentAchievements: &achievements)
        
        XCTAssertEqual(achievements[0].progress.currentTier, .silver)
        XCTAssertEqual(unlocks.count, 1)
        XCTAssertEqual(unlocks.first?.tier, .silver)
    }
    
    func testStreakMasterNoUnlockBelow3() {
        let app = AppState()
        let game = app.games.first!
        let streak = makeStreak(for: game, currentStreak: 2)
        var achievements = [AchievementFactory.createStreakMasterAchievement()]
        let result = makeResult(gameId: game.id, gameName: game.name)
        
        let unlocks = checker.checkAllAchievements(for: result, allResults: [result], streaks: [streak], games: app.games, currentAchievements: &achievements)
        
        XCTAssertNil(achievements[0].progress.currentTier)
        XCTAssertTrue(unlocks.isEmpty)
    }
    
    func testStreakMasterProgressiveTiers() {
        let app = AppState()
        let game = app.games.first!
        var achievements = [AchievementFactory.createStreakMasterAchievement()]
        let result = makeResult(gameId: game.id, gameName: game.name)
        
        // Bronze at 3
        var streak = makeStreak(for: game, currentStreak: 3)
        _ = checker.checkAllAchievements(for: result, allResults: [result], streaks: [streak], games: app.games, currentAchievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentTier, .bronze)
        
        // Gold at 14
        streak = makeStreak(for: game, currentStreak: 14)
        _ = checker.checkAllAchievements(for: result, allResults: [result], streaks: [streak], games: app.games, currentAchievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentTier, .gold)
        
        // Legendary at 100
        streak = makeStreak(for: game, currentStreak: 100)
        _ = checker.checkAllAchievements(for: result, allResults: [result], streaks: [streak], games: app.games, currentAchievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentTier, .legendary)
    }
    
    // MARK: - Game Collector
    
    func testGameCollectorCountsAllResults() {
        var achievements = [AchievementFactory.createGameCollectorAchievement()]
        let results = (0..<10).map { _ in makeResult() }
        let result = results.last!
        
        let unlocks = checker.checkAllAchievements(for: result, allResults: results, streaks: [], games: [], currentAchievements: &achievements)
        
        XCTAssertEqual(achievements[0].progress.currentValue, 10)
        XCTAssertEqual(achievements[0].progress.currentTier, .bronze)
        XCTAssertFalse(unlocks.isEmpty)
    }
    
    // MARK: - Daily Devotee
    
    func testDailyDevoteeCountsConsecutiveDays() {
        let app = AppState()
        let gid = app.games.first!.id
        let now = Date()
        var achievements = [AchievementFactory.createDailyDevoteeAchievement()]
        let results = [
            makeResult(gameId: gid, date: dayOffset(-2, from: now)),
            makeResult(gameId: gid, date: dayOffset(-1, from: now)),
            makeResult(gameId: gid, date: now),
        ]
        
        _ = checker.checkAllAchievements(for: results.last!, allResults: results, streaks: [], games: app.games, currentAchievements: &achievements)
        
        XCTAssertEqual(achievements[0].progress.currentTier, .bronze)
    }
    
    func testDailyDevoteeResetsByGap() {
        let app = AppState()
        let gid = app.games.first!.id
        let now = Date()
        var achievements = [AchievementFactory.createDailyDevoteeAchievement()]
        let results = [
            makeResult(gameId: gid, date: dayOffset(-5, from: now)),
            makeResult(gameId: gid, date: dayOffset(-4, from: now)),
            makeResult(gameId: gid, date: dayOffset(-1, from: now)),
            makeResult(gameId: gid, date: now),
        ]
        
        _ = checker.checkAllAchievements(for: results.last!, allResults: results, streaks: [], games: app.games, currentAchievements: &achievements)
        
        XCTAssertNil(achievements[0].progress.currentTier)
    }
    
    // MARK: - Variety Player
    
    func testVarietyPlayerCountsUniqueGames() {
        let app = AppState()
        let now = Date()
        let g1 = app.games[0]; let g2 = app.games[1]; let g3 = app.games[2]
        var achievements = [AchievementFactory.createVarietyPlayerAchievement()]
        let results = [
            makeResult(gameId: g1.id, gameName: g1.name, date: dayOffset(-2, from: now)),
            makeResult(gameId: g2.id, gameName: g2.name, date: dayOffset(-1, from: now)),
            makeResult(gameId: g3.id, gameName: g3.name, date: now),
        ]
        
        _ = checker.checkAllAchievements(for: results.last!, allResults: results, streaks: [], games: app.games, currentAchievements: &achievements)
        
        XCTAssertEqual(achievements[0].progress.currentValue, 3)
        XCTAssertEqual(achievements[0].progress.currentTier, .bronze)
    }
    
    func testVarietyPlayerMonotonicDoesNotDecrease() {
        let app = AppState()
        let now = Date()
        let g1 = app.games[0]; let g2 = app.games[1]; let g3 = app.games[2]
        var achievements = [AchievementFactory.createVarietyPlayerAchievement()]
        let results3 = [
            makeResult(gameId: g1.id, date: dayOffset(-2, from: now)),
            makeResult(gameId: g2.id, date: dayOffset(-1, from: now)),
            makeResult(gameId: g3.id, date: now),
        ]
        _ = checker.checkAllAchievements(for: results3.last!, allResults: results3, streaks: [], games: app.games, currentAchievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentValue, 3)
        
        let r4 = makeResult(gameId: g1.id, date: dayOffset(1, from: now))
        _ = checker.checkAllAchievements(for: r4, allResults: results3 + [r4], streaks: [], games: app.games, currentAchievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentValue, 3)
    }
    
    // MARK: - Perfectionist
    
    func testPerfectionistCountsSuccessfulOnly() {
        var achievements = [AchievementFactory.createPerfectionistAchievement()]
        let results = (0..<5).map { _ in makeResult(completed: true) } +
                      (0..<3).map { _ in makeResult(completed: false) }
        
        _ = checker.checkAllAchievements(for: results.first!, allResults: results, streaks: [], games: [], currentAchievements: &achievements)
        
        XCTAssertEqual(achievements[0].progress.currentValue, 5)
        XCTAssertEqual(achievements[0].progress.currentTier, .bronze)
    }
    
    // MARK: - Time-Based Achievements
    
    func testEarlyBirdCountsMorningPlays() {
        var achievements = [AchievementFactory.createEarlyBirdAchievement()]
        let earlyResults = (0..<3).map { _ in makeResult(date: hourOffset(6)) }
        let lateResults = [makeResult(date: hourOffset(14))]
        let all = earlyResults + lateResults
        
        _ = checker.checkAllAchievements(for: all.first!, allResults: all, streaks: [], games: [], currentAchievements: &achievements)
        
        XCTAssertEqual(achievements[0].progress.currentValue, 3)
    }
    
    func testNightOwlCountsLateNightPlays() {
        var achievements = [AchievementFactory.createNightOwlAchievement()]
        let lateResults = (0..<2).map { _ in makeResult(date: hourOffset(2)) }
        let dayResults = [makeResult(date: hourOffset(12))]
        let all = lateResults + dayResults
        
        _ = checker.checkAllAchievements(for: all.first!, allResults: all, streaks: [], games: [], currentAchievements: &achievements)
        
        XCTAssertEqual(achievements[0].progress.currentValue, 2)
    }
    
    func testEarlyBirdExcludesBoundary() {
        var achievements = [AchievementFactory.createEarlyBirdAchievement()]
        let result = makeResult(date: hourOffset(9))
        
        _ = checker.checkAllAchievements(for: result, allResults: [result], streaks: [], games: [], currentAchievements: &achievements)
        
        XCTAssertEqual(achievements[0].progress.currentValue, 0)
    }
    
    // MARK: - Marathon Runner
    
    func testMarathonRunnerCountsUniqueDays() {
        var achievements = [AchievementFactory.createMarathonRunnerAchievement()]
        let now = Date()
        let results = (0..<5).flatMap { dayIdx in
            (0..<2).map { _ in makeResult(date: dayOffset(-dayIdx, from: now)) }
        }
        
        _ = checker.checkAllAchievements(for: results.first!, allResults: results, streaks: [], games: [], currentAchievements: &achievements)
        
        XCTAssertEqual(achievements[0].progress.currentValue, 5)
    }
    
    // MARK: - Comeback Champion
    
    func testComebackChampionCountsGaps() {
        let gameId = UUID()
        let now = Date()
        var achievements = [AchievementFactory.createComebackChampionAchievement()]
        let results = [
            makeResult(gameId: gameId, date: dayOffset(-6, from: now)),
            makeResult(gameId: gameId, date: dayOffset(-5, from: now)),
            makeResult(gameId: gameId, date: dayOffset(-1, from: now)),
            makeResult(gameId: gameId, date: now),
        ]
        
        _ = checker.checkAllAchievements(for: results.last!, allResults: results, streaks: [], games: [], currentAchievements: &achievements)
        
        XCTAssertEqual(achievements[0].progress.currentValue, 1)
        XCTAssertEqual(achievements[0].progress.currentTier, .bronze)
    }
    
    // MARK: - Progress Percentage
    
    func testPercentageToNextTierFromZero() {
        let requirements = [
            TierRequirement(tier: .bronze, threshold: 10),
            TierRequirement(tier: .silver, threshold: 20),
        ]
        let progress = AchievementProgress(currentValue: 5, currentTier: nil)
        
        XCTAssertEqual(progress.percentageToNextTier(requirements: requirements), 0.5, accuracy: 0.01)
    }
    
    func testPercentageToNextTierFromBronze() {
        let requirements = [
            TierRequirement(tier: .bronze, threshold: 10),
            TierRequirement(tier: .silver, threshold: 20),
        ]
        let progress = AchievementProgress(currentValue: 15, currentTier: .bronze)
        
        XCTAssertEqual(progress.percentageToNextTier(requirements: requirements), 0.5, accuracy: 0.01)
    }
    
    func testPercentageMaxTierReturns1() {
        let requirements = [TierRequirement(tier: .bronze, threshold: 10)]
        let progress = AchievementProgress(currentValue: 10, currentTier: .bronze)
        
        // No next tier → 0.0 (nothing to progress toward)
        XCTAssertEqual(progress.percentageToNextTier(requirements: requirements), 0.0)
    }
    
    // MARK: - Recalculation with cached unique games
    
    func testVarietyPlayerUsesUnionWithCachedSetOnRecalc() {
        let app = AppState()
        let g1 = app.games[0]; let g2 = app.games[1]; let gExtra = app.games[3]
        let now = Date()
        app.recentResults = [
            makeResult(gameId: g1.id, gameName: g1.name, date: now),
            makeResult(gameId: g2.id, gameName: g2.name, date: now),
        ]
        app._uniqueGamesEver = [g1.id, g2.id, gExtra.id]
        
        app.recalculateAllTieredAchievementProgress()
        
        let varAch = app.tieredAchievements.first { $0.category == .varietyPlayer }
        XCTAssertEqual(varAch?.progress.currentValue, 3)
    }
}
