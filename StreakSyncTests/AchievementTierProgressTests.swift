//
//  AchievementTierProgressTests.swift
//  StreakSyncTests
//
//  Regression tests for bug B2: the tier progress bar must reflect every tier
//  earned, not only the highest one that happens to carry an unlock date.
//

@testable import StreakSync
import XCTest

final class AchievementTierProgressTests: XCTestCase {
    func testAllTiersUpToCurrentAreUnlockedEvenIfOnlyHighestDated() {
        // Legacy data: only the highest tier carries an unlock date, but
        // currentTier is Legendary. Every tier up to Legendary must read unlocked.
        var progress = AchievementProgress()
        progress.currentTier = .legendary
        progress.tierUnlockDates = [.legendary: Date()]

        for tier in AchievementTier.allCases {
            XCTAssertTrue(progress.isTierUnlocked(tier), "\(tier) should be unlocked at Legendary")
        }
    }

    func testTiersAboveCurrentAreLocked() {
        var progress = AchievementProgress()
        progress.currentTier = .gold
        progress.tierUnlockDates = [.gold: Date()]

        XCTAssertTrue(progress.isTierUnlocked(.bronze))
        XCTAssertTrue(progress.isTierUnlocked(.gold))
        XCTAssertFalse(progress.isTierUnlocked(.diamond))
        XCTAssertFalse(progress.isTierUnlocked(.legendary))
    }

    func testNothingUnlockedWhenNoTierReached() {
        let progress = AchievementProgress()
        XCTAssertFalse(progress.isTierUnlocked(.bronze))
    }
}
