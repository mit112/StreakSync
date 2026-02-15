//
//  LeaderboardScoringTests.swift
//  StreakSyncTests
//

import XCTest
@testable import StreakSync

final class LeaderboardScoringTests: XCTestCase {

    // MARK: - Helpers

    private func makeScore(
        gameId: UUID = Game.wordle.id,
        gameName: String = "Wordle",
        score: Int? = 3,
        maxAttempts: Int = 6,
        completed: Bool = true,
        currentStreak: Int? = nil
    ) -> DailyGameScore {
        DailyGameScore(
            id: "u|20250101|\(gameId.uuidString)",
            userId: "user1",
            dateInt: 20250101,
            gameId: gameId,
            gameName: gameName,
            score: score,
            maxAttempts: maxAttempts,
            completed: completed,
            currentStreak: currentStreak
        )
    }

    // MARK: - Lower Attempts / Lower Guesses

    func testAttemptsScoring_wordleSolvedIn3() {
        let pts = LeaderboardScoring.points(for: makeScore(score: 3, maxAttempts: 6), game: .wordle)
        XCTAssertEqual(pts, 4, "6 - 3 + 1 = 4")
    }

    func testAttemptsScoring_solvedIn1() {
        let pts = LeaderboardScoring.points(for: makeScore(score: 1, maxAttempts: 6), game: .wordle)
        XCTAssertEqual(pts, 6, "6 - 1 + 1 = 6")
    }

    func testAttemptsScoring_solvedOnLastAttempt() {
        let pts = LeaderboardScoring.points(for: makeScore(score: 6, maxAttempts: 6), game: .wordle)
        XCTAssertEqual(pts, 1, "6 - 6 + 1 = 1")
    }

    func testAttemptsScoring_incompleteReturnsZero() {
        let pts = LeaderboardScoring.points(for: makeScore(completed: false), game: .wordle)
        XCTAssertEqual(pts, 0)
    }

    func testAttemptsScoring_nilScoreReturnsZero() {
        let pts = LeaderboardScoring.points(for: makeScore(score: nil), game: .wordle)
        XCTAssertEqual(pts, 0)
    }

    func testAttemptsScoring_nilGameFallsBackToAttempts() {
        let pts = LeaderboardScoring.points(for: makeScore(score: 2, maxAttempts: 6), game: nil)
        XCTAssertEqual(pts, 5, "Falls back to attemptsPoints: 6 - 2 + 1 = 5")
    }

    // MARK: - Lower Hints (Strands)

    func testHintsScoring_twoHintsUsed() {
        let score = makeScore(gameId: Game.strands.id, gameName: "Strands", score: 2, maxAttempts: 10)
        let pts = LeaderboardScoring.points(for: score, game: .strands)
        XCTAssertEqual(pts, 9, "10 - 2 + 1 = 9")
    }

    func testHintsScoring_zeroHints() {
        let score = makeScore(gameId: Game.strands.id, gameName: "Strands", score: 0, maxAttempts: 10)
        let pts = LeaderboardScoring.points(for: score, game: .strands)
        XCTAssertEqual(pts, 11, "10 - 0 + 1 = 11")
    }

    func testHintsScoring_nilScoreReturnsZero() {
        let score = makeScore(gameId: Game.strands.id, gameName: "Strands", score: nil, maxAttempts: 10)
        let pts = LeaderboardScoring.points(for: score, game: .strands)
        XCTAssertEqual(pts, 0)
    }

    // MARK: - Lower Time (Mini Crossword, LinkedIn games)

    func testTimeBucketing_fastUnder30s() {
        let score = makeScore(gameId: Game.miniCrossword.id, gameName: "Mini", score: 25, maxAttempts: 0)
        let pts = LeaderboardScoring.points(for: score, game: .miniCrossword)
        XCTAssertEqual(pts, 7, "0-29s bucket = 7 points")
    }

