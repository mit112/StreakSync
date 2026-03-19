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
        Calendar.current.date(byAdding: .day, value: days, to: base) ?? base
    }

    private func hourOffset(_ hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
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

    /// Builds an AchievementSnapshot and calls checkAllAchievements.
    private func check(
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
            makeResult(gameId: gid, date: now),
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
            makeResult(gameId: gid, date: now),
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
            makeResult(gameId: g3.id, gameName: g3.name, date: now),
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
            makeResult(gameId: g3.id, date: now),
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
            makeResult(gameId: wordle.id, gameName: wordle.name, date: now, score: 2, completed: true),
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
            makeResult(gameId: higherGame.id, gameName: higherGame.name, date: now, score: 60, maxAttempts: 100, completed: true),
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
            makeResult(gameId: wordle.id, gameName: wordle.name, date: now, score: 4, completed: true),
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
            makeResult(gameId: wordle.id, gameName: wordle.name, date: now, score: 1, completed: true),
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
            makeResult(gameId: g2.id, gameName: g2.name, date: now, score: 2, completed: true),
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
            makeResult(gameId: wordle.id, gameName: wordle.name, date: now, score: 3, completed: true),
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

    // MARK: - nextTier Fix (skipping .master)

    func testNextTierSkipsMasterWhenNoRequirement() {
        // Achievement with no .master requirement: Diamond should go to Legendary
        let requirements = [
            TierRequirement(tier: .bronze, threshold: 3),
            TierRequirement(tier: .silver, threshold: 7),
            TierRequirement(tier: .gold, threshold: 14),
            TierRequirement(tier: .diamond, threshold: 30),
            TierRequirement(tier: .legendary, threshold: 60),
        ]
        let progress = AchievementProgress(currentValue: 30, currentTier: .diamond)

        let next = progress.nextTier(in: requirements)
        XCTAssertEqual(next, .legendary, "Should skip .master and go to .legendary")
    }

    func testNextTierReturnsNilAtMax() {
        let requirements = [
            TierRequirement(tier: .bronze, threshold: 3),
            TierRequirement(tier: .legendary, threshold: 60),
        ]
        let progress = AchievementProgress(currentValue: 60, currentTier: .legendary)

        let next = progress.nextTier(in: requirements)
        XCTAssertNil(next)
    }

    func testNextTierReturnsBronzeFromNil() {
        let requirements = [
            TierRequirement(tier: .bronze, threshold: 3),
            TierRequirement(tier: .silver, threshold: 7),
        ]
        let progress = AchievementProgress(currentValue: 0, currentTier: nil)

        let next = progress.nextTier(in: requirements)
        XCTAssertEqual(next, .bronze)
    }

    // MARK: - Progress Percentage (using requirements-aware nextTier)

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
        let requirements = [TierRequirement(tier: .legendary, threshold: 100)]
        let progress = AchievementProgress(currentValue: 100, currentTier: .legendary)

        XCTAssertEqual(progress.percentageToNextTier(requirements: requirements), 1.0, accuracy: 0.01)
    }

    // MARK: - Category Retirement

    func testIsRetiredCategories() {
        XCTAssertTrue(AchievementCategory.earlyBird.isRetired)
        XCTAssertTrue(AchievementCategory.nightOwl.isRetired)
        XCTAssertTrue(AchievementCategory.comebackChampion.isRetired)
        XCTAssertFalse(AchievementCategory.streakMaster.isRetired)
        XCTAssertFalse(AchievementCategory.personalBest.isRetired)
        XCTAssertFalse(AchievementCategory.socialPlayer.isRetired)
        XCTAssertFalse(AchievementCategory.completionist.isRetired)
    }

    func testActiveCategoriesExcludesRetired() {
        let active = AchievementCategory.activeCategories
        XCTAssertEqual(active.count, 10)
        XCTAssertFalse(active.contains(.earlyBird))
        XCTAssertFalse(active.contains(.nightOwl))
        XCTAssertFalse(active.contains(.comebackChampion))
        XCTAssertTrue(active.contains(.personalBest))
        XCTAssertTrue(active.contains(.socialPlayer))
        XCTAssertTrue(active.contains(.completionist))
    }

    func testDefaultAchievementsHave10Active() {
        let defaults = AchievementFactory.createDefaultAchievements()
        XCTAssertEqual(defaults.count, 10)
        for a in defaults {
            XCTAssertFalse(a.category.isRetired, "\(a.category.displayName) should not be retired")
        }
    }

    // MARK: - Backward Compatibility

    func testMasterTierDecodesCorrectly() {
        // Users who earned .master keep it — verify Codable round-trip
        var achievement = AchievementFactory.createStreakMasterAchievement()
        achievement.progress.currentTier = .master
        achievement.progress.tierUnlockDates[.master] = Date()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let data = try? encoder.encode(achievement),
              let decoded = try? decoder.decode(TieredAchievement.self, from: data) else {
            XCTFail("Failed to round-trip achievement with .master tier")
            return
        }

        XCTAssertEqual(decoded.progress.currentTier, .master)
        XCTAssertNotNil(decoded.progress.tierUnlockDates[.master])
    }

    func testRetiredCategoryDecodesCorrectly() {
        // Old data with retired categories should still decode
        let retired = AchievementFactory.createEarlyBirdAchievement()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let data = try? encoder.encode(retired),
              let decoded = try? decoder.decode(TieredAchievement.self, from: data) else {
            XCTFail("Failed to decode retired achievement")
            return
        }

        XCTAssertEqual(decoded.category, .earlyBird)
        XCTAssertTrue(decoded.category.isRetired)
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

    // MARK: - Snapshot Fields

    func testSnapshotExcludesRetiredFields() {
        // Verify snapshot no longer tracks earlyBirdCount, nightOwlCount, comebackCount
        let snapshot = AchievementSnapshot.build(from: [], games: [])
        XCTAssertEqual(snapshot.totalGamesPlayed, 0)
        XCTAssertEqual(snapshot.personalBestCount, 0)
        XCTAssertEqual(snapshot.friendCount, 0)
    }

    func testSnapshotPassesFriendCount() {
        let snapshot = AchievementSnapshot.build(from: [], games: [], friendCount: 5)
        XCTAssertEqual(snapshot.friendCount, 5)
    }

    // MARK: - Threshold Validation

    func testAllDefaultAchievementsHave5TiersExceptCompletionist() {
        let defaults = AchievementFactory.createDefaultAchievements()
        for a in defaults {
            if a.category == .completionist {
                XCTAssertEqual(a.requirements.count, 4, "Completionist should have 4 tiers")
            } else {
                XCTAssertEqual(a.requirements.count, 5, "\(a.category.displayName) should have 5 tiers")
            }
        }
    }

    func testNoDefaultAchievementUsesMasterTier() {
        let defaults = AchievementFactory.createDefaultAchievements()
        for a in defaults {
            for req in a.requirements {
                XCTAssertNotEqual(req.tier, .master, "\(a.category.displayName) should not use .master tier")
            }
        }
    }

    // MARK: - Edge Cases: Empty and Boundary Inputs

    func testCheckAllAchievementsWithEmptyResults() {
        var achievements = AchievementFactory.createDefaultAchievements()
        let unlocks = check(results: [], achievements: &achievements)

        XCTAssertTrue(unlocks.isEmpty)
        for a in achievements {
            XCTAssertNil(a.progress.currentTier, "\(a.category.displayName) should not unlock with no results")
        }
    }

    func testCheckAllAchievementsWithSingleResult() {
        let app = AppState()
        let game = app.games[0]
        let streak = makeStreak(for: game, currentStreak: 1)
        var achievements = AchievementFactory.createDefaultAchievements()
        let results = [makeResult(gameId: game.id, gameName: game.name)]

        _ = check(results: results, streaks: [streak], games: app.games, achievements: &achievements)

        // GameCollector should not unlock at 1 (threshold is 10)
        let gc = achievements.first { $0.category == .gameCollector }
        XCTAssertNil(gc?.progress.currentTier)
        XCTAssertEqual(gc?.progress.currentValue, 1)
    }

    // MARK: - Edge Cases: Threshold Boundaries

    func testStreakMasterExactlyAtBronzeThreshold() {
        let app = AppState()
        let game = app.games[0]
        let streak = makeStreak(for: game, currentStreak: 3)
        var achievements = [AchievementFactory.createStreakMasterAchievement()]
        let result = makeResult(gameId: game.id, gameName: game.name)

        _ = check(results: [result], streaks: [streak], games: app.games, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentTier, .bronze)
    }

    func testStreakMasterOneBelow() {
        let app = AppState()
        let game = app.games[0]
        let streak = makeStreak(for: game, currentStreak: 2)
        var achievements = [AchievementFactory.createStreakMasterAchievement()]
        let result = makeResult(gameId: game.id, gameName: game.name)

        _ = check(results: [result], streaks: [streak], games: app.games, achievements: &achievements)

        XCTAssertNil(achievements[0].progress.currentTier)
    }

    func testDailyDevoteeLegendaryAt60() {
        let app = AppState()
        let gid = app.games[0].id
        let now = Date()
        var achievements = [AchievementFactory.createDailyDevoteeAchievement()]
        // 60 consecutive days
        let results = (0..<60).map { dayIdx in
            makeResult(gameId: gid, date: dayOffset(-dayIdx, from: now))
        }

        _ = check(results: results, games: app.games, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentTier, .legendary)
    }

    func testGameCollectorLegendaryAt250() {
        var achievements = [AchievementFactory.createGameCollectorAchievement()]
        let results = (0..<250).map { _ in makeResult() }

        _ = check(results: results, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentTier, .legendary)
    }

    // MARK: - Edge Cases: updateProgress tier jumping

    func testUpdateProgressSkipsToHighestEligibleTier() {
        var achievement = AchievementFactory.createGameCollectorAchievement()
        // Jump straight to value that satisfies all tiers
        achievement.updateProgress(value: 250)

        XCTAssertEqual(achievement.progress.currentTier, .legendary)
        // Only the highest eligible tier gets a date when jumping (reverse loop
        // sets highest first, then lower tiers fail the > currentRaw check)
        XCTAssertNotNil(achievement.progress.tierUnlockDates[.legendary])
    }

    func testUpdateProgressDoesNotRegressTier() {
        var achievement = AchievementFactory.createGameCollectorAchievement()
        achievement.updateProgress(value: 100)
        XCTAssertEqual(achievement.progress.currentTier, .diamond)

        // Lower value should not regress tier
        achievement.updateProgress(value: 5)
        XCTAssertEqual(achievement.progress.currentTier, .diamond)
    }

    // MARK: - Edge Cases: Completionist Boundaries

    func testCompletionistSilverAt5() {
        var achievements = AchievementFactory.createDefaultAchievements()
        var goldCount = 0
        for i in achievements.indices where !achievements[i].category.isRetired
            && achievements[i].category != .completionist {
            if goldCount < 5 {
                achievements[i].progress.currentTier = .gold
                goldCount += 1
            }
        }

        let snapshot = AchievementSnapshot.build(from: [], games: [])
        _ = checker.checkAllAchievements(snapshot: snapshot, streaks: [], currentAchievements: &achievements)

        let completionist = achievements.first { $0.category == .completionist }
        XCTAssertEqual(completionist?.progress.currentValue, 5)
        XCTAssertEqual(completionist?.progress.currentTier, .silver)
    }

    func testCompletionistDiamondRequiresAllNineAtGold() {
        var achievements = AchievementFactory.createDefaultAchievements()
        for i in achievements.indices where !achievements[i].category.isRetired
            && achievements[i].category != .completionist {
            achievements[i].progress.currentTier = .gold
        }

        let snapshot = AchievementSnapshot.build(from: [], games: [])
        _ = checker.checkAllAchievements(snapshot: snapshot, streaks: [], currentAchievements: &achievements)

        let completionist = achievements.first { $0.category == .completionist }
        XCTAssertEqual(completionist?.progress.currentValue, 9)
        XCTAssertEqual(completionist?.progress.currentTier, .diamond)
    }

    func testCompletionistCountsDiamondAndLegendaryToo() {
        // Diamond and Legendary tiers are > Gold, so they should count
        var achievements = AchievementFactory.createDefaultAchievements()
        var count = 0
        for i in achievements.indices where !achievements[i].category.isRetired
            && achievements[i].category != .completionist {
            if count < 3 {
                achievements[i].progress.currentTier = .legendary
                count += 1
            }
        }

        let snapshot = AchievementSnapshot.build(from: [], games: [])
        _ = checker.checkAllAchievements(snapshot: snapshot, streaks: [], currentAchievements: &achievements)

        let completionist = achievements.first { $0.category == .completionist }
        XCTAssertEqual(completionist?.progress.currentValue, 3)
        XCTAssertEqual(completionist?.progress.currentTier, .bronze)
    }

    // MARK: - Edge Cases: Social Player

    func testSocialPlayerLegendaryAt15() {
        var achievements = [AchievementFactory.createSocialPlayerAchievement()]
        _ = check(results: [], friendCount: 15, achievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentTier, .legendary)
    }

    func testSocialPlayerDiamondAt10() {
        var achievements = [AchievementFactory.createSocialPlayerAchievement()]
        _ = check(results: [], friendCount: 10, achievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentTier, .diamond)
    }

    // MARK: - Edge Cases: Personal Best

    func testPersonalBestWithSingleResult() {
        let app = AppState()
        let game = app.games[0]
        var achievements = [AchievementFactory.createPersonalBestAchievement()]
        let results = [makeResult(gameId: game.id, gameName: game.name, score: 3, completed: true)]

        _ = check(results: results, games: app.games, achievements: &achievements)

        // Single result = no previous to beat
        XCTAssertEqual(achievements[0].progress.currentValue, 0)
    }

    func testPersonalBestWithEqualScores() {
        let app = AppState()
        let game = app.games.first { $0.scoringModel.isLowerBetter } ?? app.games[0]
        let now = Date()
        var achievements = [AchievementFactory.createPersonalBestAchievement()]
        // Same score twice = not a PB
        let results = [
            makeResult(gameId: game.id, gameName: game.name, date: dayOffset(-1, from: now), score: 3, completed: true),
            makeResult(gameId: game.id, gameName: game.name, date: now, score: 3, completed: true),
        ]

        _ = check(results: results, games: app.games, achievements: &achievements)

        XCTAssertEqual(achievements[0].progress.currentValue, 0)
    }

    // MARK: - Edge Cases: ConsistentID Uniqueness

    func testAllCategoryConsistentIDsAreUnique() {
        let ids = AchievementCategory.allCases.map { $0.consistentID }
        XCTAssertEqual(ids.count, Set(ids).count, "All category consistentIDs must be unique")
    }

    func testAllTierIDsAreUnique() {
        let ids = AchievementTier.allCases.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count, "All tier IDs must be unique")
    }

    // MARK: - Edge Cases: Codable Round-Trip

    func testFullAchievementArrayRoundTrip() {
        var defaults = AchievementFactory.createDefaultAchievements()
        // Set some progress on each
        for i in defaults.indices {
            defaults[i].updateProgress(value: 10)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let data = try? encoder.encode(defaults),
              let decoded = try? decoder.decode([TieredAchievement].self, from: data) else {
            XCTFail("Failed to round-trip achievement array")
            return
        }

        XCTAssertEqual(decoded.count, defaults.count)
        for (original, roundTripped) in zip(defaults, decoded) {
            XCTAssertEqual(original.id, roundTripped.id)
            XCTAssertEqual(original.category, roundTripped.category)
            XCTAssertEqual(original.progress.currentValue, roundTripped.progress.currentValue)
            XCTAssertEqual(original.progress.currentTier, roundTripped.progress.currentTier)
        }
    }

    // MARK: - Edge Cases: progressDescription

    func testProgressDescriptionNotStarted() {
        let achievement = AchievementFactory.createGameCollectorAchievement()
        XCTAssertEqual(achievement.progressDescription, "0/10")
    }

    func testProgressDescriptionInProgress() {
        var achievement = AchievementFactory.createGameCollectorAchievement()
        achievement.updateProgress(value: 15)
        // Should show progress toward silver (25)
        XCTAssertEqual(achievement.progressDescription, "15/25")
    }

    func testProgressDescriptionMaxTier() {
        var achievement = AchievementFactory.createGameCollectorAchievement()
        achievement.updateProgress(value: 250)
        // Legendary is max, no next tier
        XCTAssertEqual(achievement.progressDescription, "250 (Max)")
    }

    // MARK: - Edge Cases: Snapshot Metrics

    func testSnapshotCountsAllMetricsCorrectly() {
        let app = AppState()
        let g1 = app.games[0]; let g2 = app.games[1]
        let now = Date()
        let results = [
            makeResult(gameId: g1.id, gameName: g1.name, date: dayOffset(-1, from: now), score: 3, completed: true),
            makeResult(gameId: g2.id, gameName: g2.name, date: now, score: 2, completed: true),
            makeResult(gameId: g1.id, gameName: g1.name, date: now, score: 5, completed: false),
        ]

        let snapshot = AchievementSnapshot.build(from: results, games: app.games, friendCount: 7)

        XCTAssertEqual(snapshot.totalGamesPlayed, 3)
        XCTAssertEqual(snapshot.successCount, 2)
        XCTAssertEqual(snapshot.uniqueGameIds.count, 2)
        XCTAssertEqual(snapshot.uniqueDayCount, 2)
        XCTAssertEqual(snapshot.friendCount, 7)
    }

    func testSnapshotConsecutiveDaysWithTodayGap() {
        let now = Date()
        let results = [
            makeResult(date: dayOffset(-5, from: now)),
            makeResult(date: dayOffset(-4, from: now)),
            makeResult(date: dayOffset(-3, from: now)),
        ]

        let snapshot = AchievementSnapshot.build(from: results, games: [], referenceDate: now)

        // Gap of >1 day between last result and reference → streak is 0
        XCTAssertEqual(snapshot.consecutiveDaysPlayed, 0)
    }

    func testSnapshotConsecutiveDaysCurrentStreak() {
        let now = Date()
        let results = [
            makeResult(date: dayOffset(-2, from: now)),
            makeResult(date: dayOffset(-1, from: now)),
            makeResult(date: now),
        ]

        let snapshot = AchievementSnapshot.build(from: results, games: [], referenceDate: now)

        XCTAssertEqual(snapshot.consecutiveDaysPlayed, 3)
    }

    // MARK: - Edge Cases: Threshold ~2x Curve Validation

    func testThresholdsAreStrictlyIncreasing() {
        let defaults = AchievementFactory.createDefaultAchievements()
        for a in defaults {
            for i in 1..<a.requirements.count {
                XCTAssertGreaterThan(
                    a.requirements[i].threshold,
                    a.requirements[i - 1].threshold,
                    "\(a.category.displayName) thresholds must be strictly increasing"
                )
            }
        }
    }

    func testRequirementsAreSortedByTierRawValue() {
        let defaults = AchievementFactory.createDefaultAchievements()
        for a in defaults {
            for i in 1..<a.requirements.count {
                XCTAssertGreaterThan(
                    a.requirements[i].tier.rawValue,
                    a.requirements[i - 1].tier.rawValue,
                    "\(a.category.displayName) requirements must be sorted by tier"
                )
            }
        }
    }
}
