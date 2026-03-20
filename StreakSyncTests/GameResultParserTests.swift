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
}