    func testTimeBucketing_mediumAround90s() {
        let score = makeScore(gameId: Game.miniCrossword.id, gameName: "Mini", score: 95, maxAttempts: 0)
        let pts = LeaderboardScoring.points(for: score, game: .miniCrossword)
        XCTAssertEqual(pts, 4, "90-119s bucket = 4 points")
    }

    func testTimeBucketing_slowOver180s() {
        let score = makeScore(gameId: Game.miniCrossword.id, gameName: "Mini", score: 200, maxAttempts: 0)
        let pts = LeaderboardScoring.points(for: score, game: .miniCrossword)
        XCTAssertEqual(pts, 1, ">=180s bucket = 1 point")
    }

    func testTimeBucketing_ordering() {
        let fast = makeScore(gameId: Game.miniCrossword.id, gameName: "Mini", score: 25, maxAttempts: 0)
        let medium = makeScore(gameId: Game.miniCrossword.id, gameName: "Mini", score: 95, maxAttempts: 0)
        let slow = makeScore(gameId: Game.miniCrossword.id, gameName: "Mini", score: 190, maxAttempts: 0)
        let fastPts = LeaderboardScoring.points(for: fast, game: .miniCrossword)
        let medPts = LeaderboardScoring.points(for: medium, game: .miniCrossword)
        let slowPts = LeaderboardScoring.points(for: slow, game: .miniCrossword)
        XCTAssertTrue(fastPts > medPts, "Faster should score higher")
        XCTAssertTrue(medPts > slowPts, "Medium should score higher than slow")
    }

    func testTimeBucketing_zeroSeconds() {
        let score = makeScore(gameId: Game.miniCrossword.id, gameName: "Mini", score: 0, maxAttempts: 0)
        let pts = LeaderboardScoring.points(for: score, game: .miniCrossword)
        XCTAssertEqual(pts, 7, "0s should be in the fastest bucket")
    }

    // MARK: - Higher Is Better (Spelling Bee)

    func testHigherIsBetter_cappedAt7() {
        let score = makeScore(gameId: Game.spellingBee.id, gameName: "Spelling Bee", score: 50, maxAttempts: 0)
        let pts = LeaderboardScoring.points(for: score, game: .spellingBee)
        XCTAssertEqual(pts, 7, "Capped at 7 for cross-game comparability")
    }

    func testHigherIsBetter_lowScore() {
        let score = makeScore(gameId: Game.spellingBee.id, gameName: "Spelling Bee", score: 3, maxAttempts: 0)
        let pts = LeaderboardScoring.points(for: score, game: .spellingBee)
        XCTAssertEqual(pts, 3)
    }

    func testHigherIsBetter_nilScoreReturnsZero() {
        let score = makeScore(gameId: Game.spellingBee.id, gameName: "Spelling Bee", score: nil, maxAttempts: 0)
        let pts = LeaderboardScoring.points(for: score, game: .spellingBee)
        XCTAssertEqual(pts, 0)
    }

    // MARK: - Metric Labels

    func testMetricLabel_attempts() {
        let label = LeaderboardScoring.metricLabel(for: .wordle, points: 4)
        XCTAssertEqual(label, "3 guesses")
    }

    func testMetricLabel_hints_singular() {
        let label = LeaderboardScoring.metricLabel(for: .strands, points: 6)
        XCTAssertEqual(label, "1 hint")
    }

    func testMetricLabel_hints_plural() {
        let label = LeaderboardScoring.metricLabel(for: .strands, points: 4)
        XCTAssertEqual(label, "3 hints")
    }

    func testMetricLabel_time_fast() {
        let label = LeaderboardScoring.metricLabel(for: .miniCrossword, points: 7)
        XCTAssertEqual(label, "<30s")
    }

    func testMetricLabel_higherIsBetter() {
        let label = LeaderboardScoring.metricLabel(for: .spellingBee, points: 5)
        XCTAssertEqual(label, "5 pts")
    }

    func testMetricLabel_higherIsBetter_singular() {
        let label = LeaderboardScoring.metricLabel(for: .spellingBee, points: 1)
        XCTAssertEqual(label, "1 pt")
    }
}
