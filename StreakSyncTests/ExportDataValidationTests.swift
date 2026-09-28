//
//  ExportDataValidationTests.swift
//  StreakSyncTests
//
//  Backup import validation: what counts as a corrupted backup
//

@testable import StreakSync
import XCTest

final class ExportDataValidationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func backup(resultDate: Date, version: Int = 1) -> ExportData {
        ExportData(
            version: version,
            exportDate: now,
            appVersion: "1.25",
            gameResults: [
                GameResult(
                    gameId: Game.wordle.id, gameName: Game.wordle.name, date: resultDate,
                    score: 3, maxAttempts: 6, completed: true, sharedText: "Wordle 1,900 3/6"
                )
            ],
            achievements: [],
            streaks: [],
            favoriteGameIds: []
        )
    }

    /// Today's puzzle is dated at local noon, so a backup restored the same morning holds
    /// a result a few hours in the future. That is a normal backup, not a corrupted one.
    func testAcceptsTodaysPuzzleDatedLaterToday() {
        XCTAssertNoThrow(try backup(resultDate: now.addingTimeInterval(6 * 3600)).validate(now: now))
    }

    /// Null control: a date far beyond any puzzle day is still rejected.
    func testRejectsAResultDatedDaysAhead() {
        XCTAssertThrowsError(try backup(resultDate: now.addingTimeInterval(3 * 86_400)).validate(now: now))
    }

    func testRejectsANewerBackupVersion() {
        XCTAssertThrowsError(try backup(resultDate: now, version: 2).validate(now: now))
    }
}
