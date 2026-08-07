//
//  GameResultParserTests.swift
//  StreakSyncTests
//
//  Unit tests for GameResultParser to ensure all game formats are parsed correctly
//

@testable import StreakSync
import XCTest

class GameResultParserTests: XCTestCase {
    var parser: GameResultParser!
    var testGame: Game!

    override func setUpWithError() throws {
        parser = GameResultParser()
        testGame = Game.linkedinPinpoint
    }

    override func tearDownWithError() throws {
        parser = nil
        testGame = nil
    }

    // MARK: - LinkedIn Pinpoint Tests

    func testParseLinkedInPinpoint_NewEmojiFormat() throws {
        // Test the new emoji-based format
        let shareText = """
        Pinpoint #542
        🤔 📌 ⬜ ⬜ ⬜ (2/5)
        🏅 I'm in the Top 25% of my connections today!
        lnkd.in/pinpoint.
        """

        let result = try parser.parse(shareText, for: testGame)

        XCTAssertEqual(result.gameName, "linkedinpinpoint")
        XCTAssertEqual(result.score, 2)
        XCTAssertEqual(result.maxAttempts, 5)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "542")
        XCTAssertEqual(result.parsedData["guessCount"], "2")
        XCTAssertEqual(result.parsedData["shareFormat"], "emoji_based")
    }

    func testParseLinkedInPinpoint_NewEmojiFormat_Top10Percent() throws {
        // Test the new emoji-based format with different percentage text
        let shareText = """
        Pinpoint #542
        🤔 📌 ⬜ ⬜ ⬜ (2/5)
        🏅 I'm in the Top 10% of all players today!
        lnkd.in/pinpoint.
        """

        let result = try parser.parse(shareText, for: testGame)

        XCTAssertEqual(result.gameName, "linkedinpinpoint")
        XCTAssertEqual(result.score, 2)
        XCTAssertEqual(result.maxAttempts, 5)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "542")
        XCTAssertEqual(result.parsedData["guessCount"], "2")
        XCTAssertEqual(result.parsedData["shareFormat"], "emoji_based")
    }

    func testParseLinkedInPinpoint_NewEmojiFormat_Streak() throws {
        // Test the new emoji-based format with streak text
        let shareText = """
        Pinpoint #542
        🤔 📌 ⬜ ⬜ ⬜ (2/5)
        🏅 I started a new streak today!
        lnkd.in/pinpoint.
        """

        let result = try parser.parse(shareText, for: testGame)

        XCTAssertEqual(result.gameName, "linkedinpinpoint")
        XCTAssertEqual(result.score, 2)
        XCTAssertEqual(result.maxAttempts, 5)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "542")
        XCTAssertEqual(result.parsedData["guessCount"], "2")
        XCTAssertEqual(result.parsedData["shareFormat"], "emoji_based")
    }

    func testParseLinkedInPinpoint_OriginalFormat() throws {
        // Test the original format as fallback
        let shareText = """
        Pinpoint #522 | 5 guesses
        1️⃣  | 1% match
        2️⃣  | 5% match
        3️⃣  | 82% match
        4️⃣  | 28% match
        5️⃣  | 100% match 📌
        lnkd.in/pinpoint.
        """

        let result = try parser.parse(shareText, for: testGame)

        XCTAssertEqual(result.gameName, "linkedinpinpoint")
        XCTAssertEqual(result.score, 5)
        XCTAssertEqual(result.maxAttempts, 5)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "522")
        XCTAssertEqual(result.parsedData["guessCount"], "5")
        XCTAssertEqual(result.parsedData["shareFormat"], "original")
    }

    func testParseLinkedInPinpoint_OriginalFormat_NoExplicitGuesses() throws {
        // Test the original format without explicit guess count
        let shareText = """
        Pinpoint #522
        1️⃣  | 1% match
        2️⃣  | 5% match
        3️⃣  | 82% match
        4️⃣  | 28% match
        5️⃣  | 100% match 📌
        lnkd.in/pinpoint.
        """

        let result = try parser.parse(shareText, for: testGame)

        XCTAssertEqual(result.gameName, "linkedinpinpoint")
        XCTAssertEqual(result.score, 5) // Should count emoji lines
        XCTAssertEqual(result.maxAttempts, 5)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "522")
        XCTAssertEqual(result.parsedData["guessCount"], "5")
        XCTAssertEqual(result.parsedData["shareFormat"], "original")
    }

    func testParseLinkedInPinpoint_InvalidFormat() throws {
        // Test with invalid format
        let shareText = "This is not a valid Pinpoint result"

        XCTAssertThrowsError(try parser.parse(shareText, for: testGame)) { error in
            XCTAssertTrue(error is ParsingError)
        }
    }

    // MARK: - Edge Cases

    func testParseLinkedInPinpoint_EmojiFormat_AllAttemptsUsed() throws {
        // Test when all 5 attempts are used
        let shareText = """
        Pinpoint #542
        🤔 📌 📌 📌 📌 📌 (5/5)
        🏅 I'm in the Top 25% of my connections today!
        lnkd.in/pinpoint.
        """

        let result = try parser.parse(shareText, for: testGame)

        XCTAssertEqual(result.gameName, "linkedinpinpoint")
        XCTAssertEqual(result.score, 5)
        XCTAssertEqual(result.maxAttempts, 5)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "542")
        XCTAssertEqual(result.parsedData["guessCount"], "5")
        XCTAssertEqual(result.parsedData["shareFormat"], "emoji_based")
    }

    func testParseLinkedInPinpoint_EmojiFormat_OneAttempt() throws {
        // Test with only 1 attempt used
        let shareText = """
        Pinpoint #542
        🤔 📌 ⬜ ⬜ ⬜ ⬜ (1/5)
        🏅 I'm in the Top 25% of my connections today!
        lnkd.in/pinpoint.
        """

        let result = try parser.parse(shareText, for: testGame)

        XCTAssertEqual(result.gameName, "linkedinpinpoint")
        XCTAssertEqual(result.score, 1)
        XCTAssertEqual(result.maxAttempts, 5)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "542")
        XCTAssertEqual(result.parsedData["guessCount"], "1")
        XCTAssertEqual(result.parsedData["shareFormat"], "emoji_based")
    }

    func testParseLinkedInPinpoint_EmojiFormat_ThinkingFacesThenPin() throws {
        // Reported case: multiple thinking faces followed by a pin and (5/5)
        let shareText = """
        Pinpoint #559

        🤔 🤔 🤔 🤔 📌 (5/5)

        🏅 I'm on a 2-day win streak!

        lnkd.in/pinpoint.
        """

        let result = try parser.parse(shareText, for: testGame)

        XCTAssertEqual(result.gameName, "linkedinpinpoint")
        XCTAssertEqual(result.score, 5)
        XCTAssertEqual(result.maxAttempts, 5)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "559")
        XCTAssertEqual(result.parsedData["guessCount"], "5")
        XCTAssertEqual(result.parsedData["shareFormat"], "emoji_based")
    }

    func testPinpointScoreEmoji_NotCompletedShowsCross() {
        // When Pinpoint is not completed (e.g., 5/5 without 📌), show red cross emoji
        let result = GameResult(
            gameId: testGame.id,
            gameName: "linkedinpinpoint",
            date: Date(),
            score: 5,
            maxAttempts: 5,
            completed: false,
            sharedText: "Pinpoint #554 | 5 guesses\n1️⃣ | 81% match\n2️⃣ | 92% match\n3️⃣ | 2% match\n4️⃣ | 5% match\n5️⃣ | 6% match\nlnkd.in/pinpoint.",
            parsedData: ["puzzleNumber": "554", "guessCount": "5"]
        )

        XCTAssertEqual(result.displayScore, "5 guesses")
        XCTAssertEqual(result.scoreEmoji, "❌")
    }

    // MARK: - Canonical Puzzle Date (T1-3)

    private static let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return cal
    }()

    private func utcNoon(year: Int, month: Int, day: Int) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return try XCTUnwrap(Self.utcCalendar.date(from: components))
    }

    func testCanonicalDate_WordleAnchorMapsToPublicationDay() throws {
        let date = try XCTUnwrap(
            GameResultParser.canonicalPuzzleDate(gameName: "wordle", parsedData: ["puzzleNumber": "1875"])
        )
        XCTAssertEqual(date, try utcNoon(year: 2026, month: 8, day: 7))
    }

    func testCanonicalDate_ConsecutivePuzzlesAreExactlyOneDayApart() throws {
        let earlier = try XCTUnwrap(
            GameResultParser.canonicalPuzzleDate(gameName: "wordle", parsedData: ["puzzleNumber": "1874"])
        )
        let later = try XCTUnwrap(
            GameResultParser.canonicalPuzzleDate(gameName: "wordle", parsedData: ["puzzleNumber": "1875"])
        )
        // Exactly 24h apart, so the streak calendar reads them as one day apart in
        // any device time zone — the core timezone-immunity property.
        XCTAssertEqual(later.timeIntervalSince(earlier), 86_400, accuracy: 1)
        XCTAssertEqual(GameDateHelper.daysBetween(from: earlier, to: later), 1)
    }

    func testCanonicalDate_CommaFormattedNumberParses() throws {
        let date = try XCTUnwrap(
            GameResultParser.canonicalPuzzleDate(gameName: "wordle", parsedData: ["puzzleNumber": "1,875"])
        )
        XCTAssertEqual(date, try utcNoon(year: 2026, month: 8, day: 7))
    }

    func testCanonicalDate_WeeklyQuordleFallsBack() {
        XCTAssertNil(
            GameResultParser.canonicalPuzzleDate(
                gameName: "quordle",
                parsedData: ["puzzleNumber": "143", "mode": "weekly"]
            )
        )
    }

    func testCanonicalDate_GamesWithoutSequentialNumberFallBack() {
        XCTAssertNil(GameResultParser.canonicalPuzzleDate(gameName: "spellingbee", parsedData: [:]))
        XCTAssertNil(GameResultParser.canonicalPuzzleDate(gameName: "pips", parsedData: ["puzzleNumber": "50"]))
        XCTAssertNil(GameResultParser.canonicalPuzzleDate(gameName: "minicrossword", parsedData: [:]))
    }

    func testParseAppliesCanonicalDate_Wordle() throws {
        let older = try parser.parse("Wordle 1,000 3/6", for: Game.wordle)
        let newer = try parser.parse("Wordle 1,001 4/6", for: Game.wordle)
        // Dated by the puzzle, not receipt: #1000 lands well in the past, not ≈ now.
        XCTAssertLessThan(older.date, Date().addingTimeInterval(-86_400))
        // Consecutive puzzles are exactly one streak-day apart.
        XCTAssertEqual(GameDateHelper.daysBetween(from: older.date, to: newer.date), 1)
    }

    func testParseUsesReceiptDate_WhenNoAnchor() throws {
        // Mini Crossword has no puzzle number → keep receipt time (≈ now).
        let result = try parser.parse("Mini Crossword\nCompleted in 0:42", for: Game.miniCrossword)
        XCTAssertEqual(result.date.timeIntervalSinceNow, 0, accuracy: 5)
    }

    func testApplyingCanonicalDate_RejectsImplausibleFutureAnchor() {
        // A far-future puzzle number would map beyond "today"; the guard keeps the
        // receipt date rather than dating a result in the future.
        let receipt = Date()
        let result = GameResult(
            gameId: Game.wordle.id,
            gameName: "wordle",
            date: receipt,
            score: 3,
            maxAttempts: 6,
            completed: true,
            sharedText: "Wordle 99999 3/6",
            parsedData: ["puzzleNumber": "99999"]
        )
        let dated = GameResultParser.applyingCanonicalPuzzleDate(to: result)
        XCTAssertEqual(dated.date, receipt)
    }
}
