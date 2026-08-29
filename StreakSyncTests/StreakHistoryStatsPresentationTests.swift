//
//  StreakHistoryStatsPresentationTests.swift
//  StreakSyncTests
//
//  Tests for the GameStreak values rendered by StreakHistoryView's statsHeader.
//

@testable import StreakSync
import XCTest

/// Covers the three `HistoryStatBox` values in `Features/Streaks/Views/StreakHistoryView.swift`:
/// "Current" (`streak.currentStreak` + `streak.isActive` tint), "Best" (`streak.maxStreak`) and
/// "Success" (`streak.completionPercentage`). Streak *mutation* is covered by StreakLogicTests;
/// this file only covers how a finished GameStreak presents itself.
final class StreakHistoryStatsPresentationTests: XCTestCase {
    // MARK: - Helpers

    private func startOfDay(daysAgo: Int) throws -> Date {
        let today = Calendar.current.startOfDay(for: Date())
        return try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -daysAgo, to: today))
    }

    private func makeStreak(
        current: Int,
        best: Int,
        played: Int,
        completed: Int,
        lastPlayed: Date?
    ) -> GameStreak {
        GameStreak(
            gameId: Game.wordle.id,
            gameName: Game.Names.wordle,
            currentStreak: current,
            maxStreak: best,
            totalGamesPlayed: played,
            totalGamesCompleted: completed,
            lastPlayedDate: lastPlayed,
            streakStartDate: nil
        )
    }

    // MARK: - "Success" stat box (completionPercentage)

    func testCompletionPercentageRendersWholePercent() {
        let streak = makeStreak(current: 3, best: 9, played: 100, completed: 85, lastPlayed: nil)

        XCTAssertEqual(streak.completionPercentage, "85%")
    }

    func testCompletionPercentageRoundsUpAtTwoThirds() {
        let streak = makeStreak(current: 1, best: 1, played: 3, completed: 2, lastPlayed: nil)

        XCTAssertEqual(streak.completionPercentage, "67%")
    }

    func testCompletionPercentageRoundsDownAtOneThird() {
        let streak = makeStreak(current: 1, best: 1, played: 3, completed: 1, lastPlayed: nil)

        XCTAssertEqual(streak.completionPercentage, "33%")
    }

    func testCompletionPercentageIsZeroWhenNothingPlayed() {
        let streak = makeStreak(current: 0, best: 0, played: 0, completed: 0, lastPlayed: nil)

        // Without the `totalGamesPlayed > 0` guard this divides 0/0 and renders "nan%".
        XCTAssertEqual(streak.completionPercentage, "0%")
    }

    func testCompletionPercentageIsHundredWhenEveryGameCompleted() {
        let streak = makeStreak(current: 7, best: 7, played: 7, completed: 7, lastPlayed: nil)

        XCTAssertEqual(streak.completionPercentage, "100%")
    }

    func testCompletionPercentageIgnoresStreakLengthAndUsesLifetimeTotals() {
        // Streak is broken (current == 0) but 4 of 10 lifetime games were completed.
        let streak = makeStreak(current: 0, best: 6, played: 10, completed: 4, lastPlayed: nil)

        XCTAssertEqual(streak.completionPercentage, "40%")
    }

    // MARK: - "Current" stat box tint (isActive)

    func testIsActiveWhenLastPlayedToday() throws {
        let streak = makeStreak(current: 2, best: 5, played: 5, completed: 5, lastPlayed: try startOfDay(daysAgo: 0))

        XCTAssertTrue(streak.isActive)
    }

    func testIsActiveWhenLastPlayedYesterday() throws {
        let streak = makeStreak(current: 2, best: 5, played: 5, completed: 5, lastPlayed: try startOfDay(daysAgo: 1))

        // Yesterday still counts — today's puzzle may not have been played yet.
        XCTAssertTrue(streak.isActive)
    }

    func testIsNotActiveWhenLastPlayedTwoDaysAgo() throws {
        let streak = makeStreak(current: 2, best: 5, played: 5, completed: 5, lastPlayed: try startOfDay(daysAgo: 2))

        XCTAssertFalse(streak.isActive)
    }

    func testIsNotActiveWhenNeverPlayed() {
        let streak = makeStreak(current: 0, best: 0, played: 0, completed: 0, lastPlayed: nil)

        XCTAssertFalse(streak.isActive)
    }

    // MARK: - streakStatus

    func testStreakStatusIsBrokenWhenCurrentStreakIsZeroEvenIfPlayedToday() throws {
        let streak = makeStreak(current: 0, best: 9, played: 20, completed: 11, lastPlayed: try startOfDay(daysAgo: 0))

        // The zero check must be evaluated before the isActive check.
        XCTAssertEqual(streak.streakStatus, .broken)
    }

    func testStreakStatusIsActiveWhenStreakRunningAndPlayedToday() throws {
        let streak = makeStreak(current: 4, best: 9, played: 20, completed: 18, lastPlayed: try startOfDay(daysAgo: 0))

        XCTAssertEqual(streak.streakStatus, .active)
    }

    func testStreakStatusIsInactiveWhenStreakRunningButStale() throws {
        let streak = makeStreak(current: 4, best: 9, played: 20, completed: 18, lastPlayed: try startOfDay(daysAgo: 3))

        XCTAssertEqual(streak.streakStatus, .inactive)
    }

    // MARK: - "Best" stat box (maxStreak clamp)

    func testMaxStreakIsClampedToAtLeastCurrentStreak() {
        // A persisted streak whose maxStreak fell behind must never render "Best 3 / Current 9".
        let streak = makeStreak(current: 9, best: 3, played: 12, completed: 12, lastPlayed: nil)

        XCTAssertEqual(streak.maxStreak, 9)
        XCTAssertEqual(streak.currentStreak, 9)
    }

    func testMaxStreakIsPreservedWhenAlreadyAhead() {
        let streak = makeStreak(current: 2, best: 11, played: 30, completed: 25, lastPlayed: nil)

        XCTAssertEqual(streak.maxStreak, 11)
    }
}
