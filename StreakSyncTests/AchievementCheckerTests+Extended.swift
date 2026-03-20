//
//  AchievementCheckerTests+Extended.swift
//  StreakSyncTests
//
//  Extended achievement checker tests: tiers, progress, edge cases, validation
//

@testable import StreakSync
import XCTest

// MARK: - Tier Logic & Progress
extension AchievementCheckerTests {
    func testNextTierSkipsMasterWhenNoRequirement() {
        let requirements = [
            TierRequirement(tier: .bronze, threshold: 3),
            TierRequirement(tier: .silver, threshold: 7),
            TierRequirement(tier: .gold, threshold: 14),
            TierRequirement(tier: .diamond, threshold: 30),
            TierRequirement(tier: .legendary, threshold: 60)
        ]
        let progress = AchievementProgress(currentValue: 30, currentTier: .diamond)
        XCTAssertEqual(progress.nextTier(in: requirements), .legendary)
    }

    func testNextTierReturnsNilAtMax() {
        let requirements = [
            TierRequirement(tier: .bronze, threshold: 3),
            TierRequirement(tier: .legendary, threshold: 60)
        ]
        let progress = AchievementProgress(currentValue: 60, currentTier: .legendary)
        XCTAssertNil(progress.nextTier(in: requirements))
    }

    func testNextTierReturnsBronzeFromNil() {
        let requirements = [
            TierRequirement(tier: .bronze, threshold: 3),
            TierRequirement(tier: .silver, threshold: 7)
        ]
        let progress = AchievementProgress(currentValue: 0, currentTier: nil)
        XCTAssertEqual(progress.nextTier(in: requirements), .bronze)
    }

    func testPercentageToNextTierFromZero() {
        let requirements = [
            TierRequirement(tier: .bronze, threshold: 10),
            TierRequirement(tier: .silver, threshold: 20)
        ]
        let progress = AchievementProgress(currentValue: 5, currentTier: nil)
        XCTAssertEqual(progress.percentageToNextTier(requirements: requirements), 0.5, accuracy: 0.01)
    }

    func testPercentageToNextTierFromBronze() {
        let requirements = [
            TierRequirement(tier: .bronze, threshold: 10),
            TierRequirement(tier: .silver, threshold: 20)
        ]
        let progress = AchievementProgress(currentValue: 15, currentTier: .bronze)
        XCTAssertEqual(progress.percentageToNextTier(requirements: requirements), 0.5, accuracy: 0.01)
    }

    func testPercentageMaxTierReturns1() {
        let requirements = [TierRequirement(tier: .legendary, threshold: 100)]
        let progress = AchievementProgress(currentValue: 100, currentTier: .legendary)
        XCTAssertEqual(progress.percentageToNextTier(requirements: requirements), 1.0, accuracy: 0.01)
    }
}

// MARK: - Category Retirement & Backward Compatibility
extension AchievementCheckerTests {
    func testIsRetiredCategories() {
        XCTAssertTrue(AchievementCategory.earlyBird.isRetired)
        XCTAssertTrue(AchievementCategory.nightOwl.isRetired)
        XCTAssertTrue(AchievementCategory.comebackChampion.isRetired)
        XCTAssertFalse(AchievementCategory.streakMaster.isRetired)
    }

    func testActiveCategoriesExcludesRetired() {
        let active = AchievementCategory.activeCategories
        XCTAssertEqual(active.count, 10)
        XCTAssertFalse(active.contains(.earlyBird))
        XCTAssertTrue(active.contains(.completionist))
    }

    func testDefaultAchievementsHave10Active() {
        let defaults = AchievementFactory.createDefaultAchievements()
        XCTAssertEqual(defaults.count, 10)
        for a in defaults {
            XCTAssertFalse(a.category.isRetired)
        }
    }

    func testMasterTierDecodesCorrectly() {
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

    func testVarietyPlayerUsesUnionWithCachedSetOnRecalc() {
        let app = AppState()
        let g1 = app.games[0]; let g2 = app.games[1]; let gExtra = app.games[3]
        app.recentResults = [
            makeResult(gameId: g1.id, gameName: g1.name, date: Date()),
            makeResult(gameId: g2.id, gameName: g2.name, date: Date())
        ]
        app._uniqueGamesEver = [g1.id, g2.id, gExtra.id]
        app.recalculateAllTieredAchievementProgress()
        let varAch = app.tieredAchievements.first { $0.category == .varietyPlayer }
        XCTAssertEqual(varAch?.progress.currentValue, 3)
    }
}

// MARK: - Snapshot & Validation
extension AchievementCheckerTests {
    func testSnapshotExcludesRetiredFields() {
        let snapshot = AchievementSnapshot.build(from: [], games: [])
        XCTAssertEqual(snapshot.totalGamesPlayed, 0)
        XCTAssertEqual(snapshot.personalBestCount, 0)
        XCTAssertEqual(snapshot.friendCount, 0)
    }

