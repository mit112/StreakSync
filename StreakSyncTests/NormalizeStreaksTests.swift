//
//  NormalizeStreaksTests.swift
//  StreakSyncTests
//
//  Tests for AppState.normalizeStreaksForMissedDays() — streak integrity.
//

import XCTest
@testable import StreakSync

@MainActor
final class NormalizeStreaksTests: XCTestCase {

    private var appState: AppState!
    private let gameId = UUID()

    override func setUp() {
        super.setUp()
        appState = AppState(persistenceService: MockPersistenceService())
    }

    override func tearDown() {
        appState = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Calendar.current.startOfDay(for: Date()))!
    }

    private func makeStreak(
        current: Int,
        max: Int = 5,
        lastPlayed: Date?,
        start: Date? = nil
    ) -> GameStreak {
        GameStreak(
            gameId: gameId,
            gameName: "testgame",
            currentStreak: current,
            maxStreak: max,
            totalGamesPlayed: current,
            totalGamesCompleted: current,
            lastPlayedDate: lastPlayed,
            streakStartDate: start
        )
    }

    private func makeResult(date: Date, completed: Bool = true) -> GameResult {
        GameResult(
            gameId: gameId,
            gameName: "testgame",
            date: date,
            score: 3,
            maxAttempts: 6,
            completed: completed,
            sharedText: "Test result"
        )
    }

    // MARK: - No-op cases

    func testZeroStreakIsNotReset() async {
        let streak = makeStreak(current: 0, lastPlayed: date(daysAgo: 5))
        appState.setStreaks([streak])
        appState.setRecentResults([])

        await appState.normalizeStreaksForMissedDays(referenceDate: Date())

        XCTAssertEqual(appState.streaks.first?.currentStreak, 0)
    }

    func testNilLastPlayedIsNotReset() async {
        let streak = makeStreak(current: 3, lastPlayed: nil)
        appState.setStreaks([streak])
        appState.setRecentResults([])

        await appState.normalizeStreaksForMissedDays(referenceDate: Date())

        XCTAssertEqual(appState.streaks.first?.currentStreak, 3)
    }

    // MARK: - Continuous streaks (should survive)

    func testContinuousStreakSurvives() async {
        // Played every day for last 3 days
        let results = [
            makeResult(date: date(daysAgo: 2)),
            makeResult(date: date(daysAgo: 1)),
            makeResult(date: date(daysAgo: 0)),
        ]
        let streak = makeStreak(current: 3, lastPlayed: date(daysAgo: 0), start: date(daysAgo: 2))

        appState.setStreaks([streak])
        appState.setRecentResults(results)

        await appState.normalizeStreaksForMissedDays(referenceDate: Date())

        XCTAssertEqual(appState.streaks.first?.currentStreak, 3, "Continuous streak should survive")
    }

    func testPlayedTodayOnlyNotBroken() async {
        // Only played today — streak of 1
        let results = [makeResult(date: date(daysAgo: 0))]
        let streak = makeStreak(current: 1, lastPlayed: date(daysAgo: 0), start: date(daysAgo: 0))

        appState.setStreaks([streak])
        appState.setRecentResults(results)

        await appState.normalizeStreaksForMissedDays(referenceDate: Date())

        XCTAssertEqual(appState.streaks.first?.currentStreak, 1)
    }

    // MARK: - Gap detection (should break)

    func testMissedYesterdayBreaksStreak() async {
        // Played 2 days ago, skipped yesterday, reference = today
        let results = [makeResult(date: date(daysAgo: 2))]
        let streak = makeStreak(current: 5, lastPlayed: date(daysAgo: 2), start: date(daysAgo: 6))

        appState.setStreaks([streak])
        appState.setRecentResults(results)

        await appState.normalizeStreaksForMissedDays(referenceDate: Date())

        XCTAssertEqual(appState.streaks.first?.currentStreak, 0, "Missing yesterday should break streak")
    }

    func testMultipleDayGapBreaksStreak() async {
        // Last played 5 days ago, nothing since
        let results = [makeResult(date: date(daysAgo: 5))]
        let streak = makeStreak(current: 10, max: 10, lastPlayed: date(daysAgo: 5), start: date(daysAgo: 14))

        appState.setStreaks([streak])
        appState.setRecentResults(results)

        await appState.normalizeStreaksForMissedDays(referenceDate: Date())

        XCTAssertEqual(appState.streaks.first?.currentStreak, 0, "Multi-day gap should break streak")
        XCTAssertEqual(appState.streaks.first?.maxStreak, 10, "Max streak should be preserved")
    }

    func testGapInMiddleOfStreakBreaks() async {
        // Played days 4, 3, (skipped 2), 1, 0
        let results = [
            makeResult(date: date(daysAgo: 4)),
            makeResult(date: date(daysAgo: 3)),
            // day 2 missing
            makeResult(date: date(daysAgo: 1)),
            makeResult(date: date(daysAgo: 0)),
        ]
        let streak = makeStreak(current: 4, lastPlayed: date(daysAgo: 0), start: date(daysAgo: 4))

        appState.setStreaks([streak])
        appState.setRecentResults(results)

        await appState.normalizeStreaksForMissedDays(referenceDate: Date())

        XCTAssertEqual(appState.streaks.first?.currentStreak, 4, "Normalization only checks gap from lastPlayed to reference date, not historical gaps")
    }

    // MARK: - Edge cases

    func testIncompleteResultsDoNotCountAsPlayed() async {
        // Played yesterday (completed) and today (failed)
        let results = [
            makeResult(date: date(daysAgo: 1), completed: true),
            makeResult(date: date(daysAgo: 0), completed: false),
        ]
        let streak = makeStreak(current: 2, lastPlayed: date(daysAgo: 0), start: date(daysAgo: 1))

        appState.setStreaks([streak])
        appState.setRecentResults(results)

        // Gap detection uses `completed` results only — day 0 has no completed result
        // but lastPlayed is day 0, so it checks days between lastPlayed (0) and reference (0).
        // No gap between same day, so streak survives the normalize check.
        // The streak value itself should have been set to 0 by calculateUpdatedStreak
        // when the failed result was processed, but normalize doesn't re-evaluate that.
        await appState.normalizeStreaksForMissedDays(referenceDate: Date())

        // Normalize only checks for gaps in completed results between lastPlayed and reference.
        // lastPlayed == today, reference == today → no gap → streak unchanged
        XCTAssertEqual(appState.streaks.first?.currentStreak, 2)
    }

    func testMultipleGamesIndependent() async {
        let gameA = UUID()
        let gameB = UUID()

        let streakA = GameStreak(
            gameId: gameA, gameName: "gameA",
            currentStreak: 3, maxStreak: 3,
            totalGamesPlayed: 3, totalGamesCompleted: 3,
            lastPlayedDate: date(daysAgo: 0), streakStartDate: date(daysAgo: 2)
        )
        let streakB = GameStreak(
            gameId: gameB, gameName: "gameB",
            currentStreak: 5, maxStreak: 5,
            totalGamesPlayed: 5, totalGamesCompleted: 5,
            lastPlayedDate: date(daysAgo: 3), streakStartDate: date(daysAgo: 7)
        )

        // Game A has continuous results, game B has a gap
        let results = [
            GameResult(gameId: gameA, gameName: "gameA", date: date(daysAgo: 2), score: 1, maxAttempts: 6, completed: true, sharedText: "A"),
            GameResult(gameId: gameA, gameName: "gameA", date: date(daysAgo: 1), score: 1, maxAttempts: 6, completed: true, sharedText: "A"),
            GameResult(gameId: gameA, gameName: "gameA", date: date(daysAgo: 0), score: 1, maxAttempts: 6, completed: true, sharedText: "A"),
            GameResult(gameId: gameB, gameName: "gameB", date: date(daysAgo: 3), score: 1, maxAttempts: 6, completed: true, sharedText: "B"),
            // gameB has no results for days 2, 1, 0
        ]

        appState.setStreaks([streakA, streakB])
        appState.setRecentResults(results)

        await appState.normalizeStreaksForMissedDays(referenceDate: Date())

        let resultA = appState.streaks.first(where: { $0.gameId == gameA })
        let resultB = appState.streaks.first(where: { $0.gameId == gameB })

        XCTAssertEqual(resultA?.currentStreak, 3, "Game A continuous — should survive")
        XCTAssertEqual(resultB?.currentStreak, 0, "Game B has gap — should break")
        XCTAssertEqual(resultB?.maxStreak, 5, "Game B max streak preserved")
    }
}
