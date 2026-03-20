@testable import StreakSync
import XCTest

@MainActor
class AchievementCheckerTests: XCTestCase {
    // MARK: - Test Helpers

    let checker = TieredAchievementChecker()

    func makeResult(
        gameId: UUID = UUID(),
        gameName: String = "Test",
        date: Date = Date(),
        score: Int = 1,
        maxAttempts: Int = 6,
        completed: Bool = true
    ) -> GameResult {
        GameResult(
            id: UUID(), gameId: gameId, gameName: gameName,
            date: date, score: score, maxAttempts: maxAttempts,
            completed: completed, sharedText: "Test result",
            parsedData: [:]
        )
    }

    func dayOffset(_ days: Int, from base: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: base) ?? base
    }

    func hourOffset(_ hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }

    func makeStreak(for game: Game, currentStreak: Int) -> GameStreak {
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

    /// Builds an AchievementSnapshot and calls checkAllAchievements.
    func check(
        results: [GameResult],
        streaks: [GameStreak] = [],
        games: [Game] = [],
        friendCount: Int = 0,
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        let snapshot = AchievementSnapshot.build(from: results, games: games, friendCount: friendCount)
        return checker.checkAllAchievements(
            snapshot: snapshot,
            streaks: streaks,
            currentAchievements: &achievements
        )
    }

    // MARK: - Streak Master (thresholds: 3/7/14/30/60)

    func testStreakMasterUnlocksSilverAt7() {
        let app = AppState()
        let game = app.games[0]
        let streak = makeStreak(for: game, currentStreak: 7)
        var achievements = [AchievementFactory.createStreakMasterAchievement()]
        let result = makeResult(gameId: game.id, gameName: game.name)

        let unlocks = check(results: [result], streaks: [streak], games: app.games, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentTier, .silver)
        XCTAssertEqual(unlocks.count, 1)
        XCTAssertEqual(unlocks.first?.tier, .silver)
    }

    func testStreakMasterNoUnlockBelow3() {
        let app = AppState()
        let game = app.games[0]
        let streak = makeStreak(for: game, currentStreak: 2)
        var achievements = [AchievementFactory.createStreakMasterAchievement()]
        let result = makeResult(gameId: game.id, gameName: game.name)

        let unlocks = check(results: [result], streaks: [streak], games: app.games, achievements: &achievements)

        XCTAssertNil(achievements[0].progress.currentTier)
        XCTAssertTrue(unlocks.isEmpty)
    }

    func testStreakMasterProgressiveTiers() {
        let app = AppState()
        let game = app.games[0]
        var achievements = [AchievementFactory.createStreakMasterAchievement()]
        let result = makeResult(gameId: game.id, gameName: game.name)

        // Bronze at 3
        var streak = makeStreak(for: game, currentStreak: 3)
        _ = check(results: [result], streaks: [streak], games: app.games, achievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentTier, .bronze)

        // Gold at 14
        streak = makeStreak(for: game, currentStreak: 14)
        _ = check(results: [result], streaks: [streak], games: app.games, achievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentTier, .gold)

        // Legendary at 60
        streak = makeStreak(for: game, currentStreak: 60)
        _ = check(results: [result], streaks: [streak], games: app.games, achievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentTier, .legendary)
    }

    // MARK: - Game Collector (thresholds: 10/25/50/100/250)

    func testGameCollectorCountsAllResults() {
        var achievements = [AchievementFactory.createGameCollectorAchievement()]
        let results = (0..<10).map { _ in makeResult() }

        let unlocks = check(results: results, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentValue, 10)
        XCTAssertEqual(achievements[0].progress.currentTier, .bronze)
        XCTAssertFalse(unlocks.isEmpty)
    }

    func testGameCollectorSilverAt25() {
        var achievements = [AchievementFactory.createGameCollectorAchievement()]
        let results = (0..<25).map { _ in makeResult() }

        _ = check(results: results, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentTier, .silver)
    }

    // MARK: - Daily Devotee (thresholds: 3/7/14/30/60)

    func testDailyDevoteeCountsConsecutiveDays() {
        let app = AppState()
        let gid = app.games[0].id
        let now = Date()
        var achievements = [AchievementFactory.createDailyDevoteeAchievement()]
        let results = [
            makeResult(gameId: gid, date: dayOffset(-2, from: now)),
            makeResult(gameId: gid, date: dayOffset(-1, from: now)),
            makeResult(gameId: gid, date: now)
        ]

        _ = check(results: results, games: app.games, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentTier, .bronze)
    }

    func testDailyDevoteeResetsByGap() {
        let app = AppState()
        let gid = app.games[0].id
        let now = Date()
        var achievements = [AchievementFactory.createDailyDevoteeAchievement()]
        let results = [
            makeResult(gameId: gid, date: dayOffset(-5, from: now)),
            makeResult(gameId: gid, date: dayOffset(-4, from: now)),
            makeResult(gameId: gid, date: dayOffset(-1, from: now)),
            makeResult(gameId: gid, date: now)
        ]

        _ = check(results: results, games: app.games, achievements: &achievements)

        XCTAssertNil(achievements[0].progress.currentTier)
    }

    // MARK: - Variety Player (thresholds: 3/5/8/12/16)

    func testVarietyPlayerCountsUniqueGames() {
        let app = AppState()
        let now = Date()
        let g1 = app.games[0]; let g2 = app.games[1]; let g3 = app.games[2]
        var achievements = [AchievementFactory.createVarietyPlayerAchievement()]
        let results = [
            makeResult(gameId: g1.id, gameName: g1.name, date: dayOffset(-2, from: now)),
            makeResult(gameId: g2.id, gameName: g2.name, date: dayOffset(-1, from: now)),
            makeResult(gameId: g3.id, gameName: g3.name, date: now)
        ]

        _ = check(results: results, games: app.games, achievements: &achievements)

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
            makeResult(gameId: g3.id, date: now)
        ]
        _ = check(results: results3, games: app.games, achievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentValue, 3)

        let r4 = makeResult(gameId: g1.id, date: dayOffset(1, from: now))
        _ = check(results: results3 + [r4], games: app.games, achievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentValue, 3)
    }

    // MARK: - Perfectionist (thresholds: 5/15/30/75/150)

    func testPerfectionistCountsSuccessfulOnly() {
        var achievements = [AchievementFactory.createPerfectionistAchievement()]
        let results = (0..<5).map { _ in makeResult(completed: true) } +
                      (0..<3).map { _ in makeResult(completed: false) }

        _ = check(results: results, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentValue, 5)
        XCTAssertEqual(achievements[0].progress.currentTier, .bronze)
    }

    // MARK: - Speed Demon (thresholds: 1/5/10/25/50)

    func testSpeedDemonCountsMinimalAttemptWins() {
        let app = AppState()
        let wordle = app.games.first { $0.name.lowercased() == "wordle" } ?? app.games[0]
        var achievements = [AchievementFactory.createSpeedDemonAchievement()]
        // Score of 1 on wordle = minimal attempt win
        let results = [makeResult(gameId: wordle.id, gameName: wordle.name, score: 1, completed: true)]

        _ = check(results: results, games: app.games, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentValue, 1)
        XCTAssertEqual(achievements[0].progress.currentTier, .bronze)
    }

    // MARK: - Marathon Runner (thresholds: 7/30/60/120/365)

    func testMarathonRunnerCountsUniqueDays() {
        var achievements = [AchievementFactory.createMarathonRunnerAchievement()]
        let now = Date()
        // 7 unique days → bronze
        let results = (0..<7).flatMap { dayIdx in
            (0..<2).map { _ in makeResult(date: dayOffset(-dayIdx, from: now)) }
        }

        _ = check(results: results, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentValue, 7)
        XCTAssertEqual(achievements[0].progress.currentTier, .bronze)
    }

    // MARK: - Personal Best (thresholds: 1/3/5/10/20)

    func testPersonalBestCountsImprovementsLowerIsBetter() {
        let app = AppState()
        let wordle = app.games.first { $0.name.lowercased() == "wordle" } ?? app.games[0]
        let now = Date()
        var achievements = [AchievementFactory.createPersonalBestAchievement()]
        // Score 5, then 3, then 2 = 2 personal bests (lower is better for Wordle)
        let results = [
            makeResult(gameId: wordle.id, gameName: wordle.name, date: dayOffset(-2, from: now), score: 5, completed: true),
            makeResult(gameId: wordle.id, gameName: wordle.name, date: dayOffset(-1, from: now), score: 3, completed: true),
            makeResult(gameId: wordle.id, gameName: wordle.name, date: now, score: 2, completed: true)
        ]

        _ = check(results: results, games: app.games, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentValue, 2)
    }

    func testPersonalBestHigherIsBetterGame() {
        let app = AppState()
        // Find a higherIsBetter game (e.g. Spelling Bee)
        guard let higherGame = app.games.first(where: { $0.scoringModel == .higherIsBetter }) else {
            XCTFail("No higherIsBetter game found in catalog")
            return
        }
        let now = Date()
        var achievements = [AchievementFactory.createPersonalBestAchievement()]
        // Higher scores are better: 50, then 75, then 60 = 1 personal best (75 beats 50)
        let results = [
            makeResult(gameId: higherGame.id, gameName: higherGame.name, date: dayOffset(-2, from: now), score: 50, maxAttempts: 100, completed: true),
            makeResult(gameId: higherGame.id, gameName: higherGame.name, date: dayOffset(-1, from: now), score: 75, maxAttempts: 100, completed: true),
            makeResult(gameId: higherGame.id, gameName: higherGame.name, date: now, score: 60, maxAttempts: 100, completed: true)
        ]

        _ = check(results: results, games: app.games, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentValue, 1)
    }

    func testPersonalBestIgnoresWorseScores() {
        let app = AppState()
        let wordle = app.games.first { $0.name.lowercased() == "wordle" } ?? app.games[0]
        let now = Date()
        var achievements = [AchievementFactory.createPersonalBestAchievement()]
        // Score 2, then 4 (worse for lowerIsBetter) = 0 personal bests
        let results = [
            makeResult(gameId: wordle.id, gameName: wordle.name, date: dayOffset(-1, from: now), score: 2, completed: true),
            makeResult(gameId: wordle.id, gameName: wordle.name, date: now, score: 4, completed: true)
        ]

        _ = check(results: results, games: app.games, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentValue, 0)
    }

    func testPersonalBestIgnoresFailedResults() {
        let app = AppState()
        let wordle = app.games.first { $0.name.lowercased() == "wordle" } ?? app.games[0]
        let now = Date()
        var achievements = [AchievementFactory.createPersonalBestAchievement()]
        let results = [
            makeResult(gameId: wordle.id, gameName: wordle.name, date: dayOffset(-2, from: now), score: 5, completed: true),
            makeResult(gameId: wordle.id, gameName: wordle.name, date: dayOffset(-1, from: now), score: 2, completed: false),
            makeResult(gameId: wordle.id, gameName: wordle.name, date: now, score: 1, completed: true)
        ]

        _ = check(results: results, games: app.games, achievements: &achievements)

        // Failed result skipped, score 1 beats score 5 = 1 PB
        XCTAssertEqual(achievements[0].progress.currentValue, 1)
    }

    func testPersonalBestAcrossMultipleGames() {
        let app = AppState()
        // Use two known lowerIsBetter games to ensure score direction is correct
        let lowerGames = app.games.filter { $0.scoringModel.isLowerBetter }
        guard lowerGames.count >= 2 else {
            XCTFail("Need at least 2 lowerIsBetter games")
            return
        }
        let g1 = lowerGames[0]; let g2 = lowerGames[1]
        let now = Date()
        var achievements = [AchievementFactory.createPersonalBestAchievement()]
        let results = [
            makeResult(gameId: g1.id, gameName: g1.name, date: dayOffset(-3, from: now), score: 5, completed: true),
            makeResult(gameId: g1.id, gameName: g1.name, date: dayOffset(-2, from: now), score: 3, completed: true),
            makeResult(gameId: g2.id, gameName: g2.name, date: dayOffset(-1, from: now), score: 4, completed: true),
            makeResult(gameId: g2.id, gameName: g2.name, date: now, score: 2, completed: true)
        ]

        _ = check(results: results, games: app.games, achievements: &achievements)

        // 1 personal best per game = 2 total
        XCTAssertEqual(achievements[0].progress.currentValue, 2)
    }

    func testPersonalBestBronzeAtOne() {
        let app = AppState()
        let wordle = app.games.first { $0.name.lowercased() == "wordle" } ?? app.games[0]
        let now = Date()
        var achievements = [AchievementFactory.createPersonalBestAchievement()]
        let results = [
            makeResult(gameId: wordle.id, gameName: wordle.name, date: dayOffset(-1, from: now), score: 5, completed: true),
            makeResult(gameId: wordle.id, gameName: wordle.name, date: now, score: 3, completed: true)
        ]

        _ = check(results: results, games: app.games, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentTier, .bronze)
    }

    // MARK: - Social Player (thresholds: 1/3/5/10/15)

    func testSocialPlayerBronzeAtOneFriend() {
        var achievements = [AchievementFactory.createSocialPlayerAchievement()]

        _ = check(results: [], friendCount: 1, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentValue, 1)
        XCTAssertEqual(achievements[0].progress.currentTier, .bronze)
    }

    func testSocialPlayerSilverAt3Friends() {
        var achievements = [AchievementFactory.createSocialPlayerAchievement()]

        _ = check(results: [], friendCount: 3, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentTier, .silver)
    }

    func testSocialPlayerNoUnlockAt0Friends() {
        var achievements = [AchievementFactory.createSocialPlayerAchievement()]

        _ = check(results: [], friendCount: 0, achievements: &achievements)

        XCTAssertNil(achievements[0].progress.currentTier)
    }

    // MARK: - Completionist (meta-achievement, thresholds: 3/5/7/9)

    func testCompletionistCountsGoldOrAboveCategories() {
        var achievements = AchievementFactory.createDefaultAchievements()

        // Set 3 categories to Gold
        for i in achievements.indices where achievements[i].category == .streakMaster
            || achievements[i].category == .perfectionist
            || achievements[i].category == .dailyDevotee {
            achievements[i].progress.currentTier = .gold
        }

        // Re-check completionist
        let snapshot = AchievementSnapshot.build(from: [], games: [])
        _ = checker.checkAllAchievements(
            snapshot: snapshot,
            streaks: [],
            currentAchievements: &achievements
        )

        let completionist = achievements.first { $0.category == .completionist }
        XCTAssertEqual(completionist?.progress.currentValue, 3)
        XCTAssertEqual(completionist?.progress.currentTier, .bronze)
    }

    func testCompletionistIgnoresRetiredCategories() {
        // Even if retired categories somehow have Gold, they shouldn't count
        var achievements = AchievementFactory.createDefaultAchievements()
        // Manually add a retired achievement with Gold
        var retired = AchievementFactory.createEarlyBirdAchievement()
        retired.progress.currentTier = .gold
        achievements.append(retired)

        let snapshot = AchievementSnapshot.build(from: [], games: [])
        _ = checker.checkAllAchievements(
            snapshot: snapshot,
            streaks: [],
            currentAchievements: &achievements
        )

        let completionist = achievements.first { $0.category == .completionist }
        XCTAssertEqual(completionist?.progress.currentValue, 0)
    }

    func testCompletionistExcludesSelf() {
        // Completionist shouldn't count itself even if somehow at Gold
        var achievements = AchievementFactory.createDefaultAchievements()
        if let idx = achievements.firstIndex(where: { $0.category == .completionist }) {
            achievements[idx].progress.currentTier = .gold
        }

        let snapshot = AchievementSnapshot.build(from: [], games: [])
        _ = checker.checkAllAchievements(
            snapshot: snapshot,
            streaks: [],
            currentAchievements: &achievements
        )

        let completionist = achievements.first { $0.category == .completionist }
        // Should still be 0 (no other categories at Gold)
        XCTAssertEqual(completionist?.progress.currentValue, 0)
    }
}