    func testSnapshotPassesFriendCount() {
        let snapshot = AchievementSnapshot.build(from: [], games: [], friendCount: 5)
        XCTAssertEqual(snapshot.friendCount, 5)
    }

    func testAllDefaultAchievementsHave5TiersExceptCompletionist() {
        let defaults = AchievementFactory.createDefaultAchievements()
        for a in defaults {
            if a.category == .completionist {
                XCTAssertEqual(a.requirements.count, 4)
            } else {
                XCTAssertEqual(a.requirements.count, 5)
            }
        }
    }

    func testNoDefaultAchievementUsesMasterTier() {
        let defaults = AchievementFactory.createDefaultAchievements()
        for a in defaults {
            for req in a.requirements {
                XCTAssertNotEqual(req.tier, .master)
            }
        }
    }
}

// MARK: - Edge Cases
extension AchievementCheckerTests {
    func testCheckAllAchievementsWithEmptyResults() {
        var achievements = AchievementFactory.createDefaultAchievements()
        let unlocks = check(results: [], achievements: &achievements)
        XCTAssertTrue(unlocks.isEmpty)
        for a in achievements {
            XCTAssertNil(a.progress.currentTier)
        }
    }

    func testCheckAllAchievementsWithSingleResult() {
        let app = AppState()
        let game = app.games[0]
        let streak = makeStreak(for: game, currentStreak: 1)
        var achievements = AchievementFactory.createDefaultAchievements()
        let results = [makeResult(gameId: game.id, gameName: game.name)]
        _ = check(results: results, streaks: [streak], games: app.games, achievements: &achievements)
        let gc = achievements.first { $0.category == .gameCollector }
        XCTAssertNil(gc?.progress.currentTier)
        XCTAssertEqual(gc?.progress.currentValue, 1)
    }

    func testStreakMasterExactlyAtBronzeThreshold() {
        let app = AppState()
        let game = app.games[0]
        let streak = makeStreak(for: game, currentStreak: 3)
        var achievements = [AchievementFactory.createStreakMasterAchievement()]
        _ = check(results: [makeResult(gameId: game.id, gameName: game.name)], streaks: [streak], games: app.games, achievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentTier, .bronze)
    }

    func testStreakMasterOneBelow() {
        let app = AppState()
        let game = app.games[0]
        let streak = makeStreak(for: game, currentStreak: 2)
        var achievements = [AchievementFactory.createStreakMasterAchievement()]
        _ = check(results: [makeResult(gameId: game.id, gameName: game.name)], streaks: [streak], games: app.games, achievements: &achievements)
        XCTAssertNil(achievements[0].progress.currentTier)
    }

    func testDailyDevoteeLegendaryAt60() {
        let app = AppState()
        let gid = app.games[0].id
        let now = Date()
        var achievements = [AchievementFactory.createDailyDevoteeAchievement()]
        let results = (0..<60).map { makeResult(gameId: gid, date: dayOffset(-$0, from: now)) }
        _ = check(results: results, games: app.games, achievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentTier, .legendary)
    }

    func testGameCollectorLegendaryAt250() {
        var achievements = [AchievementFactory.createGameCollectorAchievement()]
        let results = (0..<250).map { _ in makeResult() }
        _ = check(results: results, achievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentTier, .legendary)
    }

    func testUpdateProgressSkipsToHighestEligibleTier() {
        var achievement = AchievementFactory.createGameCollectorAchievement()
        achievement.updateProgress(value: 250)
        XCTAssertEqual(achievement.progress.currentTier, .legendary)
        XCTAssertNotNil(achievement.progress.tierUnlockDates[.legendary])
    }

    func testUpdateProgressDoesNotRegressTier() {
        var achievement = AchievementFactory.createGameCollectorAchievement()
        achievement.updateProgress(value: 100)
        XCTAssertEqual(achievement.progress.currentTier, .diamond)
        achievement.updateProgress(value: 5)
        XCTAssertEqual(achievement.progress.currentTier, .diamond)
    }

