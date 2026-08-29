//
//  StreakHistoryGroupedDisplayTests.swift
//  StreakSyncTests
//
//  Tests for the GroupedGameResult values rendered by the Streaks history calendar.
//

@testable import StreakSync
import XCTest

/// Covers `GroupedGameResult`'s display surface as consumed by
/// `Features/Streaks/Views/StreakHistoryView+Components.swift` — the per-difficulty dots in
/// `HistoryCalendarDayView`, the `completionStatus` label and `bestTime` subtitle in
/// `IOS26SelectedDateGroupedDetail`, and the month-summary counters in `StreakHistoryView`.
final class StreakHistoryGroupedDisplayTests: XCTestCase {
    // MARK: - Helpers

    /// Mirrors the shape emitted by `GameResultParser.parsePips` (see GameResultParser+Other.swift):
    /// score is raw seconds, maxAttempts is the par time, and parsedData carries
    /// puzzleNumber/difficulty/time/totalSeconds.
    private func makePipsResult(
        puzzleNumber: String = "42",
        difficulty: String,
        time: String,
        totalSeconds: Int,
        date: Date = Date()
    ) -> GameResult {
        GameResult(
            gameId: Game.pips.id,
            gameName: Game.Names.pips,
            date: date,
            score: totalSeconds,
            maxAttempts: 600,
            completed: true,
            sharedText: "Pips #\(puzzleNumber) \(difficulty) \(time)",
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "difficulty": difficulty,
                "time": time,
                "totalSeconds": "\(totalSeconds)"
            ]
        )
    }

    private func makeGroup(
        puzzleNumber: String = "42",
        results: [GameResult]
    ) -> GroupedGameResult {
        GroupedGameResult(
            gameId: Game.pips.id,
            gameName: Game.Names.pips,
            puzzleNumber: puzzleNumber,
            date: results.first?.date ?? Date(),
            results: results
        )
    }

    // MARK: - completionStatus

    func testCompletionStatusIsNotStartedWhenNoDifficultyRecorded() {
        let bare = GameResult(
            gameId: Game.pips.id,
            gameName: Game.Names.pips,
            score: 90,
            maxAttempts: 600,
            completed: true,
            sharedText: "Pips #42",
            parsedData: ["puzzleNumber": "42"]
        )
        let group = makeGroup(results: [bare])

        XCTAssertEqual(group.completionStatus, "Not Started")
    }

    func testCompletionStatusIsOneOfThreeForASingleDifficulty() {
        let group = makeGroup(results: [
            makePipsResult(difficulty: "Easy", time: "1:05", totalSeconds: 65)
        ])

        XCTAssertEqual(group.completionStatus, "1/3 Complete")
    }

    func testCompletionStatusIsTwoOfThreeForTwoDifficulties() {
        let group = makeGroup(results: [
            makePipsResult(difficulty: "Easy", time: "1:05", totalSeconds: 65),
            makePipsResult(difficulty: "Hard", time: "4:12", totalSeconds: 252)
        ])

        XCTAssertEqual(group.completionStatus, "2/3 Complete")
    }

    func testCompletionStatusIsAllCompleteForThreeDifficulties() {
        let group = makeGroup(results: [
            makePipsResult(difficulty: "Easy", time: "1:05", totalSeconds: 65),
            makePipsResult(difficulty: "Medium", time: "2:30", totalSeconds: 150),
            makePipsResult(difficulty: "Hard", time: "4:12", totalSeconds: 252)
        ])

        XCTAssertEqual(group.completionStatus, "All Complete")
    }

    // MARK: - Per-difficulty dots

    func testDifficultyFlagsAreSetIndependently() {
        let group = makeGroup(results: [
            makePipsResult(difficulty: "Easy", time: "1:05", totalSeconds: 65),
            makePipsResult(difficulty: "Hard", time: "4:12", totalSeconds: 252)
        ])

        XCTAssertTrue(group.hasEasy)
        XCTAssertFalse(group.hasMedium)
        XCTAssertTrue(group.hasHard)
    }

    func testDifficultyFlagsAreAllFalseWhenNothingRecorded() {
        let group = makeGroup(results: [])

        XCTAssertFalse(group.hasEasy)
        XCTAssertFalse(group.hasMedium)
        XCTAssertFalse(group.hasHard)
    }

    func testCompletedDifficultiesPreservesEveryRecordedDifficulty() {
        let group = makeGroup(results: [
            makePipsResult(difficulty: "Medium", time: "2:30", totalSeconds: 150),
            makePipsResult(difficulty: "Easy", time: "1:05", totalSeconds: 65)
        ])

        XCTAssertEqual(group.completedDifficulties, ["Medium", "Easy"])
    }

    // MARK: - bestTime

    func testBestTimePicksTheFastestDifficultyNotTheFirst() {
        let group = makeGroup(results: [
            makePipsResult(difficulty: "Easy", time: "2:00", totalSeconds: 120),
            makePipsResult(difficulty: "Hard", time: "1:35", totalSeconds: 95),
            makePipsResult(difficulty: "Medium", time: "3:10", totalSeconds: 190)
        ])

        XCTAssertEqual(group.bestTime, "Hard - 1:35")
    }

    func testBestTimeIsNilWhenTotalSecondsIsMissing() {
        // `time` alone is not enough — bestTime ranks on the numeric `totalSeconds` key.
        let withoutSeconds = GameResult(
            gameId: Game.pips.id,
            gameName: Game.Names.pips,
            score: 65,
            maxAttempts: 600,
            completed: true,
            sharedText: "Pips #42 Easy 1:05",
            parsedData: [
                "puzzleNumber": "42",
                "difficulty": "Easy",
                "time": "1:05"
            ]
        )
        let group = makeGroup(results: [withoutSeconds])

        XCTAssertNil(group.bestTime)
    }

    func testBestTimeIsNilForAnEmptyGroup() {
        XCTAssertNil(makeGroup(results: []).bestTime)
    }

    // MARK: - displayTitle / isValid

    func testDisplayTitleUsesThePuzzleNumber() {
        let group = makeGroup(
            puzzleNumber: "137",
            results: [makePipsResult(puzzleNumber: "137", difficulty: "Easy", time: "1:05", totalSeconds: 65)]
        )

        XCTAssertEqual(group.displayTitle, "Puzzle #137")
    }

    func testIsValidRequiresAtLeastOneResult() {
        let populated = makeGroup(results: [
            makePipsResult(difficulty: "Easy", time: "1:05", totalSeconds: 65)
        ])

        XCTAssertTrue(populated.isValid)
        XCTAssertFalse(makeGroup(results: []).isValid)
    }

    func testIsValidRequiresANonEmptyPuzzleNumber() {
        let group = makeGroup(
            puzzleNumber: "",
            results: [makePipsResult(difficulty: "Easy", time: "1:05", totalSeconds: 65)]
        )

        XCTAssertFalse(group.isValid)
    }
}
