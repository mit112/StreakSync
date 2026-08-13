//
//  DerivedStateReconciliationTests.swift
//  StreakSyncTests
//
//  Regression tests for state derived from the capped result set.
//

@testable import StreakSync
import XCTest

final class DerivedStateReconciliationTests: XCTestCase {
    // MARK: - Fixtures

    private func makeGame(id: UUID, name: String, scoringModel: ScoringModel = .lowerAttempts) -> Game {
        Game(
            id: id,
            name: name,
            displayName: name,
            url: URL(staticString: "https://example.com"),
            category: .word,
            iconSystemName: "textformat.abc",
            backgroundColor: CodableColor(.green),
            isPopular: true,
            scoringModel: scoringModel
        )
    }

    private func makeResult(gameId: UUID, name: String, date: Date, score: Int?, completed: Bool = true) -> GameResult {
        GameResult(
            id: UUID(),
            gameId: gameId,
            gameName: name,
            date: date,
            score: score,
            maxAttempts: 6,
            completed: completed,
            sharedText: "Test result"
        )
    }

    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private func makeTieredAchievement() -> TieredAchievement {
        TieredAchievement(
            category: .gameCollector,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 10),
                TierRequirement(tier: .silver, threshold: 50),
                TierRequirement(tier: .gold, threshold: 100)
            ]
        )
    }

    // MARK: - Achievement progress vs earned tier

    /// Deleting results used to leave a card reading "Gold — 5/100": the tier is never
    /// revoked, but currentValue was overwritten with the freshly recomputed number.
    func test_updateProgress_doesNotDropBelowEarnedTierThreshold() {
        var achievement = makeTieredAchievement()
        achievement.updateProgress(value: 120)
        XCTAssertEqual(achievement.progress.currentTier, .gold)

        achievement.updateProgress(value: 5)

        XCTAssertEqual(achievement.progress.currentTier, .gold, "Earned tiers are never revoked")
        XCTAssertEqual(
            achievement.progress.currentValue, 100,
            "Progress must not contradict the badge — it floors at the earned tier's threshold"
        )
    }

    func test_updateProgress_belowFirstTier_reportsRawValue() {
        var achievement = makeTieredAchievement()
        achievement.updateProgress(value: 4)

        XCTAssertNil(achievement.progress.currentTier)
        XCTAssertEqual(achievement.progress.currentValue, 4)
    }

    func test_updateProgress_tierDecisionsIgnoreTheFloor() {
        var achievement = makeTieredAchievement()
        achievement.updateProgress(value: 100)
        achievement.updateProgress(value: 0)

        // Flooring is presentational: it must not let a lapsed value re-cross a higher tier.
        XCTAssertEqual(achievement.progress.currentTier, .gold)
        XCTAssertEqual(achievement.progress.currentValue, 100)
    }

    // MARK: - Lifetime active days survive the result cap

    /// `recentResults` is capped at 500, so a user playing two games a day tops out near
    /// 250 distinct days and could never reach Marathon Runner's 365-day tier.
    func test_snapshotBuild_usesLifetimeDayCountWhenResultWindowIsCapped() {
        let gameId = UUID()
        let game = makeGame(id: gameId, name: "Wordle")
        let results = (0..<3).map { makeResult(gameId: gameId, name: "Wordle", date: daysAgo($0), score: 3) }

        let snapshot = AchievementSnapshot.build(
            from: results, games: [game], friendCount: 0, lifetimeActiveDayCount: 300
        )

        XCTAssertEqual(snapshot.uniqueDayCount, 300)
    }

    func test_snapshotBuild_prefersWindowCountWhenItIsLarger() {
        let gameId = UUID()
        let game = makeGame(id: gameId, name: "Wordle")
        let results = (0..<3).map { makeResult(gameId: gameId, name: "Wordle", date: daysAgo($0), score: 3) }

        let snapshot = AchievementSnapshot.build(
            from: results, games: [game], friendCount: 0, lifetimeActiveDayCount: 0
        )

        XCTAssertEqual(snapshot.uniqueDayCount, 3)
    }

    // MARK: - Personal bests determinism

    /// Best-score entries were taken with prefix(2) off a Dictionary, so the Personal Bests
    /// card showed a different arbitrary pair of games on each recompute.
    func test_computePersonalBests_isStableAcrossRepeatedComputations() {
        var games: [Game] = []
        var results: [GameResult] = []
        for index in 0..<6 {
            let id = UUID()
            let name = "Game\(index)"
            games.append(makeGame(id: id, name: name))
            results.append(makeResult(gameId: id, name: name, date: daysAgo(index + 1), score: index + 2))
        }

        let runs = (0..<8).map { _ in
            AnalyticsComputer.computePersonalBests(
                timeRange: .month, game: nil, games: games, streaks: [], results: results
            ).map(\.description)
        }

        for run in runs.dropFirst() {
            XCTAssertEqual(run, runs[0], "Personal bests must not reshuffle between recomputations")
        }
    }

    func test_computePersonalBests_bestScoreEntriesPreferMostRecent() {
        var games: [Game] = []
        var results: [GameResult] = []
        for index in 0..<4 {
            let id = UUID()
            let name = "Game\(index)"
            games.append(makeGame(id: id, name: name))
            // index 0 is the most recent day
            results.append(makeResult(gameId: id, name: name, date: daysAgo(index + 1), score: 3))
        }

        let bests = AnalyticsComputer.computePersonalBests(
            timeRange: .month, game: nil, games: games, streaks: [], results: results
        )
        let bestScoreGames = bests.filter { $0.type == .bestScore }.compactMap { $0.game?.displayName }

        XCTAssertEqual(bestScoreGames, ["Game0", "Game1"])
    }
}
