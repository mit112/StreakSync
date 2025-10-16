import XCTest
@testable import StreakSync

final class LeaderboardScoringTests: XCTestCase {
    func testAttemptsScoring() {
        let game = Game.wordle
        let score = DailyGameScore(id: "u|20250101|g", userId: "u", dateInt: 20250101, gameId: game.id, gameName: game.displayName, score: 3, maxAttempts: 6, completed: true)
        XCTAssertEqual(LeaderboardScoring.points(for: score, game: game), 4) // 6-3+1
    }

    func testHintsScoring() {
        let game = Game.strands
        let score = DailyGameScore(id: "u|20250101|g", userId: "u", dateInt: 20250101, gameId: game.id, gameName: game.displayName, score: 2, maxAttempts: 10, completed: true)
        XCTAssertEqual(LeaderboardScoring.points(for: score, game: game), 9) // 10-2+1
    }

    func testTimeBucketing() {
        let game = Game.miniCrossword
        let fast = DailyGameScore(id: "f|2025|g", userId: "f", dateInt: 20250101, gameId: game.id, gameName: game.displayName, score: 25, maxAttempts: 0, completed: true)
        let medium = DailyGameScore(id: "m|2025|g", userId: "m", dateInt: 20250101, gameId: game.id, gameName: game.displayName, score: 95, maxAttempts: 0, completed: true)
        let slow = DailyGameScore(id: "s|2025|g", userId: "s", dateInt: 20250101, gameId: game.id, gameName: game.displayName, score: 190, maxAttempts: 0, completed: true)
        XCTAssertTrue(LeaderboardScoring.points(for: fast, game: game) > LeaderboardScoring.points(for: medium, game: game))
        XCTAssertTrue(LeaderboardScoring.points(for: medium, game: game) > LeaderboardScoring.points(for: slow, game: game))
    }

    func testHigherIsBetter() {
        let game = Game.spellingBee
        let s1 = DailyGameScore(id: "1|2025|g", userId: "1", dateInt: 20250101, gameId: game.id, gameName: game.displayName, score: 3, maxAttempts: 0, completed: true)
        let s2 = DailyGameScore(id: "2|2025|g", userId: "2", dateInt: 20250101, gameId: game.id, gameName: game.displayName, score: 7, maxAttempts: 0, completed: true)
        XCTAssertTrue(LeaderboardScoring.points(for: s2, game: game) >= LeaderboardScoring.points(for: s1, game: game))
    }
}
