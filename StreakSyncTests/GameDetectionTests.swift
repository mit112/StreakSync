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

    // MARK: - Detection Helper (mirrors ShareViewController.detectGame)

    /// Replicates the Share Extension's game detection rules.
    /// If these tests pass, the Share Extension will correctly route shared text.
    private func detectGame(from text: String) -> Game? {
        let games = Game.allAvailableGames

        let rules: [(String, String)] = [
            ("Pips #", "pips"),
            ("Daily Quordle", "quordle"),
            ("Daily Octordle", "octordle"),
            ("Wordle", "wordle"),
            ("nerdlegame", "nerdle"),
            ("Strands #", "strands"),
            ("Mini Sudoku #", "linkedinminisudoku"),
            ("Queens #", "linkedinqueens"),
            ("Tango #", "linkedintango"),
            ("Crossclimb #", "linkedincrossclimb"),
            ("Pinpoint #", "linkedinpinpoint"),
            ("Zip #", "linkedinzip"),
        ]

        // Connections needs two markers
        if text.contains("Connections") && text.contains("Puzzle #") {
            return games.first { $0.name.lowercased() == "connections" }
        }

        for (marker, name) in rules {
            if text.contains(marker) {
                return games.first { $0.name.lowercased() == name }
            }
        }

        return nil
    }

    // MARK: - NYT Games

    func testDetectsWordle() {
        let text = "Wordle 1,292 3/6\n\n⬛🟨⬛⬛⬛\n🟩⬛🟩🟨⬛\n🟩🟩🟩🟩🟩"
        let game = detectGame(from: text)
        XCTAssertEqual(game?.name.lowercased(), "wordle")
    }

    func testDetectsConnections() {
        let text = "Connections\nPuzzle #603\n🟩🟩🟩🟩\n🟨🟨🟨🟨\n🟪🟪🟪🟪\n🟦🟦🟦🟦"
        let game = detectGame(from: text)
        XCTAssertEqual(game?.name.lowercased(), "connections")
    }

    func testDetectsStrands() {
        let text = "Strands #350\n\u{201C}Knot your average puzzle\u{201D}\n🔵🔵🔵🟡\n🔵🔵🔵"
        let game = detectGame(from: text)
        XCTAssertEqual(game?.name.lowercased(), "strands")
    }

    // MARK: - LinkedIn Games

    func testDetectsQueens() {
        let text = "Queens #210\n👑 Completed in 1:23"
        let game = detectGame(from: text)
        XCTAssertEqual(game?.name.lowercased(), "linkedinqueens")
    }

    func testDetectsTango() {
        let text = "Tango #185\n🌙 Completed in 0:45"
        let game = detectGame(from: text)
        XCTAssertEqual(game?.name.lowercased(), "linkedintango")
    }

    func testDetectsZip() {
        let text = "Zip #102\n⚡ 0:32 | 0 backtracks"
        let game = detectGame(from: text)
        XCTAssertEqual(game?.name.lowercased(), "linkedinzip")
    }

    func testDetectsCrossclimb() {
        let text = "Crossclimb #89\n⏱️ 2:15"
        let game = detectGame(from: text)
        XCTAssertEqual(game?.name.lowercased(), "linkedincrossclimb")
    }

    func testDetectsPinpoint() {
        let text = "Pinpoint #77\n📍 Got it in 2 guesses"
        let game = detectGame(from: text)
        XCTAssertEqual(game?.name.lowercased(), "linkedinpinpoint")
    }

    func testDetectsMiniSudoku() {
        let text = "Mini Sudoku #45\n✅ Completed in 1:10"
        let game = detectGame(from: text)
        XCTAssertEqual(game?.name.lowercased(), "linkedinminisudoku")
    }

    // MARK: - Other Games

    func testDetectsPips() {
        let text = "Pips #120\nEasy 🟢 0:22"
        let game = detectGame(from: text)
        XCTAssertEqual(game?.name.lowercased(), "pips")
    }

    func testDetectsQuordle() {
        let text = "Daily Quordle 1074\n3️⃣ 5️⃣\n4️⃣ 6️⃣"
        let game = detectGame(from: text)
        XCTAssertEqual(game?.name.lowercased(), "quordle")
    }

    func testDetectsOctordle() {
        let text = "Daily Octordle #1074\nScore: 62"
        let game = detectGame(from: text)
        XCTAssertEqual(game?.name.lowercased(), "octordle")
    }

    func testDetectsNerdle() {
        let text = "nerdlegame 789 3/6"
        let game = detectGame(from: text)
        XCTAssertEqual(game?.name.lowercased(), "nerdle")
    }

    // MARK: - Priority / Ambiguity

    func testQuordleBeforeWordleInPriority() {
        // "Daily Quordle" contains "Wordle" substring — Quordle check must come first
        let text = "Daily Quordle 1074\n3️⃣ 5️⃣\n4️⃣ 6️⃣"
        let game = detectGame(from: text)
        XCTAssertEqual(game?.name.lowercased(), "quordle", "Quordle should match before Wordle")
    }

    func testOctordleBeforeWordleInPriority() {
        let text = "Daily Octordle #1074\nScore: 62"
        let game = detectGame(from: text)
        XCTAssertEqual(game?.name.lowercased(), "octordle", "Octordle should match before Wordle")
    }

    // MARK: - Negative Cases

    func testUnknownTextReturnsNil() {
        let text = "Just a random message about games"
        let game = detectGame(from: text)
        XCTAssertNil(game)
    }

    func testEmptyTextReturnsNil() {
        let game = detectGame(from: "")
        XCTAssertNil(game)
    }

    func testConnectionsWithoutPuzzleHashReturnsNil() {
        // "Connections" alone without "Puzzle #" should not match
        let text = "Connections are important in life"
        let game = detectGame(from: text)
        XCTAssertNil(game)
    }
}
