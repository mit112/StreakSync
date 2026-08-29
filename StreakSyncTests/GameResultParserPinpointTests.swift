//
//  GameResultParserPinpointTests.swift
//  StreakSyncTests
//
//  Guards that the Pinpoint parser never invents a score for an unsolved puzzle
//  and never reads another game's rows out of a combined daily post.
//

@testable import StreakSync
import XCTest

final class GameResultParserPinpointTests: XCTestCase {
    private let parser = GameResultParser()
    private let game = Game.linkedinPinpoint

    /// A Pinpoint that was never solved and whose share carries no guess counter:
    /// no 📌, no "100% match", no "N guesses". The old fallback recorded score 1 —
    /// the *best possible* Pinpoint result — for a puzzle the user lost, which then
    /// won `AnalyticsComputer.computePersonalBests`' `min(by: score)`.
    func testNeverSolvedWithoutGuessCountDoesNotFabricateAScore() throws {
        let shareText = """
        Pinpoint #560
        🤔 🤔 🤔 🤔 🤔
        lnkd.in/pinpoint.
        """

        let result = try parser.parse(shareText, for: game)

        XCTAssertEqual(result.parsedData["puzzleNumber"], "560")
        XCTAssertNil(result.score, "an unsolved puzzle with no readable count must not score 1")
        XCTAssertFalse(result.completed)
        XCTAssertEqual(result.displayScore, "Did not solve")
    }

    /// Players post their whole LinkedIn set in one comment. Pinpoint has to read
    /// only its own rows — Crossclimb's "Fill order" keycaps are not Pinpoint
    /// guesses. Counting them also risks exceeding `maxAttempts`, which trips
    /// `GameResult`'s scoring assert and aborts the process in Debug.
    func testCombinedDailyPostDoesNotBorrowAnotherGamesRows() throws {
        let shareText = """
        Crossclimb #398 | 0:40 and flawless
        Fill order: 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ ⬆️ ⬇️ 🪜
        lnkd.in/crossclimb.

        Pinpoint #560
        🤔 🤔 🤔 🤔 🤔
        lnkd.in/pinpoint.
        """

        let result = try parser.parse(shareText, for: game)

        XCTAssertEqual(result.parsedData["puzzleNumber"], "560")
        XCTAssertNil(result.score, "Crossclimb's five keycaps are not five Pinpoint guesses")
        XCTAssertFalse(result.completed)
    }

    /// A malformed grid whose count is outside 1...maxAttempts. `.lowerGuesses`
    /// requires `1 <= score <= maxAttempts`, so passing the raw count through
    /// aborted the test host on the emoji path.
    func testOutOfRangeEmojiGridCountRecordsNoScore() throws {
        let shareText = """
        Pinpoint #561
        🤔 ⬜ ⬜ ⬜ ⬜ (0/5)
        lnkd.in/pinpoint.
        """

        let result = try parser.parse(shareText, for: game)

        XCTAssertEqual(result.parsedData["shareFormat"], "emoji_based")
        XCTAssertNil(result.score)
        XCTAssertFalse(result.completed)
    }

    /// The normal unsolved path still keeps a real guess count — only `completed`
    /// separates it from a win.
    func testUnsolvedOriginalFormatKeepsItsGuessCount() throws {
        let shareText = """
        Pinpoint #554 | 5 guesses
        1️⃣ | 81% match
        2️⃣ | 92% match
        3️⃣ | 2% match
        4️⃣ | 5% match
        5️⃣ | 6% match
        lnkd.in/pinpoint.
        """

        let result = try parser.parse(shareText, for: game)

        XCTAssertEqual(result.score, 5)
        XCTAssertFalse(result.completed)
        XCTAssertEqual(result.displayScore, "5 guesses")
        XCTAssertEqual(result.scoreEmoji, "❌")
    }
}
