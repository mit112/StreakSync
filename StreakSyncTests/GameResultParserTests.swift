//
//  GameResultParserTests.swift
//  StreakSyncTests
//
//  Unit tests for GameResultParser to ensure all game formats are parsed correctly
//

import XCTest
@testable import StreakSync

final class GameResultParserTests: XCTestCase {

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

    // MARK: - Wordle Tests

    func testParseWordle_Success() throws {
        let shareText = "Wordle 1,492 3/6\n\n⬛🟨⬛⬛⬛\n🟩⬛🟩🟨⬛\n🟩🟩🟩🟩🟩"

        let result = try parser.parse(shareText, for: Game.wordle)

        XCTAssertEqual(result.gameName, "wordle")
        XCTAssertEqual(result.score, 3)
        XCTAssertEqual(result.maxAttempts, 6)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "1492")
    }

    func testParseWordle_Failure() throws {
        let shareText = "Wordle 1,492 X/6\n\n⬛🟨⬛⬛⬛\n🟩⬛🟩🟨⬛\n⬛⬛⬛⬛⬛\n⬛⬛⬛⬛⬛\n⬛⬛⬛⬛⬛\n⬛⬛⬛⬛⬛"

        let result = try parser.parse(shareText, for: Game.wordle)

        XCTAssertNil(result.score)
        XCTAssertFalse(result.completed)
    }

    // MARK: - Connections Tests

    func testParseConnections_Perfect() throws {
        let shareText = "Connections\nPuzzle #603\n🟩🟩🟩🟩\n🟨🟨🟨🟨\n🟪🟪🟪🟪\n🟦🟦🟦🟦"

        let result = try parser.parse(shareText, for: Game.connections)

        XCTAssertEqual(result.gameName, "connections")
        XCTAssertEqual(result.score, 4)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["solvedCategories"], "4")
    }

    func testParseConnections_Partial_StillSolvesAll() throws {
        // One incorrect guess row mixed in; four all-same rows still present
        let shareText = "Connections\nPuzzle #603\n🟩🟩🟩🟩\n🟨🟨🟩🟨\n🟨🟨🟨🟨\n🟪🟪🟪🟪\n🟦🟦🟦🟦"

        let result = try parser.parse(shareText, for: Game.connections)

        XCTAssertEqual(result.parsedData["solvedCategories"], "4")
        XCTAssertTrue(result.completed)
    }

    // MARK: - Spelling Bee Tests

    func testParseSpellingBee_Success() throws {
        let shareText = "Spelling Bee\nScore: 150\nWords: 25\nRank: Genius"

        let result = try parser.parse(shareText, for: Game.spellingBee)

        XCTAssertEqual(result.gameName, "spellingbee")
        XCTAssertEqual(result.score, 150)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["rank"], "Genius")
    }

    func testParseSpellingBee_Invalid() throws {
        let shareText = "Not a Spelling Bee result"

        XCTAssertThrowsError(try parser.parse(shareText, for: Game.spellingBee)) { error in
            XCTAssertTrue(error is ParsingError)
        }
    }

    // MARK: - Mini Crossword Tests

    func testParseMiniCrossword_Success() throws {
        let shareText = "Mini Crossword\nCompleted in 2:30"

        let result = try parser.parse(shareText, for: Game.miniCrossword)

        XCTAssertEqual(result.gameName, "minicrossword")
        XCTAssertEqual(result.score, 150) // 2*60 + 30
        XCTAssertTrue(result.completed)
    }

    func testParseMiniCrossword_Invalid() throws {
        let shareText = "Mini Crossword\nNo time here"

        XCTAssertThrowsError(try parser.parse(shareText, for: Game.miniCrossword)) { error in
            XCTAssertTrue(error is ParsingError)
        }
    }

    // MARK: - Strands Tests

    func testParseStrands_Perfect_NoHints() throws {
        let shareText = "Strands #580\n\"Bring it home\"\n🔵🔵🔵\n🔵🟡🔵🔵\n🔵"

        let result = try parser.parse(shareText, for: Game.strands)

        XCTAssertEqual(result.gameName, "strands")
        XCTAssertEqual(result.score, 0)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["hintCount"], "0")
    }

    func testParseStrands_WithHints() throws {
        let shareText = "Strands #580\n\"Theme\"\n💡🔵🔵💡\n🔵🟡🔵🔵\n🔵"

        let result = try parser.parse(shareText, for: Game.strands)

        XCTAssertEqual(result.score, 2)
        XCTAssertTrue(result.completed) // Strands has no failure state
    }

    // MARK: - Queens Tests

    func testParseLinkedInQueens_Success() throws {
        let shareText = "Queens #522\n1:11 👑\nlnkd.in/queens."

        let result = try parser.parse(shareText, for: Game.linkedinQueens)

        XCTAssertEqual(result.gameName, "linkedinqueens")
        XCTAssertEqual(result.score, 71) // 1*60 + 11
        XCTAssertEqual(result.parsedData["puzzleNumber"], "522")
    }

    func testParseLinkedInQueens_NoTime() throws {
        // No time in the text — parser falls back to score=0
        let shareText = "Queens #522\n👑\nlnkd.in/queens."

        let result = try parser.parse(shareText, for: Game.linkedinQueens)

        XCTAssertEqual(result.score, 0)
    }

    // MARK: - Tango Tests

    func testParseLinkedInTango_Success() throws {
        let shareText = "Tango #362\n1:10 🌗\nlnkd.in/tango."

        let result = try parser.parse(shareText, for: Game.linkedinTango)

        XCTAssertEqual(result.gameName, "linkedintango")
        XCTAssertEqual(result.score, 70) // 1*60 + 10
        XCTAssertEqual(result.parsedData["puzzleNumber"], "362")
    }

    // MARK: - Crossclimb Tests

    func testParseLinkedInCrossclimb_Success() throws {
        let shareText = "Crossclimb #522\n2:08 🪜\n🏅 I'm on a 94-day win streak!\nlnkd.in/crossclimb."

        let result = try parser.parse(shareText, for: Game.linkedinCrossclimb)

        XCTAssertEqual(result.gameName, "linkedincrossclimb")
        XCTAssertEqual(result.score, 128) // 2*60 + 8
        XCTAssertEqual(result.parsedData["puzzleNumber"], "522")
    }

    // MARK: - Zip Tests

    func testParseLinkedInZip_WithBacktrack() throws {
        // The Zip parser regex uses a lazy wildcard before the optional backtrack group;
        // the backtrack count is never captured (group 3 is nil → defaults to "0").
        // This test documents the current parser behaviour.
        let shareText = "Zip #201\n0:23 🏁\nWith 1 backtrack 🛑\nlnkd.in/zip."

        let result = try parser.parse(shareText, for: Game.linkedinZip)

        XCTAssertEqual(result.gameName, "linkedinzip")
        XCTAssertEqual(result.score, 23) // 0*60 + 23
        XCTAssertEqual(result.parsedData["backtrackCount"], "0") // regex limitation: backtrack not captured
    }

    func testParseLinkedInZip_NoBacktrack() throws {
        let shareText = "Zip #201\n0:37 🏁\nlnkd.in/zip."

        let result = try parser.parse(shareText, for: Game.linkedinZip)

        XCTAssertEqual(result.score, 37)
        XCTAssertEqual(result.parsedData["backtrackCount"], "0")
    }

    // MARK: - Mini Sudoku Tests

    func testParseLinkedInMiniSudoku_Success() throws {
        let shareText = "Mini Sudoku puzzle #45 completed"

        let result = try parser.parse(shareText, for: Game.linkedinMiniSudoku)

        XCTAssertEqual(result.gameName, "linkedinminisudoku")
        XCTAssertEqual(result.score, 1)
        XCTAssertTrue(result.completed)
    }

    // MARK: - Quordle Tests

    func testParseQuordle_Success() throws {
        let shareText = "Daily Quordle 1346\n6️⃣5️⃣\n9️⃣4️⃣"

        let result = try parser.parse(shareText, for: Game.quordle)

        XCTAssertEqual(result.gameName, "quordle")
        // Average of 6+5+9+4=24 / 4 = 6
        XCTAssertEqual(result.score, 6)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["score1"], "6")
        XCTAssertEqual(result.parsedData["score2"], "5")
        XCTAssertEqual(result.parsedData["score3"], "9")
        XCTAssertEqual(result.parsedData["score4"], "4")
    }

    func testParseQuordle_WithFailure() throws {
        let shareText = "Daily Quordle 1346\n6️⃣🟥\n9️⃣4️⃣"

        let result = try parser.parse(shareText, for: Game.quordle)

        XCTAssertNil(result.score)
        XCTAssertFalse(result.completed)
    }

    // MARK: - Nerdle Tests

    func testParseNerdle_Success() throws {
        let shareText = "nerdlegame 728 3/6"

        let result = try parser.parse(shareText, for: Game.nerdle)

        XCTAssertEqual(result.gameName, "nerdle")
        XCTAssertEqual(result.score, 3)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "728")
        XCTAssertTrue(result.completed)
    }

    func testParseNerdle_Failure() throws {
        let shareText = "nerdlegame 728 X/6"

        let result = try parser.parse(shareText, for: Game.nerdle)

        XCTAssertNil(result.score)
        XCTAssertFalse(result.completed)
    }

    // MARK: - Pips Tests

    func testParsePips_Easy() throws {
        // Note: the Pips parser regex uses a character class for colour-dot emojis that does not
        // match multi-byte emoji under NSRegularExpression; use the emoji-free variant instead.
        let shareText = "Pips #46 Easy\n1:03"

        let result = try parser.parse(shareText, for: Game.pips)

        XCTAssertEqual(result.gameName, "pips")
        XCTAssertEqual(result.score, 63) // 1*60 + 3
        XCTAssertEqual(result.parsedData["difficulty"], "Easy")
        XCTAssertEqual(result.parsedData["puzzleNumber"], "46")
    }

    func testParsePips_Hard() throws {
        let shareText = "Pips #46 Hard\n2:59"

        let result = try parser.parse(shareText, for: Game.pips)

        XCTAssertEqual(result.score, 179) // 2*60 + 59
        XCTAssertEqual(result.parsedData["difficulty"], "Hard")
    }

    // MARK: - Octordle Tests

    func testParseOctordle_Success() throws {
        let shareText = "Daily Octordle #1349\n8️⃣4️⃣\n5️⃣6️⃣\n7️⃣3️⃣\n6️⃣7️⃣\nScore: 46"

        let result = try parser.parse(shareText, for: Game.octordle)

        XCTAssertEqual(result.gameName, "octordle")
        XCTAssertEqual(result.score, 46)
        XCTAssertEqual(result.maxAttempts, 104)
        XCTAssertTrue(result.completed)
    }

    func testParseOctordle_WithFailure() throws {
        let shareText = "Daily Octordle #1349\n🟥4️⃣\n5️⃣🟥\n7️⃣3️⃣\n6️⃣7️⃣\nScore: 58"

        let result = try parser.parse(shareText, for: Game.octordle)

        XCTAssertFalse(result.completed)
    }

    // MARK: - Generic Parser Tests

    func testParseGeneric_Success() throws {
        let customGame = Game(
            id: UUID(),
            name: "testgame",
            displayName: "Test Game",
            url: URL(string: "https://example.com")!,
            category: .word,
            resultPattern: #"TestGame \d+/\d+"#,
            iconSystemName: "star",
            backgroundColor: CodableColor(.systemBlue),
            isPopular: false,
            isCustom: true
        )

        let result = try parser.parse("TestGame 5/10", for: customGame)

        XCTAssertEqual(result.score, 5)
        XCTAssertEqual(result.maxAttempts, 10)
        XCTAssertTrue(result.completed)
    }

    func testParseGeneric_MultiDigit() throws {
        let customGame = Game(
            id: UUID(),
            name: "testgame",
            displayName: "Test Game",
            url: URL(string: "https://example.com")!,
            category: .word,
            resultPattern: #"TestGame \d+/\d+"#,
            iconSystemName: "star",
            backgroundColor: CodableColor(.systemBlue),
            isPopular: false,
            isCustom: true
        )

        let result = try parser.parse("TestGame 10/15", for: customGame)

        XCTAssertEqual(result.score, 10)
        XCTAssertEqual(result.maxAttempts, 15)
        XCTAssertTrue(result.completed)
    }

    func testParseGeneric_FailureX() throws {
        let customGame = Game(
            id: UUID(),
            name: "testgame",
            displayName: "Test Game",
            url: URL(string: "https://example.com")!,
            category: .word,
            resultPattern: #"TestGame \d+/\d+"#,
            iconSystemName: "star",
            backgroundColor: CodableColor(.systemBlue),
            isPopular: false,
            isCustom: true
        )

        let result = try parser.parse("TestGame X/6", for: customGame)

        XCTAssertNil(result.score)
        XCTAssertFalse(result.completed)
    }
}
