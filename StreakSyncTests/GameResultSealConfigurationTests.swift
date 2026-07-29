//
//  GameResultSealConfigurationTests.swift
//  StreakSyncTests
//
//  Result/game-to-seal text and symbol mapping, including the missing-game fallback
//

@testable import StreakSync
import XCTest

final class GameResultSealConfigurationTests: XCTestCase {
    private func makeResult(completed: Bool = true, score: Int? = 3) -> GameResult {
        GameResult(
            gameId: Game.wordle.id,
            gameName: Game.Names.wordle,
            date: Date(timeIntervalSince1970: 1_722_470_400),
            score: score,
            maxAttempts: 6,
            completed: completed,
            sharedText: "Wordle 1,234 3/6",
            parsedData: ["puzzleNumber": "1,234"]
        )
    }

    func testCompletedResultUsesSuccessStatus() {
        let result = makeResult(completed: true, score: 3)
        let config = GameResultSealConfiguration.make(result: result, game: .wordle)
        XCTAssertEqual(config.score, "3/6")
        XCTAssertEqual(config.statusText, "Completed")
        XCTAssertEqual(config.statusSystemImage, "checkmark.circle.fill")
    }

    func testIncompleteResultUsesFailureStatus() {
        let config = GameResultSealConfiguration.make(
            result: makeResult(completed: false, score: nil),
            game: .wordle
        )
        XCTAssertEqual(config.statusText, "Not Completed")
        XCTAssertEqual(config.statusSystemImage, "xmark.circle.fill")
    }

    func testMissingGameUsesSafeFallbackSymbol() {
        let config = GameResultSealConfiguration.make(result: makeResult(), game: nil)
        XCTAssertEqual(config.gameSystemImage, "gamecontroller")
    }

    func testMissingGameFallsBackToTheResultsOwnName() {
        let config = GameResultSealConfiguration.make(result: makeResult(), game: nil)
        XCTAssertEqual(config.gameName, Game.Names.wordle)
    }

    func testKnownGamePrefersItsDisplayNameAndSymbol() {
        let config = GameResultSealConfiguration.make(result: makeResult(), game: .wordle)
        XCTAssertEqual(config.gameName, "Wordle")
        XCTAssertEqual(config.gameSystemImage, "square.grid.3x3.fill")
    }
}
