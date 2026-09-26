//
//  LoadAndAchievementsTests.swift
//  StreakSyncTests
//
//  Regression tests for load debouncing, achievement persistence and Delete All Data.
//

@testable import StreakSync
import XCTest

@MainActor
final class LoadAndAchievementsTests: XCTestCase {
    // Minimal persistence double to count saves per key
    final class CountingPersistence: PersistenceServiceProtocol {
        var savesByKey: [String: Int] = [:]
        var storage: [String: Data] = [:]
        
        func save<T>(_ object: T, forKey key: String) throws where T: Decodable, T: Encodable {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            storage[key] = try encoder.encode(object)
            savesByKey[key, default: 0] += 1
        }
        
        func load<T>(_ type: T.Type, forKey key: String) -> T? where T: Decodable, T: Encodable {
            guard let data = storage[key] else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(type, from: data)
        }
        
        func remove(forKey key: String) {
            storage.removeValue(forKey: key)
        }
        
        func clearAll() {
            storage.removeAll()
            savesByKey.removeAll()
        }
    }
    
    func testLoadPersistedDataIsDebounced() async {
        let persistence = CountingPersistence()
        let appState = AppState(persistenceService: persistence)
        
        await appState.loadPersistedData()
        let firstCount = appState.loadCountSinceLaunch
        
        // Immediate second call should be skipped by debounce/guard
        await appState.loadPersistedData()
        let secondCount = appState.loadCountSinceLaunch
        
        XCTAssertEqual(firstCount, 1, "First load should increment once")
        XCTAssertEqual(secondCount, 1, "Second immediate load should be skipped")
    }
    
    func testTieredAchievementsNotSavedWhenUnchanged() async {
        let persistence = CountingPersistence()
        let appState = AppState(persistenceService: persistence)

        // Ensure defaults exist
        _ = appState.tieredAchievements

        // Recompute with no results; should be up to date and not save
        appState.recalculateAllTieredAchievementProgress()

        let saveCount = persistence.savesByKey[AppState.tieredAchievementsKey] ?? 0
        XCTAssertEqual(saveCount, 0, "Recompute should not save when achievements are unchanged")
    }

    /// Launch must seed the recompute from the persisted achievements. Seeding from
    /// fresh defaults re-crosses every earned tier and stamps its unlock date as "now",
    /// so every relaunch rewrote the user's unlock history to the launch date.
    func testLoadPreservesPersistedTierUnlockDates() async throws {
        let persistence = CountingPersistence()
        let unlockedAt = Date(timeIntervalSince1970: 1_600_000_000)

        var streakMaster = AchievementFactory.createStreakMasterAchievement()
        streakMaster.updateProgress(value: 15)
        for tier in [AchievementTier.bronze, .silver, .gold] {
            streakMaster.progress.tierUnlockDates[tier] = unlockedAt
        }
        try persistence.save([streakMaster], forKey: AppState.tieredAchievementsKey)

        let streak = GameStreak(
            gameId: Game.wordle.id, gameName: Game.wordle.name,
            currentStreak: 0, maxStreak: 15,
            totalGamesPlayed: 15, totalGamesCompleted: 15,
            lastPlayedDate: unlockedAt, streakStartDate: nil
        )
        try persistence.save([streak], forKey: UserDefaultsPersistenceService.Keys.streaks)

        let appState = AppState(persistenceService: persistence)
        await appState.loadPersistedData()

        let loaded = try XCTUnwrap(appState.tieredAchievements.first { $0.category == .streakMaster })
        XCTAssertEqual(loaded.progress.currentTier, .gold, "Precondition: the recompute still earns gold")
        XCTAssertEqual(loaded.progress.tierUnlockDates[.bronze], unlockedAt, "Bronze unlock date was rewritten")
        XCTAssertEqual(loaded.progress.tierUnlockDates[.gold], unlockedAt, "Gold unlock date was rewritten")
    }

    // MARK: - Delete All Data

    /// "Delete All Data" empties the stores, so the lazy lifetime caches must not keep
    /// serving (and later re-saving) the deleted history.
    func testClearAllDataDropsCachedLifetimeSets() async {
        let appState = AppState(persistenceService: MockPersistenceService())
        appState.recordActiveDays(from: [
            GameResult(
                gameId: Game.wordle.id, gameName: Game.wordle.name, date: Date(),
                score: 3, maxAttempts: 6, completed: true, sharedText: "Wordle 1,900 3/6"
            )
        ])
        XCTAssertFalse(appState.activeDaysEver.isEmpty, "Precondition: a day was recorded")

        await appState.clearAllData()

        XCTAssertTrue(appState.activeDaysEver.isEmpty, "Deleted active days are still served from the cache")
    }

    // MARK: - Migration Tests

    func testMigrationStripsRetiredAndAddsNewCategories() {
        let persistence = CountingPersistence()

        // Simulate old data with retired categories and missing new ones
        let oldAchievements: [TieredAchievement] = [
            AchievementFactory.createStreakMasterAchievement(),
            AchievementFactory.createGameCollectorAchievement(),
            AchievementFactory.createPerfectionistAchievement(),
            AchievementFactory.createDailyDevoteeAchievement(),
            AchievementFactory.createVarietyPlayerAchievement(),
            AchievementFactory.createSpeedDemonAchievement(),
            AchievementFactory.createEarlyBirdAchievement(),
            AchievementFactory.createNightOwlAchievement(),
            AchievementFactory.createComebackChampionAchievement(),
            AchievementFactory.createMarathonRunnerAchievement()
        ]

        // Persist old data
        try? persistence.save(oldAchievements, forKey: AppState.tieredAchievementsKey)

        let appState = AppState(persistenceService: persistence)
        let loaded = appState.tieredAchievements

        // Should have 10 active categories (3 retired stripped, 3 new added)
        XCTAssertEqual(loaded.count, 10, "Should have exactly 10 active achievements")

        // Retired should be gone
        XCTAssertFalse(loaded.contains { $0.category == .earlyBird }, "earlyBird should be stripped")
        XCTAssertFalse(loaded.contains { $0.category == .nightOwl }, "nightOwl should be stripped")
        XCTAssertFalse(loaded.contains { $0.category == .comebackChampion }, "comebackChampion should be stripped")

        // New categories should be present
        XCTAssertTrue(loaded.contains { $0.category == .personalBest }, "personalBest should be added")
        XCTAssertTrue(loaded.contains { $0.category == .socialPlayer }, "socialPlayer should be added")
        XCTAssertTrue(loaded.contains { $0.category == .completionist }, "completionist should be added")
    }

    func testMigrationPreservesExistingProgress() {
        let persistence = CountingPersistence()

        var streakMaster = AchievementFactory.createStreakMasterAchievement()
        streakMaster.updateProgress(value: 15)

        let oldAchievements: [TieredAchievement] = [
            streakMaster,
            AchievementFactory.createGameCollectorAchievement(),
            AchievementFactory.createEarlyBirdAchievement() // retired
        ]

        try? persistence.save(oldAchievements, forKey: AppState.tieredAchievementsKey)

        let appState = AppState(persistenceService: persistence)
        let loaded = appState.tieredAchievements

        // Streak Master progress should be preserved
        let sm = loaded.first { $0.category == .streakMaster }
        XCTAssertEqual(sm?.progress.currentValue, 15)
        XCTAssertEqual(sm?.progress.currentTier, .gold)
    }
}
