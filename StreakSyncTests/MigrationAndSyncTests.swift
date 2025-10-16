import XCTest
@testable import StreakSync

final class MigrationAndSyncTests: XCTestCase {
    func testMergePicksHigherProgressAndUnionDates() {
        let app = AppState()
        let local = [
            TieredAchievement(category: .streakMaster, requirements: [TierRequirement(tier: .bronze, threshold: 3), TierRequirement(tier: .silver, threshold: 7)], progress: AchievementProgress(currentValue: 3, currentTier: .bronze, tierUnlockDates: [.bronze: Date(timeIntervalSince1970: 1000)], lastUpdated: Date()))
        ]
        let remote = [
            TieredAchievement(category: .streakMaster, requirements: [TierRequirement(tier: .bronze, threshold: 3), TierRequirement(tier: .silver, threshold: 7)], progress: AchievementProgress(currentValue: 7, currentTier: .silver, tierUnlockDates: [.silver: Date(timeIntervalSince1970: 2000)], lastUpdated: Date()))
        ]
        let service = AchievementSyncService(appState: app)
        let merged = service.merge(local: local, remote: remote)
        XCTAssertEqual(merged.first?.progress.currentTier, .silver)
        XCTAssertNotNil(merged.first?.progress.tierUnlockDates[.bronze])
        XCTAssertNotNil(merged.first?.progress.tierUnlockDates[.silver])
    }
}


