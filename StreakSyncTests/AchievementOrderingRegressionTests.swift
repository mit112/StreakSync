//
//  AchievementOrderingRegressionTests.swift
//  StreakSyncTests
//
//  Guards the ordering contract between Variety Player and Completionist,
//  Variety Player's monotonic floor, and the progress bar's floor at an
//  already-earned tier.
//

@testable import StreakSync
import XCTest

@MainActor
final class AchievementOrderingRegressionTests: XCTestCase {
    private func makeResult(gameId: UUID, gameName: String) -> GameResult {
        GameResult(
            id: UUID(), gameId: gameId, gameName: gameName,
            date: Date(), score: 1, maxAttempts: 6,
            completed: true, sharedText: "Test result",
            parsedData: [:]
        )
    }

    /// Completionist counts categories at Gold or above, and runs last inside
    /// `checkAllAchievements`. Variety Player is lifetime-scoped, so its value has to
    /// come from the union with `uniqueGamesEver` *before* the pass — not from a bump
    /// applied by the caller afterwards, which is what used to happen. With the old
    /// ordering Variety Player was still Bronze when Completionist counted, so
    /// Completionist undercounted by one for a whole cycle.
    func testCompletionistSeesVarietyPlayerGoldEarnedFromLifetimeSetInTheSamePass() {
        let app = AppState()
        XCTAssertGreaterThanOrEqual(app.games.count, 8, "needs 8 distinct games")

        // Recent window only covers 3 games — Variety Player Bronze (threshold 3).
        let recent = Array(app.games.prefix(3))
        app.recentResults = recent.map { makeResult(gameId: $0.id, gameName: $0.name) }
        // Lifetime history covers 8 — Variety Player Gold (threshold 8).
        app._uniqueGamesEver = Set(app.games.prefix(8).map(\.id))

        // Two unrelated categories already at Gold, so Completionist reaches Bronze
        // (threshold 3) only if Variety Player is counted in this same pass.
        var seeded = AchievementFactory.createDefaultAchievements()
        for category in [AchievementCategory.streakMaster, .gameCollector] {
            guard let index = seeded.firstIndex(where: { $0.category == category }),
                  let goldThreshold = seeded[index].requirements
                      .first(where: { $0.tier == .gold })?.threshold else {
                return XCTFail("missing gold requirement for \(category)")
            }
            seeded[index].updateProgress(value: goldThreshold)
        }
        app._tieredAchievements = seeded

        app.checkTieredAchievements()

        let variety = app.tieredAchievements.first { $0.category == .varietyPlayer }
        XCTAssertEqual(variety?.progress.currentValue, 8)
        XCTAssertEqual(variety?.progress.currentTier, .gold)

        let completionist = app.tieredAchievements.first { $0.category == .completionist }
        XCTAssertEqual(
            completionist?.progress.currentValue, 3,
            "Completionist must count Variety Player's Gold in the same pass"
        )
        XCTAssertEqual(completionist?.progress.currentTier, .bronze)
    }

    /// Variety Player is lifetime-scoped and must never walk backwards. The snapshot
    /// unions the capped result window with `uniqueGamesEver`, but BOTH of those are
    /// bounded by what this device has seen: sync pulls at most 500 results, so a device
    /// restored from a longer history can hold a Variety Player value that predates
    /// everything in the window. The checker therefore also floors the new value at the
    /// achievement's own stored `currentValue`.
    ///
    /// Deleting that floor looks like a clean simplification of the checker and is not —
    /// it silently demotes restored users. This test is what makes that irreversible.
    func testVarietyPlayerNeverWalksBackwardsBelowItsStoredValue() {
        let app = AppState()
        XCTAssertGreaterThanOrEqual(app.games.count, 2, "needs 2 distinct games")

        // Everything this device can still see is 2 games — window and lifetime set alike.
        let visible = Array(app.games.prefix(2))
        app.recentResults = visible.map { makeResult(gameId: $0.id, gameName: $0.name) }
        app._uniqueGamesEver = Set(visible.map(\.id))

        // But the restored achievement already records 12 lifetime games.
        var seeded = AchievementFactory.createDefaultAchievements()
        guard let index = seeded.firstIndex(where: { $0.category == .varietyPlayer }) else {
            return XCTFail("missing Variety Player achievement")
        }
        seeded[index].updateProgress(value: 12)
        app._tieredAchievements = seeded

        app.recalculateAllTieredAchievementProgress()

        let variety = app.tieredAchievements.first { $0.category == .varietyPlayer }
        XCTAssertEqual(
            variety?.progress.currentValue, 12,
            "Variety Player must floor at its stored value, not fall back to the 2 visible games"
        )
    }

    /// Tiers are never revoked, and `progressDescription` already floors the displayed
    /// number at the earned tier's threshold. The bar has to agree: a missed day drops
    /// `currentValue`, and the bar used to slide back to ~3% while the label beside it
    /// still read "5/8".
    func testProgressBarDoesNotRegressBelowAnEarnedTier() {
        var achievement = AchievementFactory.createVarietyPlayerAchievement()
        achievement.updateProgress(value: 5)          // Silver (5), next is Gold (8)
        XCTAssertEqual(achievement.progress.currentTier, .silver)

        achievement.updateProgress(value: 1)          // history pruned / streak broken
        XCTAssertEqual(achievement.progress.currentTier, .silver, "tiers are never revoked")

        let percentage = achievement.progress.percentageToNextTier(
            requirements: achievement.requirements
        )
        XCTAssertEqual(percentage, 5.0 / 8.0, accuracy: 0.0001,
                       "bar must floor at the earned tier, matching progressDescription")
        XCTAssertEqual(achievement.progressDescription, "5/8")
    }
}
