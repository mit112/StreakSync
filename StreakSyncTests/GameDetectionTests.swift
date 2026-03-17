//
//  GameDetectionTests.swift
//  StreakSyncTests
//
//  Tests for game detection logic used by the Share Extension.
//  Validates that shared text from each supported game correctly
//  maps to the right Game via signature string matching.
//

import XCTest
@testable import StreakSync

final class GameDetectionTests: XCTestCase {

    // MARK: - NYT Games

    func testDetectsWordle() {
        let text = "Wordle 1,292 3/6\n\n⬛🟨⬛⬛⬛\n🟩⬛🟩🟨⬛\n🟩🟩🟩🟩🟩"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "wordle")
    }

    func testDetectsConnections() {
        let text = "Connections\nPuzzle #603\n🟩🟩🟩🟩\n🟨🟨🟨🟨\n🟪🟪🟪🟪\n🟦🟦🟦🟦"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "connections")
    }

    func testDetectsStrands() {
        let text = "Strands #350\n\u{201C}Knot your average puzzle\u{201D}\n🔵🔵🔵🟡\n🔵🔵🔵"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "strands")
    }

    // MARK: - LinkedIn Games

    func testDetectsQueens() {
        let text = "Queens #210\n👑 Completed in 1:23"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "linkedinqueens")
    }

    func testDetectsTango() {
        let text = "Tango #185\n🌙 Completed in 0:45"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "linkedintango")
    }

    func testDetectsZip() {
        let text = "Zip #102\n⚡ 0:32 | 0 backtracks"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "linkedinzip")
    }

    func testDetectsCrossclimb() {
        let text = "Crossclimb #89\n⏱️ 2:15"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "linkedincrossclimb")
    }

    func testDetectsPinpoint() {
        let text = "Pinpoint #77\n📍 Got it in 2 guesses"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "linkedinpinpoint")
    }

    func testDetectsMiniSudoku() {
        let text = "Mini Sudoku #45\n✅ Completed in 1:10"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "linkedinminisudoku")
    }

    // MARK: - Other Games

    func testDetectsPips() {
        let text = "Pips #120\nEasy 🟢 0:22"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "pips")
    }

    func testDetectsQuordle() {
        let text = "Daily Quordle 1074\n3️⃣ 5️⃣\n4️⃣ 6️⃣"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "quordle")
    }

    func testDetectsWeeklyQuordleChallenge() {
        let text = "Weekly Quordle Challenge 143\n7️⃣4️⃣\n5️⃣6️⃣\nm-w.com/games/quordle/"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "quordle")
    }

    func testDetectsOctordle() {
        let text = "Daily Octordle #1074\nScore: 62"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "octordle")
    }

    func testDetectsNerdle() {
        let text = "nerdlegame 789 3/6"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "nerdle")
    }

    // MARK: - Priority / Ambiguity

    func testQuordleBeforeWordleInPriority() {
        // "Daily Quordle" contains "Wordle" substring — Quordle check must come first
        let text = "Daily Quordle 1074\n3️⃣ 5️⃣\n4️⃣ 6️⃣"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "quordle", "Quordle should match before Wordle")
    }

    func testOctordleBeforeWordleInPriority() {
        let text = "Daily Octordle #1074\nScore: 62"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "octordle", "Octordle should match before Wordle")
    }

    // MARK: - Negative Cases

    func testUnknownTextReturnsNil() {
        let text = "Just a random message about games"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertNil(game)
    }

    func testEmptyTextReturnsNil() {
        let game = GameDetector.detect(from: "", in: Game.allAvailableGames)
        XCTAssertNil(game)
    }

    func testConnectionsWithoutPuzzleHashReturnsNil() {
        // "Connections" alone without "Puzzle #" should not match
        let text = "Connections are important in life"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertNil(game)
    }

    // MARK: - Previously Missing Games

    func testDetectsSpellingBee() {
        let text = "Spelling Bee - I found 42 words, including the pangram!"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "spellingbee")
    }

    func testDetectsMiniCrossword() {
        let text = "I solved the Mini Crossword in 1:47!"
        let game = GameDetector.detect(from: text, in: Game.allAvailableGames)
        XCTAssertEqual(game?.name.lowercased(), "minicrossword")
    }
}
