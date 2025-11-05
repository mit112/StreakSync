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
        testGame = Game(
            id: UUID(),
            name: "linkedinpinpoint",
            displayName: "LinkedIn Pinpoint",
            category: .linkedin,
            scoringType: .lowerAttempts,
            maxAttempts: 5,
            isActive: true
        )
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
}
