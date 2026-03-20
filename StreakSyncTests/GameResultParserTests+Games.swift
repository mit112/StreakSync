//
//  GameResultParserTests+Games.swift
//  StreakSyncTests
//
//  Per-game parser tests: Wordle, Connections, Spelling Bee, and more
//

@testable import StreakSync
import XCTest

extension GameResultParserTests {
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
        XCTAssertThrowsError(try parser.parse("Not a Spelling Bee result", for: Game.spellingBee)) { error in
            XCTAssertTrue(error is ParsingError)
        }
    }

    // MARK: - Mini Crossword Tests

    func testParseMiniCrossword_Success() throws {
        let result = try parser.parse("Mini Crossword\nCompleted in 2:30", for: Game.miniCrossword)
        XCTAssertEqual(result.gameName, "minicrossword")
        XCTAssertEqual(result.score, 150)
        XCTAssertTrue(result.completed)
    }

    func testParseMiniCrossword_Invalid() throws {
        XCTAssertThrowsError(try parser.parse("Mini Crossword\nNo time here", for: Game.miniCrossword)) { error in
            XCTAssertTrue(error is ParsingError)
        }
    }

    // MARK: - Strands Tests

    func testParseStrands_Perfect_NoHints() throws {
        let result = try parser.parse("Strands #580\n\"Bring it home\"\n🔵🔵🔵\n🔵🟡🔵🔵\n🔵", for: Game.strands)
        XCTAssertEqual(result.gameName, "strands")
        XCTAssertEqual(result.score, 0)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["hintCount"], "0")
    }

    func testParseStrands_WithHints() throws {
        let result = try parser.parse("Strands #580\n\"Theme\"\n💡🔵🔵💡\n🔵🟡🔵🔵\n🔵", for: Game.strands)
        XCTAssertEqual(result.score, 2)
        XCTAssertTrue(result.completed)
    }

    // MARK: - Queens Tests

    func testParseLinkedInQueens_Success() throws {
        let result = try parser.parse("Queens #522\n1:11 👑\nlnkd.in/queens.", for: Game.linkedinQueens)
        XCTAssertEqual(result.gameName, "linkedinqueens")
        XCTAssertEqual(result.score, 71)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "522")
    }

    func testParseLinkedInQueens_NoTime() throws {
        let result = try parser.parse("Queens #522\n👑\nlnkd.in/queens.", for: Game.linkedinQueens)
        XCTAssertEqual(result.score, 0)
    }

    // MARK: - Tango Tests

    func testParseLinkedInTango_Success() throws {
        let result = try parser.parse("Tango #362\n1:10 🌗\nlnkd.in/tango.", for: Game.linkedinTango)
        XCTAssertEqual(result.gameName, "linkedintango")
        XCTAssertEqual(result.score, 70)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "362")
    }

    func testParseLinkedInTango_InvalidFormat() throws {
        XCTAssertThrowsError(try parser.parse("This is not a Tango result", for: Game.linkedinTango)) { error in
            XCTAssertTrue(error is ParsingError)
        }
    }

    // MARK: - Crossclimb Tests

    func testParseLinkedInCrossclimb_Success() throws {
        let shareText = "Crossclimb #522\n2:08 🪜\n🏅 I'm on a 94-day win streak!\nlnkd.in/crossclimb."
        let result = try parser.parse(shareText, for: Game.linkedinCrossclimb)
        XCTAssertEqual(result.gameName, "linkedincrossclimb")
        XCTAssertEqual(result.score, 128)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "522")
    }

    func testParseLinkedInCrossclimb_InvalidFormat() throws {
        XCTAssertThrowsError(try parser.parse("Not a Crossclimb result at all", for: Game.linkedinCrossclimb)) { error in
            XCTAssertTrue(error is ParsingError)
        }
    }

    // MARK: - Zip Tests

    func testParseLinkedInZip_WithBacktrack() throws {
        let shareText = "Zip #201\n0:23 🏁\nWith 1 backtrack 🛑\nlnkd.in/zip."
        let result = try parser.parse(shareText, for: Game.linkedinZip)
        XCTAssertEqual(result.gameName, "linkedinzip")
        XCTAssertEqual(result.score, 23)
        XCTAssertEqual(result.parsedData["backtrackCount"], "0")
    }

    func testParseLinkedInZip_NoBacktrack() throws {
        let result = try parser.parse("Zip #201\n0:37 🏁\nlnkd.in/zip.", for: Game.linkedinZip)
        XCTAssertEqual(result.score, 37)
        XCTAssertEqual(result.parsedData["backtrackCount"], "0")
    }

    // MARK: - Mini Sudoku Tests

    func testParseLinkedInMiniSudoku_Success() throws {
        let result = try parser.parse("Mini Sudoku puzzle #45 completed", for: Game.linkedinMiniSudoku)
        XCTAssertEqual(result.gameName, "linkedinminisudoku")
        XCTAssertEqual(result.score, 1)
        XCTAssertTrue(result.completed)
    }

    func testParseLinkedInMiniSudoku_InvalidFormat() throws {
        XCTAssertThrowsError(try parser.parse("This is not a Mini Sudoku result", for: Game.linkedinMiniSudoku)) { error in
            XCTAssertTrue(error is ParsingError)
        }
    }

    // MARK: - Quordle Tests

    func testParseQuordle_Success() throws {
        let shareText = "Daily Quordle 1346\n6️⃣5️⃣\n9️⃣4️⃣"
        let result = try parser.parse(shareText, for: Game.quordle)
        XCTAssertEqual(result.gameName, "quordle")
        XCTAssertEqual(result.score, 6)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["score1"], "6")
        XCTAssertEqual(result.parsedData["score2"], "5")
        XCTAssertEqual(result.parsedData["score3"], "9")
        XCTAssertEqual(result.parsedData["score4"], "4")
    }

    func testParseQuordle_WithFailure() throws {
        let result = try parser.parse("Daily Quordle 1346\n6️⃣🟥\n9️⃣4️⃣", for: Game.quordle)
        XCTAssertNil(result.score)
        XCTAssertFalse(result.completed)
    }

    func testParseQuordle_WeeklyChallenge() throws {
        let shareText = "Weekly Quordle Challenge 143\n7️⃣4️⃣\n5️⃣6️⃣\nm-w.com/games/quordle/"
        let result = try parser.parse(shareText, for: Game.quordle)
        XCTAssertEqual(result.gameName, "quordle")
        XCTAssertEqual(result.score, 5)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["mode"], "weekly")
        XCTAssertEqual(result.parsedData["challengeNumber"], "143")
        XCTAssertEqual(result.parsedData["puzzleNumber"], "143")
    }

    func testParseQuordle_WeeklyChallengeMissingNumber_Throws() {
        XCTAssertThrowsError(try parser.parse("Weekly Quordle Challenge\n7️⃣4️⃣\n5️⃣6️⃣", for: Game.quordle)) { error in
            XCTAssertTrue(error is ParsingError)
        }
    }

    // MARK: - Nerdle Tests

    func testParseNerdle_Success() throws {
        let result = try parser.parse("nerdlegame 728 3/6", for: Game.nerdle)
        XCTAssertEqual(result.gameName, "nerdle")
        XCTAssertEqual(result.score, 3)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "728")
        XCTAssertTrue(result.completed)
    }

    func testParseNerdle_Failure() throws {
        let result = try parser.parse("nerdlegame 728 X/6", for: Game.nerdle)
        XCTAssertNil(result.score)
        XCTAssertFalse(result.completed)
    }

    // MARK: - Pips Tests

    func testParsePips_Easy() throws {
        let result = try parser.parse("Pips #46 Easy\n1:03", for: Game.pips)
        XCTAssertEqual(result.gameName, "pips")
        XCTAssertEqual(result.score, 63)
        XCTAssertEqual(result.parsedData["difficulty"], "Easy")
        XCTAssertEqual(result.parsedData["puzzleNumber"], "46")
    }

    func testParsePips_Hard() throws {
        let result = try parser.parse("Pips #46 Hard\n2:59", for: Game.pips)
        XCTAssertEqual(result.score, 179)
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

    // MARK: - Extensibility Coverage

    func testAllGamesHaveMatchingParserCase() {
        let games = Game.allAvailableGames
        XCTAssertFalse(games.isEmpty)

        for game in games {
            XCTAssertFalse(game.name.isEmpty)
            do {
                _ = try parser.parse("test X/6", for: game)
            } catch let error as ParsingError {
                if case .invalidFormat = error {
                    // Expected
                } else {
                    XCTFail("Parser for \(game.displayName) threw unexpected ParsingError: \(error)")
                }
            } catch {
                XCTFail("Parser for \(game.displayName) threw unexpected error: \(error)")
            }
        }
    }

    // MARK: - Generic Parser Tests

    func testParseGeneric_Success() throws {
        let customGame = Game(
            id: UUID(), name: "testgame", displayName: "Test Game",
            url: URL(string: "https://example.com")!, // swiftlint:disable:this force_unwrapping
            category: .word, resultPattern: #"TestGame \d+/\d+"#,
            iconSystemName: "star", backgroundColor: CodableColor(.systemBlue),
            isPopular: false, isCustom: true
        )
        let result = try parser.parse("TestGame 5/10", for: customGame)
        XCTAssertEqual(result.score, 5)
        XCTAssertEqual(result.maxAttempts, 10)
        XCTAssertTrue(result.completed)
    }

    func testParseGeneric_MultiDigit() throws {
        let customGame = Game(
            id: UUID(), name: "testgame", displayName: "Test Game",
            url: URL(string: "https://example.com")!, // swiftlint:disable:this force_unwrapping
            category: .word, resultPattern: #"TestGame \d+/\d+"#,
            iconSystemName: "star", backgroundColor: CodableColor(.systemBlue),
            isPopular: false, isCustom: true
        )
        let result = try parser.parse("TestGame 10/15", for: customGame)
        XCTAssertEqual(result.score, 10)
        XCTAssertEqual(result.maxAttempts, 15)
        XCTAssertTrue(result.completed)
    }

    func testParseGeneric_FailureX() throws {
        let customGame = Game(
            id: UUID(), name: "testgame", displayName: "Test Game",
            url: URL(string: "https://example.com")!, // swiftlint:disable:this force_unwrapping
            category: .word, resultPattern: #"TestGame \d+/\d+"#,
            iconSystemName: "star", backgroundColor: CodableColor(.systemBlue),
            isPopular: false, isCustom: true
        )
        let result = try parser.parse("TestGame X/6", for: customGame)
        XCTAssertNil(result.score)
        XCTAssertFalse(result.completed)
    }
}
