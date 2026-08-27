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

    func testParseWordle_PeriodGroupedPuzzleNumber() throws {
        // Some locales group the puzzle number with a period instead of a comma.
        let shareText = "Wordle 1.492 3/6\n\n⬛🟨⬛⬛⬛\n🟩⬛🟩🟨⬛\n🟩🟩🟩🟩🟩"
        let result = try parser.parse(shareText, for: Game.wordle)
        XCTAssertEqual(result.score, 3)
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

    func testParseConnections_GridWithSpacesBetweenSquares() throws {
        // Some paste paths insert spaces between squares, e.g. "🟩 🟩 🟩 🟩".
        let shareText = "Connections\nPuzzle #687\n🟩 🟩 🟩 🟩\n🟨 🟨 🟨 🟨\n🟪 🟪 🟪 🟪\n🟦 🟦 🟦 🟦"
        let result = try parser.parse(shareText, for: Game.connections)
        XCTAssertEqual(result.parsedData["solvedCategories"], "4")
        XCTAssertTrue(result.completed)
    }

    func testParseConnections_NoGrid_ThrowsRatherThanFabricatingALoss() throws {
        // Header-only text with no readable grid must not be recorded as a
        // fabricated 0/4 loss — that would silently wipe the user's streak.
        XCTAssertThrowsError(try parser.parse("Connections\nPuzzle #687", for: Game.connections)) { error in
            XCTAssertTrue(error is ParsingError)
        }
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

    func testParseSpellingBee_NYTShareSentence() throws {
        let shareText = "Spelling Bee - I found 42 words, including the pangram!"
        let result = try parser.parse(shareText, for: Game.spellingBee)
        XCTAssertEqual(result.gameName, "spellingbee")
        XCTAssertEqual(result.score, 42)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["wordsFound"], "42")
        XCTAssertEqual(result.parsedData["hasPangram"], "true")
        XCTAssertEqual(result.parsedData["shareFormat"], "sentence")
    }

    func testParseSpellingBee_NonGeniusRank_StillCompleted() throws {
        // Spelling Bee has no lose state — any successfully parsed result counts
        // as completed regardless of rank, so a same-day result parsed from either
        // share format doesn't disagree and wipe the user's streak.
        let shareText = "Spelling Bee\nScore: 40\nWords: 10\nRank: Solid"
        let result = try parser.parse(shareText, for: Game.spellingBee)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["rank"], "Solid")
    }

    func testParseSpellingBee_NYTStructuredShare() throws {
        let shareText = """
        NYT Spelling Bee May 19, 2026
        Rank: Genius
        Score: 150
        Words found: 25
        Pangrams: 1
        """
        let result = try parser.parse(shareText, for: Game.spellingBee)
        XCTAssertEqual(result.score, 150)
        XCTAssertEqual(result.parsedData["wordsFound"], "25")
        XCTAssertEqual(result.parsedData["rank"], "Genius")
        XCTAssertEqual(result.parsedData["pangrams"], "1")
        XCTAssertEqual(result.parsedData["shareFormat"], "structured")
        XCTAssertTrue(result.completed)
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

    func testParseMiniCrossword_NYTAppShareSentence() throws {
        let shareText = """
        I solved the 4/28/2025 New York Times
        Mini Crossword in 0:22!
        """
        let result = try parser.parse(shareText, for: Game.miniCrossword)
        XCTAssertEqual(result.gameName, "minicrossword")
        XCTAssertEqual(result.score, 22)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["completionTime"], "0:22")
    }

    // MARK: - Strands Tests

    func testParseStrands_Perfect_NoHints() throws {
        let result = try parser.parse("Strands #580\n\"Bring it home\"\n🔵🔵🔵\n🔵🟡🔵🔵\n🔵", for: Game.strands)
        XCTAssertEqual(result.gameName, "strands")
        XCTAssertEqual(result.score, 0)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["hintCount"], "0")
    }

    func testParseStrands_CurlyQuoteTheme() throws {
        // Real NYT shares wrap the theme in curly quotes (U+201C/U+201D), not
        // straight ASCII quotes.
        let shareText = "Strands #350\n\u{201C}Knot your average puzzle\u{201D}\n🔵🔵🔵🟡\n🔵🔵🔵"
        let result = try parser.parse(shareText, for: Game.strands)
        XCTAssertEqual(result.parsedData["theme"], "Knot your average puzzle")
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
        // No time parses — don't fabricate a 0-second solve (that would rank as
        // the best possible score under LeaderboardScoring). The puzzle is still
        // recorded as completed with an honest nil score.
        let result = try parser.parse("Queens #522\n👑\nlnkd.in/queens.", for: Game.linkedinQueens)
        XCTAssertNil(result.score)
        XCTAssertTrue(result.completed)
    }

    func testParseLinkedInQueens_CombinedMultiGamePost_DoesNotStealAnotherGamesTime() throws {
        // Users often post their whole daily set in one comment. Queens must pick
        // up its OWN time (0:42), not Tango's (0:51), which appears earlier in the text.
        let shareText = """
        Tango #669 | 0:51 🌗
        Queens #829 | 0:42 👑
        Zip #508 | 0:33 🏁
        """
        let result = try parser.parse(shareText, for: Game.linkedinQueens)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "829")
        XCTAssertEqual(result.parsedData["time"], "0:42")
        XCTAssertEqual(result.score, 42)
    }

    func testParseLinkedInQueens_NoHashWithTimeLabel() throws {
        let shareText = """
        Queens 522
        Time: 1:11
        👑👑👑👑👑
        """
        let result = try parser.parse(shareText, for: Game.linkedinQueens)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "522")
        XCTAssertEqual(result.score, 71)
        XCTAssertEqual(result.parsedData["time"], "1:11")
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

    func testParseLinkedInTango_NoTime() throws {
        // No time parses — don't fabricate a 0-second solve; still completed with a nil score.
        let result = try parser.parse("Tango #362\nlnkd.in/tango.", for: Game.linkedinTango)
        XCTAssertNil(result.score)
        XCTAssertTrue(result.completed)
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

    func testParseLinkedInCrossclimb_NoTime() throws {
        // No time parses — don't fabricate a 0-second solve; still completed with a nil score.
        let result = try parser.parse("Crossclimb #522\nlnkd.in/crossclimb.", for: Game.linkedinCrossclimb)
        XCTAssertNil(result.score)
        XCTAssertTrue(result.completed)
    }

    // MARK: - Zip Tests

    func testParseLinkedInZip_WithBacktrack() throws {
        let shareText = "Zip #201\n0:23 🏁\nWith 1 backtrack 🛑\nlnkd.in/zip."
        let result = try parser.parse(shareText, for: Game.linkedinZip)
        XCTAssertEqual(result.gameName, "linkedinzip")
        XCTAssertEqual(result.score, 23)
        // The backtrack count is a real capture, not a dead optional group — it
        // must reflect the actual "With 1 backtrack" text.
        XCTAssertEqual(result.parsedData["backtrackCount"], "1")
    }

    func testParseLinkedInZip_NoBacktrack() throws {
        let result = try parser.parse("Zip #201\n0:37 🏁\nlnkd.in/zip.", for: Game.linkedinZip)
        XCTAssertEqual(result.score, 37)
        XCTAssertEqual(result.parsedData["backtrackCount"], "0")
    }

    func testParseLinkedInZip_NoTime() throws {
        // No time parses — don't fabricate a 0-second solve; still completed with a nil score.
        let result = try parser.parse("Zip #201\nlnkd.in/zip.", for: Game.linkedinZip)
        XCTAssertNil(result.score)
        XCTAssertTrue(result.completed)
    }

    // MARK: - Mini Sudoku Tests

    func testParseLinkedInMiniSudoku_Success() throws {
        // No time in this legacy share format — must store a nil score (not 0,
        // which would read as an instant solve under .lowerTimeSeconds scoring)
        // while still recording the puzzle as completed.
        let result = try parser.parse("Mini Sudoku puzzle #45 completed", for: Game.linkedinMiniSudoku)
        XCTAssertEqual(result.gameName, "linkedinminisudoku")
        XCTAssertNil(result.score)
        XCTAssertTrue(result.completed)
    }

    func testParseLinkedInMiniSudoku_InvalidFormat() throws {
        XCTAssertThrowsError(try parser.parse("This is not a Mini Sudoku result", for: Game.linkedinMiniSudoku)) { error in
            XCTAssertTrue(error is ParsingError)
        }
    }

    func testParseLinkedInMiniSudoku_CurrentShareFormat() throws {
        let shareText = """
        Mini Sudoku #142 | 0:39 and flawless ✏️
        🏅 I'm smarter than 95% of CEOs today!
        lnkd.in/minisudoku.
        """
        let result = try parser.parse(shareText, for: Game.linkedinMiniSudoku)
        XCTAssertEqual(result.gameName, "linkedinminisudoku")
        XCTAssertEqual(result.parsedData["puzzleNumber"], "142")
        XCTAssertEqual(result.parsedData["time"], "0:39")
        XCTAssertEqual(result.score, 39, "0:39 -> 0*60 + 39 = 39 seconds, stored as score")
        XCTAssertTrue(result.completed)
    }

    func testParseLinkedInMiniSudoku_DatedShareBlock() throws {
        let shareText = """
        Mini Sudoku - May 19, 2026
        Score: 95
        Time: 1:23
        Perfect Game
        """
        let result = try parser.parse(shareText, for: Game.linkedinMiniSudoku)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "May 19, 2026")
        XCTAssertEqual(result.parsedData["pointsScore"], "95")
        XCTAssertEqual(result.parsedData["time"], "1:23")
        XCTAssertEqual(result.parsedData["shareFormat"], "dated")
        XCTAssertEqual(result.score, 83, "1:23 -> 1*60 + 23 = 83 seconds, stored as score")
        XCTAssertTrue(result.completed)
    }

    // MARK: - Quordle Tests

    func testParseQuordle_Success() throws {
        let shareText = "Daily Quordle 1346\n6️⃣5️⃣\n9️⃣4️⃣"
        let result = try parser.parse(shareText, for: Game.quordle)
        XCTAssertEqual(result.gameName, "quordle")
        XCTAssertEqual(result.score, 24, "Sum of the four boards: 6 + 5 + 9 + 4 = 24")
        XCTAssertEqual(result.maxAttempts, 36, "4 boards x 9 max guesses per board")
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["score1"], "6")
        XCTAssertEqual(result.parsedData["score2"], "5")
        XCTAssertEqual(result.parsedData["score3"], "9")
        XCTAssertEqual(result.parsedData["score4"], "4")
    }

    func testParseQuordle_DifferentTotalsDoNotCollapse() throws {
        // Regression for the truncated-mean bug: totals of 17 and 18 both used to
        // store 4 (17/4 = 4, 18/4 = 4 under integer division). Storing the sum
        // keeps a better (fewer total guesses) game from reading as equal to a
        // worse (more total guesses) one.
        let betterTotal = try parser.parse("Daily Quordle 1346\n6️⃣5️⃣\n5️⃣1️⃣", for: Game.quordle) // 6+5+5+1=17
        let worseTotal = try parser.parse("Daily Quordle 1347\n6️⃣5️⃣\n5️⃣2️⃣", for: Game.quordle) // 6+5+5+2=18
        XCTAssertEqual(betterTotal.score, 17)
        XCTAssertEqual(worseTotal.score, 18)
        XCTAssertNotEqual(betterTotal.score, worseTotal.score)
    }

    func testParseQuordle_WithLeadingEmoji() throws {
        let shareText = """
        🙂 Daily Quordle 1576
        2️⃣8️⃣
        7️⃣9️⃣
        m-w.com/games/quordle/
        """
        let result = try parser.parse(shareText, for: Game.quordle)
        XCTAssertEqual(result.gameName, "quordle")
        XCTAssertEqual(result.score, 26, "Sum of the four boards: 2 + 8 + 7 + 9 = 26")
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "1576")
        XCTAssertEqual(result.parsedData["score1"], "2")
        XCTAssertEqual(result.parsedData["score2"], "8")
        XCTAssertEqual(result.parsedData["score3"], "7")
        XCTAssertEqual(result.parsedData["score4"], "9")
    }

    func testParseQuordle_WithoutLeadingEmoji() throws {
        let shareText = """
        Daily Quordle 1576
        2️⃣8️⃣
        7️⃣9️⃣
        m-w.com/games/quordle/
        """
        let result = try parser.parse(shareText, for: Game.quordle)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "1576")
        XCTAssertEqual(result.score, 26, "Sum of the four boards: 2 + 8 + 7 + 9 = 26")
        XCTAssertTrue(result.completed)
    }

    func testParseQuordle_WithDifferentLeadingEmoji() throws {
        let shareText = "🔥 Daily Quordle 1576\n2️⃣8️⃣\n7️⃣9️⃣"
        let result = try parser.parse(shareText, for: Game.quordle)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "1576")
        XCTAssertEqual(result.score, 26, "Sum of the four boards: 2 + 8 + 7 + 9 = 26")
    }

    func testParseQuordle_WithHashPuzzleNumber() throws {
        let shareText = "Daily Quordle #1576\n2️⃣8️⃣\n7️⃣9️⃣"
        let result = try parser.parse(shareText, for: Game.quordle)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "1576")
        XCTAssertEqual(result.score, 26, "Sum of the four boards: 2 + 8 + 7 + 9 = 26")
    }

    func testParseQuordle_WithPlainDigitScores() throws {
        let shareText = """
        Daily Quordle 1576
        2 8
        7 9
        m-w.com/games/quordle/
        """
        let result = try parser.parse(shareText, for: Game.quordle)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "1576")
        XCTAssertEqual(result.score, 26, "Sum of the four boards: 2 + 8 + 7 + 9 = 26")
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.parsedData["score1"], "2")
        XCTAssertEqual(result.parsedData["score4"], "9")
    }

    func testParseQuordle_PlainDigitScores_IgnoresTrailingStreakCommentary() throws {
        // A trailing commentary line containing digits (e.g. "12-day streak")
        // must not be ingested as extra fabricated scores — a fully-solved day
        // must still parse as completed.
        let shareText = """
        Daily Quordle 1576
        2 8
        7 9
        🏅 I'm on a 12-day streak!
        """
        let result = try parser.parse(shareText, for: Game.quordle)
        XCTAssertEqual(result.parsedData["completedPuzzles"], "4")
        XCTAssertTrue(result.completed)
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
        XCTAssertEqual(result.score, 22, "Sum of the four boards: 7 + 4 + 5 + 6 = 22")
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

    func testParseNerdle_BrandedHeader() throws {
        let result = try parser.parse("Nerdle 728 3/6", for: Game.nerdle)
        XCTAssertEqual(result.score, 3)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "728")
        XCTAssertTrue(result.completed)
    }

    func testParseNerdle_PeriodGroupedPuzzleNumber() throws {
        let result = try parser.parse("nerdlegame 1.728 3/6", for: Game.nerdle)
        XCTAssertEqual(result.score, 3)
        XCTAssertEqual(result.parsedData["puzzleNumber"], "1728")
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

    func testParsePips_EasyWithDifficultyEmoji() throws {
        let shareText = """
        Pips #46 Easy 🟢
        1:03
        """
        let result = try parser.parse(shareText, for: Game.pips)
        XCTAssertEqual(result.score, 63)
        XCTAssertEqual(result.parsedData["difficulty"], "Easy")
        XCTAssertEqual(result.parsedData["puzzleNumber"], "46")
    }

    func testParsePips_DifficultyOnSeparateLine() throws {
        let result = try parser.parse("Pips #120\nEasy 🟢 0:22", for: Game.pips)
        XCTAssertEqual(result.score, 22)
        XCTAssertEqual(result.parsedData["difficulty"], "Easy")
        XCTAssertEqual(result.parsedData["puzzleNumber"], "120")
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
            category: .custom,
            iconSystemName: "star", backgroundColor: CodableColor(.systemBlue),
            isPopular: false
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
            category: .custom,
            iconSystemName: "star", backgroundColor: CodableColor(.systemBlue),
            isPopular: false
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
            category: .custom,
            iconSystemName: "star", backgroundColor: CodableColor(.systemBlue),
            isPopular: false
        )
        let result = try parser.parse("TestGame X/6", for: customGame)
        XCTAssertNil(result.score)
        XCTAssertFalse(result.completed)
    }
}
