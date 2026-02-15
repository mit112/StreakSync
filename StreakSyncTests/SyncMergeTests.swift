//
//  SyncMergeTests.swift
//  StreakSyncTests
//
//  Tests for sync conflict resolution:
//  - FirestoreAchievementSyncService.merge() (tiered achievements)
//  - GameResult.lastModified timestamp comparison logic
//

import XCTest
@testable import StreakSync

@MainActor
final class SyncMergeTests: XCTestCase {
    
    private var syncService: FirestoreAchievementSyncService!
    private var appState: AppState!
    
    override func setUp() {
        super.setUp()
        appState = AppState(persistenceService: MockPersistenceService())
        syncService = FirestoreAchievementSyncService(appState: appState)
    }
    
    override func tearDown() {
        syncService = nil
        appState = nil
        super.tearDown()
    }
    
    // MARK: - Helpers
    
    private let testId = UUID()
    
    private func makeAchievement(
        id: UUID? = nil,
        category: AchievementCategory = .streakMaster,
        tier: AchievementTier? = nil,
        value: Int = 0,
        unlockDates: [AchievementTier: Date] = [:]
    ) -> TieredAchievement {
        TieredAchievement(
            id: id ?? testId,
            category: category,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 3),
                TierRequirement(tier: .silver, threshold: 7),
                TierRequirement(tier: .gold, threshold: 30)
            ],
            progress: AchievementProgress(
                currentValue: value,
                currentTier: tier,
                tierUnlockDates: unlockDates
            )
        )
    }
    
    private func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    }
    
    // MARK: - Achievement Merge: Tier Priority
    
    func testHigherRemoteTierWins() {
        let local = [makeAchievement(tier: .bronze, value: 5)]
        let remote = [makeAchievement(tier: .silver, value: 8)]
        
        let merged = syncService.merge(local: local, remote: remote)
        
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].progress.currentTier, .silver)
    }
    
    func testHigherLocalTierPreserved() {
        let local = [makeAchievement(tier: .gold, value: 30)]
        let remote = [makeAchievement(tier: .silver, value: 8)]
        
        let merged = syncService.merge(local: local, remote: remote)
        
        XCTAssertEqual(merged[0].progress.currentTier, .gold)
    }
    
    func testRemoteTierWinsOverNil() {
        let local = [makeAchievement(tier: nil, value: 2)]
        let remote = [makeAchievement(tier: .bronze, value: 5)]
        
        let merged = syncService.merge(local: local, remote: remote)
        
        XCTAssertEqual(merged[0].progress.currentTier, .bronze)
    }
    
    // MARK: - Achievement Merge: Progress Value
    
    func testHigherProgressValueWins() {
        let local = [makeAchievement(tier: .bronze, value: 5)]
        let remote = [makeAchievement(tier: .bronze, value: 10)]
        
        let merged = syncService.merge(local: local, remote: remote)
        
        XCTAssertEqual(merged[0].progress.currentValue, 10)
    }
    
    func testLocalHigherProgressPreserved() {
        let local = [makeAchievement(tier: .bronze, value: 15)]
        let remote = [makeAchievement(tier: .bronze, value: 10)]
        
        let merged = syncService.merge(local: local, remote: remote)
        
        XCTAssertEqual(merged[0].progress.currentValue, 15)
    }
    
    // MARK: - Achievement Merge: Unlock Dates
    
    func testUnlockDatesUnioned() {
        let localDates: [AchievementTier: Date] = [.bronze: date(daysAgo: 10)]
        let remoteDates: [AchievementTier: Date] = [.silver: date(daysAgo: 3)]
        
        let local = [makeAchievement(tier: .silver, value: 8, unlockDates: localDates)]
        let remote = [makeAchievement(tier: .silver, value: 8, unlockDates: remoteDates)]
        
        let merged = syncService.merge(local: local, remote: remote)
        
        XCTAssertNotNil(merged[0].progress.tierUnlockDates[.bronze])
        XCTAssertNotNil(merged[0].progress.tierUnlockDates[.silver])
    }
    
    func testConflictingUnlockDatesKeepLatest() {
        let olderDate = date(daysAgo: 10)
        let newerDate = date(daysAgo: 2)
        
        let local = [makeAchievement(tier: .bronze, value: 5, unlockDates: [.bronze: olderDate])]
        let remote = [makeAchievement(tier: .bronze, value: 5, unlockDates: [.bronze: newerDate])]
        
        let merged = syncService.merge(local: local, remote: remote)
        
        XCTAssertEqual(merged[0].progress.tierUnlockDates[.bronze], newerDate)
    }
    
    // MARK: - Achievement Merge: Missing Achievements
    
    func testRemoteOnlyAchievementAdded() {
        let localId = UUID()
        let remoteId = UUID()
        
        let local = [makeAchievement(id: localId, category: .streakMaster, tier: .bronze, value: 5)]
        let remote = [makeAchievement(id: remoteId, category: .gameCollector, tier: .silver, value: 12)]
        
        let merged = syncService.merge(local: local, remote: remote)
        
        XCTAssertEqual(merged.count, 2)
        XCTAssertTrue(merged.contains(where: { $0.id == localId }))
        XCTAssertTrue(merged.contains(where: { $0.id == remoteId }))
    }
    
    func testEmptyRemoteLeavesLocalUnchanged() {
        let local = [
            makeAchievement(id: UUID(), category: .streakMaster, tier: .bronze, value: 5),
            makeAchievement(id: UUID(), category: .gameCollector, tier: .silver, value: 12)
        ]
        
        let merged = syncService.merge(local: local, remote: [])
        
        XCTAssertEqual(merged.count, 2)
    }
    
    func testEmptyLocalTakesRemote() {
        let remote = [makeAchievement(tier: .gold, value: 30)]
        
        let merged = syncService.merge(local: [], remote: remote)
        
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].progress.currentTier, .gold)
    }
    
    // MARK: - GameResult lastModified Comparison
    
    func testNewerLocalResultPreservedInMerge() {
        let id = UUID()
        let olderDate = date(daysAgo: 2)
        let newerDate = date(daysAgo: 0)
        
        let local = GameResult(
            id: id, gameId: UUID(), gameName: "wordle",
            date: date(daysAgo: 1), score: 3, maxAttempts: 6,
            completed: true, sharedText: "Wordle 100 3/6",
            lastModified: newerDate
        )
        
        let remote = GameResult(
            id: id, gameId: UUID(), gameName: "wordle",
            date: date(daysAgo: 1), score: 4, maxAttempts: 6,
            completed: true, sharedText: "Wordle 100 4/6",
            lastModified: olderDate
        )
        
        // Simulate the merge logic from syncIfNeeded
        var merged = [local]
        if remote.lastModified >= local.lastModified {
            merged[0] = remote
        }
        
        // Local should win because it's newer
        XCTAssertEqual(merged[0].score, 3)
    }
    
    func testNewerRemoteResultWinsInMerge() {
        let id = UUID()
        let olderDate = date(daysAgo: 2)
        let newerDate = date(daysAgo: 0)
        
        let local = GameResult(
            id: id, gameId: UUID(), gameName: "wordle",
            date: date(daysAgo: 1), score: 3, maxAttempts: 6,
            completed: true, sharedText: "Wordle 100 3/6",
            lastModified: olderDate
        )
        
        let remote = GameResult(
            id: id, gameId: UUID(), gameName: "wordle",
            date: date(daysAgo: 1), score: 4, maxAttempts: 6,
            completed: true, sharedText: "Wordle 100 4/6",
            lastModified: newerDate
        )
        
        var merged = [local]
        if remote.lastModified >= local.lastModified {
            merged[0] = remote
        }
        
        // Remote should win because it's newer
        XCTAssertEqual(merged[0].score, 4)
    }
    
    func testLastModifiedDefaultsToDate() {
        let result = GameResult(
            gameId: UUID(), gameName: "wordle",
            date: date(daysAgo: 5), score: 3, maxAttempts: 6,
            completed: true, sharedText: "Wordle 100 3/6"
            // no lastModified parameter — should default to date
        )
        
        XCTAssertEqual(
            Calendar.current.startOfDay(for: result.lastModified),
            Calendar.current.startOfDay(for: date(daysAgo: 5))
        )
    }
}
