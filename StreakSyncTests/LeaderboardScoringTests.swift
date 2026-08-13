//
//  LeaderboardScoringTests.swift
//  StreakSyncTests
//

@testable import StreakSync
import XCTest

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
        // normalizedPoints(3, worst: 6): ratio = (6-3)/(6-1) = 0.6; round(0.6*6)+1 = round(3.6)+1 = 4+1 = 5
        XCTAssertEqual(pts, 5, "round((6-3)/(6-1) * 6) + 1 = round(3.6) + 1 = 5")
    }

    func testAttemptsScoring_solvedIn1() {
        let pts = LeaderboardScoring.points(for: makeScore(score: 1, maxAttempts: 6), game: .wordle)
        // normalizedPoints(1, worst: 6): ratio = (6-1)/(6-1) = 1.0; round(1.0*6)+1 = 6+1 = 7
        XCTAssertEqual(pts, 7, "Best possible attempt maps to the top of the scale: round(1.0*6)+1 = 7")
    }

    func testAttemptsScoring_solvedOnLastAttempt() {
        let pts = LeaderboardScoring.points(for: makeScore(score: 6, maxAttempts: 6), game: .wordle)
        // normalizedPoints(6, worst: 6): ratio = (6-6)/(6-1) = 0; round(0*6)+1 = 0+1 = 1
        XCTAssertEqual(pts, 1, "Worst possible attempt maps to the bottom of the scale: round(0*6)+1 = 1")
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
        // normalizedPoints(2, worst: 6): ratio = (6-2)/(6-1) = 0.8; round(0.8*6)+1 = round(4.8)+1 = 5+1 = 6
        XCTAssertEqual(pts, 6, "Falls back to attemptsPoints/normalizedPoints: round(4.8)+1 = 6")
    }

    // MARK: - Lower Hints (Strands)

    func testHintsScoring_twoHintsUsed() {
        let score = makeScore(gameId: Game.strands.id, gameName: "Strands", score: 2, maxAttempts: 10)
        let pts = LeaderboardScoring.points(for: score, game: .strands)
        // normalizedPoints(2, worst: 10): ratio = (10-2)/(10-1) = 8/9 = 0.8889; round(0.8889*6)+1 = round(5.333)+1 = 5+1 = 6
        XCTAssertEqual(pts, 6, "round((10-2)/9 * 6) + 1 = round(5.33) + 1 = 6")
    }

    func testHintsScoring_zeroHints() {
        let score = makeScore(gameId: Game.strands.id, gameName: "Strands", score: 0, maxAttempts: 10)
        let pts = LeaderboardScoring.points(for: score, game: .strands)
        // normalizedPoints clamps the value into 1...worst first, so 0 hints clamps
        // to 1 (the best case) rather than producing the old out-of-range 11 points:
        // ratio = (10-1)/(10-1) = 1.0; round(1.0*6)+1 = 7
        XCTAssertEqual(pts, 7, "0 hints clamps to the best case: round(1.0*6)+1 = 7 (was out-of-range 11 before normalization)")
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

    func testTimeBucketing_fallbackUnaffectedByNormalization() {
        // maxAttempts: 0 is not a plausible par, so these games (Queens/Tango/
        // Crossclimb/Zip all pass 0) must keep using the original fixed-bucket
        // formula exactly, not the new par-relative normalization.
        let score = makeScore(gameId: Game.linkedinQueens.id, gameName: "Queens", score: 65, maxAttempts: 0)
        let pts = LeaderboardScoring.points(for: score, game: .linkedinQueens)
        // bucket = min(6, 65/30) = min(6, 2) = 2; 7 - 2 = 5
        XCTAssertEqual(pts, 5, "Fixed bucket fallback preserved: 7 - (65/30) = 7 - 2 = 5")
    }

    // MARK: - Lower Time, par-relative (Pips)

    func testTimeBucketing_pipsEasyAndHardScoreComparablyWhenBothGood() {
        // Easy par = 90s, a 30s solve is proportionally about as good as a 160s
        // solve against Hard's 480s par — they should land on the same point value.
        let easy = makeScore(gameId: Game.pips.id, gameName: "pips", score: 30, maxAttempts: 90)
        let hard = makeScore(gameId: Game.pips.id, gameName: "pips", score: 160, maxAttempts: 480)
        let easyPts = LeaderboardScoring.points(for: easy, game: .pips)
        let hardPts = LeaderboardScoring.points(for: hard, game: .pips)
        // Easy: ratio = (90-30)/89 = 0.6742; round(0.6742*6)+1 = round(4.045)+1 = 5
        // Hard: ratio = (480-160)/479 = 0.6678; round(0.6678*6)+1 = round(4.007)+1 = 5
        XCTAssertEqual(easyPts, 5)
        XCTAssertEqual(hardPts, 5)
    }

    func testTimeBucketing_pipsHardSolveBeatsMediocreEasySolve() {
        // A mediocre Easy solve close to its 90s par should score worse than a
        // solidly-paced Hard solve against its 480s par — Hard is no longer
        // penalized on an absolute time axis for taking longer than Easy.
        let mediocreEasy = makeScore(gameId: Game.pips.id, gameName: "pips", score: 85, maxAttempts: 90)
        let goodHard = makeScore(gameId: Game.pips.id, gameName: "pips", score: 200, maxAttempts: 480)
        let easyPts = LeaderboardScoring.points(for: mediocreEasy, game: .pips)
        let hardPts = LeaderboardScoring.points(for: goodHard, game: .pips)
        // Easy: ratio = (90-85)/89 = 0.0562; round(0.0562*6)+1 = round(0.337)+1 = 0+1 = 1
        // Hard: ratio = (480-200)/479 = 0.5846; round(0.5846*6)+1 = round(3.507)+1 = 4+1 = 5
        XCTAssertEqual(easyPts, 1)
        XCTAssertEqual(hardPts, 5)
        XCTAssertTrue(hardPts > easyPts, "A good Hard solve should outscore a mediocre Easy solve")
    }

    // MARK: - Nil score returns zero across every scoring model

    func testNilScore_returnsZero_forEveryScoringModel() {
        XCTAssertEqual(
            LeaderboardScoring.points(for: makeScore(score: nil, maxAttempts: 6), game: .wordle), 0,
            "lowerAttempts"
        )
        XCTAssertEqual(
            LeaderboardScoring.points(for: makeScore(score: nil, maxAttempts: 5), game: .linkedinPinpoint), 0,
            "lowerGuesses"
        )
        XCTAssertEqual(
            LeaderboardScoring.points(for: makeScore(score: nil, maxAttempts: 10), game: .strands), 0,
            "lowerHints"
        )
        XCTAssertEqual(
            LeaderboardScoring.points(for: makeScore(score: nil, maxAttempts: 0), game: .spellingBee), 0,
            "higherIsBetter"
        )
        XCTAssertEqual(
            LeaderboardScoring.points(for: makeScore(score: nil, maxAttempts: 0), game: .miniCrossword), 0,
            "lowerTimeSeconds (fixed-bucket fallback)"
        )
        XCTAssertEqual(
            LeaderboardScoring.points(for: makeScore(score: nil, maxAttempts: 90), game: .pips), 0,
            "lowerTimeSeconds (par-relative)"
        )
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
    // These assert the TRUE raw metric is rendered — never reverse-derived from `points`.

    func testMetricLabel_attempts() {
        let label = LeaderboardScoring.metricLabel(for: .wordle, rawScore: 3)
        XCTAssertEqual(label, "3 guesses")
    }

    func testMetricLabel_attempts_singular() {
        let label = LeaderboardScoring.metricLabel(for: .wordle, rawScore: 1)
        XCTAssertEqual(label, "1 guess")
    }

    func testMetricLabel_hints_singular() {
        let label = LeaderboardScoring.metricLabel(for: .strands, rawScore: 1)
        XCTAssertEqual(label, "1 hint")
    }

    func testMetricLabel_hints_plural() {
        let label = LeaderboardScoring.metricLabel(for: .strands, rawScore: 3)
        XCTAssertEqual(label, "3 hints")
    }

    func testMetricLabel_hints_zero() {
        let label = LeaderboardScoring.metricLabel(for: .strands, rawScore: 0)
        XCTAssertEqual(label, "0 hints")
    }

    /// Regression: Strands has `maxAttempts` 10, not the Wordle-shaped 6 the old
    /// reverse-derivation silently assumed. Points-based reversal would have printed
    /// a fabricated number here; the raw hint count must be labeled exactly as recorded.
    func testMetricLabel_hints_strandsWithNonWordleMaxAttempts() {
        let score = makeScore(gameId: Game.strands.id, gameName: "Strands", score: 4, maxAttempts: 10)
        let points = LeaderboardScoring.points(for: score, game: .strands)
        // Sanity: points is the normalized 1...7 rank, unrelated to the raw hint count.
        XCTAssertNotEqual(points, 4)
        let label = LeaderboardScoring.metricLabel(for: .strands, rawScore: score.score)
        XCTAssertEqual(label, "4 hints", "The true recorded hint count, independent of maxAttempts or normalized points")
    }

    func testMetricLabel_time_subMinute() {
        let label = LeaderboardScoring.metricLabel(for: .miniCrossword, rawScore: 39)
        XCTAssertEqual(label, "0:39")
    }

    func testMetricLabel_time_overMinute() {
        let label = LeaderboardScoring.metricLabel(for: .miniCrossword, rawScore: 179)
        XCTAssertEqual(label, "2:59")
    }

    func testMetricLabel_higherIsBetter() {
        let label = LeaderboardScoring.metricLabel(for: .spellingBee, rawScore: 5)
        XCTAssertEqual(label, "5 pts")
    }

    func testMetricLabel_higherIsBetter_singular() {
        let label = LeaderboardScoring.metricLabel(for: .spellingBee, rawScore: 1)
        XCTAssertEqual(label, "1 pt")
    }

    func testMetricLabel_nilRawScore_returnsPlaceholder() {
        XCTAssertEqual(LeaderboardScoring.metricLabel(for: .wordle, rawScore: nil), "—")
        XCTAssertEqual(LeaderboardScoring.metricLabel(for: .strands, rawScore: nil), "—")
        XCTAssertEqual(LeaderboardScoring.metricLabel(for: .miniCrossword, rawScore: nil), "—")
        XCTAssertEqual(LeaderboardScoring.metricLabel(for: .spellingBee, rawScore: nil), "—")
    }
}
