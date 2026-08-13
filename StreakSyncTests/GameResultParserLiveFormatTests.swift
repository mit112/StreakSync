//
//  GameResultParserLiveFormatTests.swift
//  StreakSyncTests
//
//  Validates parsers against real-world share text fixtures collected from the web.
//

@testable import StreakSync
import XCTest

final class GameResultParserLiveFormatTests: XCTestCase {
    private let parser = GameResultParser()

    func testAllLiveFormatFixturesMatchExpectations() {
        var failures: [String] = []

        for fixture in GameShareFormatFixtures.all {
            do {
                _ = try parser.parse(fixture.shareText, for: fixture.game)
                if !fixture.shouldParse {
                    failures.append("\(fixture.game.displayName)/\(fixture.label): parsed but expected failure")
                }
            } catch {
                if fixture.shouldParse {
                    failures.append("\(fixture.game.displayName)/\(fixture.label): failed to parse — \(error)")
                }
            }
        }

        if !failures.isEmpty {
            XCTFail("Live format gaps (\(failures.count)):\n" + failures.joined(separator: "\n"))
        }
    }

    /// Asserts PARSED VALUES (not just "did it parse") for representative live fixtures.
    /// The Octordle case guards the UTF-16 NSRange fix: "Score:" sits after four keycap-emoji
    /// rows, so a grapheme-length search window dropped the value to the emoji-grid fallback.
    func testParsedValuesForRepresentativeFixtures() throws {
        let wordle = try parser.parse("Wordle 1,406 4/6*", for: Game.wordle)
        XCTAssertEqual(wordle.score, 4)
        XCTAssertEqual(wordle.maxAttempts, 6)
        XCTAssertTrue(wordle.completed)

        let nerdle = try parser.parse("nerdlegame 728 3/6", for: Game.nerdle)
        XCTAssertEqual(nerdle.score, 3)
        XCTAssertTrue(nerdle.completed)

        // Four keycap-emoji rows precede "Score: 61".
        let octordleText = "Daily Octordle #845\n8️⃣4️⃣\n5️⃣🔟\n9️⃣6️⃣\n🕛7️⃣\nScore: 61"
        let octordle = try parser.parse(octordleText, for: Game.octordle)
        XCTAssertEqual(octordle.score, 61)
        XCTAssertEqual(octordle.maxAttempts, 104)
    }

    /// Regression net for GameDetector: `parser.parse(text, for: game)` above is
    /// handed the game directly, so it never exercises detection. Every fixture
    /// the parser is expected to accept must also be independently *detectable*
    /// from its raw share text — otherwise the Share Extension can parse a format
    /// perfectly and still never route it to the right game.
    func testAllLiveFormatFixturesDetectExpectedGame() {
        var failures: [String] = []

        for fixture in GameShareFormatFixtures.all where fixture.shouldParse {
            let detected = GameDetector.detect(from: fixture.shareText, in: Game.allAvailableGames)
            if detected?.id != fixture.game.id {
                let detectedName = detected?.displayName ?? "nil"
                failures.append("\(fixture.game.displayName)/\(fixture.label): detected \(detectedName)")
            }
        }

        if !failures.isEmpty {
            XCTFail("Detection gaps (\(failures.count)):\n" + failures.joined(separator: "\n"))
        }
    }

    func testLiveFormatCoverageIncludesAllGames() {
        let coveredGames = Set(GameShareFormatFixtures.all.map { $0.game.id })
        for game in Game.allAvailableGames {
            XCTAssertTrue(
                coveredGames.contains(game.id),
                "Missing live format fixture for \(game.displayName)"
            )
        }
    }
}
