//
//  SyncMergeTests.swift
//  StreakSyncTests
//
//  Tests for sync conflict resolution:
//  - FirestoreAchievementSyncService.merge() (tiered achievements)
//  - GameResult.lastModified timestamp comparison logic
//

@testable import StreakSync
import XCTest

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
        // swiftlint:disable:next force_unwrapping
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
    
    func testConflictingUnlockDatesKeepEarliest() {
        let olderDate = date(daysAgo: 10)
        let newerDate = date(daysAgo: 2)

        let local = [makeAchievement(tier: .bronze, value: 5, unlockDates: [.bronze: olderDate])]
        let remote = [makeAchievement(tier: .bronze, value: 5, unlockDates: [.bronze: newerDate])]

        let merged = syncService.merge(local: local, remote: remote)

        XCTAssertEqual(merged[0].progress.tierUnlockDates[.bronze], olderDate)
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
    
    // MARK: - GameResult Merge (real GameResultSyncMerge code)

    /// Builds a GameResult with controllable id / puzzle date / lastModified / score.
    private func makeResult(
        id: UUID = UUID(),
        daysAgo: Int = 1,
        score: Int = 3,
        lastModified: Date? = nil,
        exactDate: Date? = nil
    ) -> GameResult {
        // `date(daysAgo:)` is relative to `Date()` at call time, so two results built with
        // the same `daysAgo` differ by microseconds. Tie-break tests must pass `exactDate`.
        let puzzleDate = exactDate ?? date(daysAgo: daysAgo)
        return GameResult(
            id: id, gameId: UUID(), gameName: "wordle",
            date: puzzleDate, score: score, maxAttempts: 6,
            completed: true, sharedText: "Wordle 100 \(score)/6",
            lastModified: lastModified ?? puzzleDate
        )
    }

    func testNewerLocalResultPreservedInMerge() {
        let id = UUID()
        let local = makeResult(id: id, score: 3, lastModified: date(daysAgo: 0))
        let remote = makeResult(id: id, score: 4, lastModified: date(daysAgo: 2))

        let merged = GameResultSyncMerge.mergeResults(local: [local], remote: [remote])

        // Local wins because it's newer (strict `>`)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].score, 3)
    }

    func testNewerRemoteResultWinsInMerge() {
        let id = UUID()
        let local = makeResult(id: id, score: 3, lastModified: date(daysAgo: 2))
        let remote = makeResult(id: id, score: 4, lastModified: date(daysAgo: 0))

        let merged = GameResultSyncMerge.mergeResults(local: [local], remote: [remote])

        XCTAssertEqual(merged[0].score, 4)
    }

    func testEqualLastModifiedLocalWins() {
        // mergeResults uses strict `>` — on a tie, local is preserved.
        let id = UUID()
        let tied = date(daysAgo: 1)
        let local = makeResult(id: id, score: 3, lastModified: tied)
        let remote = makeResult(id: id, score: 4, lastModified: tied)

        let merged = GameResultSyncMerge.mergeResults(local: [local], remote: [remote])

        XCTAssertEqual(merged[0].score, 3)
    }

    // MARK: - Restore scenarios

    func testEmptyLocalFullRemoteRestoresAll() {
        // Reinstall / new sign-in: local empty, remote is the cloud archive.
        let remote = [makeResult(daysAgo: 1), makeResult(daysAgo: 2), makeResult(daysAgo: 3)]

        let merged = GameResultSyncMerge.mergeResults(local: [], remote: remote)

        XCTAssertEqual(Set(merged.map { $0.id }), Set(remote.map { $0.id }))
    }

    func testMergeUnionsDistinctIds() {
        let local = [makeResult(daysAgo: 1), makeResult(daysAgo: 2)]
        let remote = [makeResult(daysAgo: 3), makeResult(daysAgo: 4)]

        let merged = GameResultSyncMerge.mergeResults(local: local, remote: remote)

        XCTAssertEqual(merged.count, 4)
        XCTAssertEqual(Set(merged.map { $0.id }), Set((local + remote).map { $0.id }))
    }

    func testTombstonedResultNotResurrected() {
        // A deleted id present remotely must not survive a merge+filter.
        let deletedId = UUID()
        let keptId = UUID()
        let merged = GameResultSyncMerge.mergeResults(
            local: [],
            remote: [makeResult(id: deletedId), makeResult(id: keptId)]
        )

        let filtered = GameResultSyncMerge.filterDeleted(merged, deletedIds: [deletedId])

        XCTAssertEqual(filtered.map { $0.id }, [keptId])
    }

    func testResultsToPushSelectsLocalOnlyAndNewer() {
        let sharedId = UUID()
        let localOnly = makeResult(daysAgo: 1)
        let localNewer = makeResult(id: sharedId, score: 5, lastModified: date(daysAgo: 0))
        let remoteOlder = makeResult(id: sharedId, score: 2, lastModified: date(daysAgo: 3))

        let local = [localOnly, localNewer]
        let remote = [remoteOlder]
        let merged = GameResultSyncMerge.mergeResults(local: local, remote: remote)

        let toPush = GameResultSyncMerge.resultsToPush(merged: merged, local: local, remote: remote)

        // Both the local-only result and the locally-newer edit must be pushed.
        XCTAssertEqual(Set(toPush.map { $0.id }), Set([localOnly.id, sharedId]))
    }

    // MARK: - Cap / prune

    func testPruneToCapKeepsNewestByDate() {
        let results = (1...5).map { makeResult(daysAgo: $0) } // daysAgo 1 = newest

        let pruned = GameResultSyncMerge.pruneToCap(results, limit: 3)

        XCTAssertEqual(pruned.count, 3)
        // Newest three are daysAgo 1, 2, 3.
        let keptDays = Set(pruned.map { Calendar.current.dateComponents([.day], from: $0.date, to: Date()).day })
        XCTAssertEqual(keptDays, Set([1, 2, 3]))
    }

    func testPruneToCapUnderLimitReturnsInputUnchanged() {
        let results = [makeResult(daysAgo: 1), makeResult(daysAgo: 2)]

        let pruned = GameResultSyncMerge.pruneToCap(results, limit: 10)

        XCTAssertEqual(pruned.map { $0.id }, results.map { $0.id })
    }

    func testPruneToCapDeterministicOnDateTies() {
        // All same puzzle date → tie-break by id must be stable regardless of input order.
        let tiedDate = date(daysAgo: 1)
        let resultA = makeResult(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(), exactDate: tiedDate)
        let resultB = makeResult(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(), exactDate: tiedDate)
        let resultC = makeResult(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID(), exactDate: tiedDate)

        let forward = GameResultSyncMerge.pruneToCap([resultA, resultB, resultC], limit: 2)
        let reversed = GameResultSyncMerge.pruneToCap([resultC, resultB, resultA], limit: 2)

        XCTAssertEqual(forward.map { $0.id }, reversed.map { $0.id })
        XCTAssertEqual(Set(forward.map { $0.id }), Set([resultA.id, resultB.id]))
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