    func testCompletionistSilverAt5() {
        var achievements = AchievementFactory.createDefaultAchievements()
        var goldCount = 0
        for i in achievements.indices where !achievements[i].category.isRetired
            && achievements[i].category != .completionist {
            if goldCount < 5 { achievements[i].progress.currentTier = .gold; goldCount += 1 }
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
        var achievements = AchievementFactory.createDefaultAchievements()
        var count = 0
        for i in achievements.indices where !achievements[i].category.isRetired
            && achievements[i].category != .completionist {
            if count < 3 { achievements[i].progress.currentTier = .legendary; count += 1 }
        }
        let snapshot = AchievementSnapshot.build(from: [], games: [])
        _ = checker.checkAllAchievements(snapshot: snapshot, streaks: [], currentAchievements: &achievements)
        let completionist = achievements.first { $0.category == .completionist }
        XCTAssertEqual(completionist?.progress.currentValue, 3)
        XCTAssertEqual(completionist?.progress.currentTier, .bronze)
    }

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

    func testPersonalBestWithSingleResult() {
        let app = AppState()
        let game = app.games[0]
        var achievements = [AchievementFactory.createPersonalBestAchievement()]
        _ = check(results: [makeResult(gameId: game.id, gameName: game.name, score: 3, completed: true)], games: app.games, achievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentValue, 0)
    }

    func testPersonalBestWithEqualScores() {
        let app = AppState()
        let game = app.games.first { $0.scoringModel.isLowerBetter } ?? app.games[0]
        let now = Date()
        var achievements = [AchievementFactory.createPersonalBestAchievement()]
        let results = [
            makeResult(gameId: game.id, gameName: game.name, date: dayOffset(-1, from: now), score: 3, completed: true),
            makeResult(gameId: game.id, gameName: game.name, date: now, score: 3, completed: true)
        ]
        _ = check(results: results, games: app.games, achievements: &achievements)
        XCTAssertEqual(achievements[0].progress.currentValue, 0)
    }

    func testAllCategoryConsistentIDsAreUnique() {
        let ids = AchievementCategory.allCases.map { $0.consistentID }
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testAllTierIDsAreUnique() {
        let ids = AchievementTier.allCases.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testFullAchievementArrayRoundTrip() {
        var defaults = AchievementFactory.createDefaultAchievements()
        for i in defaults.indices { defaults[i].updateProgress(value: 10) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? encoder.encode(defaults),
              let decoded = try? decoder.decode([TieredAchievement].self, from: data) else {
            XCTFail("Failed to round-trip achievement array"); return
        }
        XCTAssertEqual(decoded.count, defaults.count)
        for (original, roundTripped) in zip(defaults, decoded) {
            XCTAssertEqual(original.id, roundTripped.id)
            XCTAssertEqual(original.progress.currentTier, roundTripped.progress.currentTier)
        }
    }

    func testProgressDescriptionNotStarted() {
        XCTAssertEqual(AchievementFactory.createGameCollectorAchievement().progressDescription, "0/10")
    }

    func testProgressDescriptionInProgress() {
        var achievement = AchievementFactory.createGameCollectorAchievement()
        achievement.updateProgress(value: 15)
        XCTAssertEqual(achievement.progressDescription, "15/25")
    }

    func testProgressDescriptionMaxTier() {
        var achievement = AchievementFactory.createGameCollectorAchievement()
        achievement.updateProgress(value: 250)
        XCTAssertEqual(achievement.progressDescription, "250 (Max)")
    }

    func testSnapshotCountsAllMetricsCorrectly() {
        let app = AppState()
        let g1 = app.games[0]; let g2 = app.games[1]
        let now = Date()
        let results = [
            makeResult(gameId: g1.id, gameName: g1.name, date: dayOffset(-1, from: now), score: 3, completed: true),
            makeResult(gameId: g2.id, gameName: g2.name, date: now, score: 2, completed: true),
            makeResult(gameId: g1.id, gameName: g1.name, date: now, score: 5, completed: false)
        ]
        let snapshot = AchievementSnapshot.build(from: results, games: app.games, friendCount: 7)
        XCTAssertEqual(snapshot.totalGamesPlayed, 3)
        XCTAssertEqual(snapshot.successCount, 2)
        XCTAssertEqual(snapshot.uniqueGameIds.count, 2)
        XCTAssertEqual(snapshot.friendCount, 7)
    }

    func testSnapshotConsecutiveDaysWithTodayGap() {
        let now = Date()
        let results = (3...5).map { makeResult(date: dayOffset(-$0, from: now)) }
        let snapshot = AchievementSnapshot.build(from: results, games: [], referenceDate: now)
        XCTAssertEqual(snapshot.consecutiveDaysPlayed, 0)
    }

    func testSnapshotConsecutiveDaysCurrentStreak() {
        let now = Date()
        let results = [
            makeResult(date: dayOffset(-2, from: now)),
            makeResult(date: dayOffset(-1, from: now)),
            makeResult(date: now)
        ]
        let snapshot = AchievementSnapshot.build(from: results, games: [], referenceDate: now)
        XCTAssertEqual(snapshot.consecutiveDaysPlayed, 3)
    }

    func testThresholdsAreStrictlyIncreasing() {
        for a in AchievementFactory.createDefaultAchievements() {
            for i in 1..<a.requirements.count {
                XCTAssertGreaterThan(a.requirements[i].threshold, a.requirements[i - 1].threshold)
            }
        }
    }

    func testRequirementsAreSortedByTierRawValue() {
        for a in AchievementFactory.createDefaultAchievements() {
            for i in 1..<a.requirements.count {
                XCTAssertGreaterThan(a.requirements[i].tier.rawValue, a.requirements[i - 1].tier.rawValue)
            }
        }
    }
}
