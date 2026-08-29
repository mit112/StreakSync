//
//  StreakHistoryGroupingTests.swift
//  StreakSyncTests
//
//  Tests for AppState.getGroupedResults, the data source behind the Streaks history calendar.
//

@testable import StreakSync
import XCTest

/// `StreakHistoryView.monthGroupedResults` is built from `appState.getGroupedResults(for:)`,
/// then filtered to the visible month and re-sorted. Everything the calendar shows for Pips —
/// which day gets a cell, which dots appear, which detail row expands — depends on this
/// grouping being correct, so it is exercised here rather than through the view.
@MainActor
final class StreakHistoryGroupingTests: XCTestCase {
    // MARK: - Helpers

    private func makeAppState() -> AppState {
        let appState = AppState(persistenceService: MockPersistenceService())
        appState._tieredAchievements = AchievementFactory.createDefaultAchievements()
        return appState
    }

    private func startOfDay(daysAgo: Int) throws -> Date {
        let today = Calendar.current.startOfDay(for: Date())
        return try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -daysAgo, to: today))
    }

    private func makePipsResult(
        puzzleNumber: String,
        difficulty: String,
        totalSeconds: Int,
        date: Date
    ) -> GameResult {
        GameResult(
            gameId: Game.pips.id,
            gameName: Game.Names.pips,
            date: date,
            score: totalSeconds,
            maxAttempts: 600,
            completed: true,
            sharedText: "Pips #\(puzzleNumber) \(difficulty)",
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "difficulty": difficulty,
                "time": "1:05",
                "totalSeconds": "\(totalSeconds)"
            ]
        )
    }

    private func makeWordleResult(date: Date) -> GameResult {
        GameResult(
            gameId: Game.wordle.id,
            gameName: Game.Names.wordle,
            date: date,
            score: 3,
            maxAttempts: 6,
            completed: true,
            sharedText: "Wordle 1,234 3/6",
            parsedData: ["puzzleNumber": "1234"]
        )
    }

    // MARK: - Game gating

    func testGroupingIsEmptyForANonPipsGame() throws {
        let appState = makeAppState()
        let today = try startOfDay(daysAgo: 0)
        appState.setRecentResults([makeWordleResult(date: today)])

        XCTAssertTrue(appState.getGroupedResults(for: Game.wordle).isEmpty)
    }

    func testGroupingIgnoresResultsBelongingToOtherGames() throws {
        let appState = makeAppState()
        let today = try startOfDay(daysAgo: 0)
        appState.setRecentResults([
            makeWordleResult(date: today),
            makePipsResult(puzzleNumber: "10", difficulty: "Easy", totalSeconds: 65, date: today)
        ])

        let groups = appState.getGroupedResults(for: Game.pips)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.results.count, 1)
    }

    // MARK: - Grouping

    func testGroupingBucketsResultsByPuzzleNumber() throws {
        let appState = makeAppState()
        let today = try startOfDay(daysAgo: 0)
        let yesterday = try startOfDay(daysAgo: 1)
        appState.setRecentResults([
            makePipsResult(puzzleNumber: "10", difficulty: "Easy", totalSeconds: 65, date: yesterday),
            makePipsResult(puzzleNumber: "10", difficulty: "Hard", totalSeconds: 252, date: yesterday),
            makePipsResult(puzzleNumber: "11", difficulty: "Easy", totalSeconds: 70, date: today)
        ])

        let groups = appState.getGroupedResults(for: Game.pips)

        XCTAssertEqual(groups.count, 2)
        let puzzleTen = try XCTUnwrap(groups.first { $0.puzzleNumber == "10" })
        XCTAssertEqual(puzzleTen.results.count, 2)
    }

    func testGroupingDropsResultsWithNoPuzzleNumber() throws {
        let appState = makeAppState()
        let today = try startOfDay(daysAgo: 0)
        let orphan = GameResult(
            gameId: Game.pips.id,
            gameName: Game.Names.pips,
            date: today,
            score: 65,
            maxAttempts: 600,
            completed: true,
            sharedText: "Pips Easy 1:05",
            parsedData: ["difficulty": "Easy"]
        )
        appState.setRecentResults([
            orphan,
            makePipsResult(puzzleNumber: "10", difficulty: "Easy", totalSeconds: 65, date: today)
        ])

        let groups = appState.getGroupedResults(for: Game.pips)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.puzzleNumber, "10")
    }

    // MARK: - Ordering

    func testGroupsAreSortedNewestFirst() throws {
        let appState = makeAppState()
        let older = try startOfDay(daysAgo: 4)
        let newer = try startOfDay(daysAgo: 1)
        appState.setRecentResults([
            makePipsResult(puzzleNumber: "10", difficulty: "Easy", totalSeconds: 65, date: older),
            makePipsResult(puzzleNumber: "11", difficulty: "Easy", totalSeconds: 70, date: newer)
        ])

        let groups = appState.getGroupedResults(for: Game.pips)

        XCTAssertEqual(groups.map(\.puzzleNumber), ["11", "10"])
    }

    func testResultsInsideAGroupAreSortedNewestFirst() throws {
        let appState = makeAppState()
        let day = try startOfDay(daysAgo: 1)
        let early = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: 8, to: day))
        let late = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: 20, to: day))
        appState.setRecentResults([
            makePipsResult(puzzleNumber: "10", difficulty: "Easy", totalSeconds: 65, date: early),
            makePipsResult(puzzleNumber: "10", difficulty: "Hard", totalSeconds: 252, date: late)
        ])

        let group = try XCTUnwrap(appState.getGroupedResults(for: Game.pips).first)

        XCTAssertEqual(group.results.map { $0.parsedData["difficulty"] }, ["Hard", "Easy"])
    }

    func testGroupDateIsTheNewestResultInTheGroup() throws {
        let appState = makeAppState()
        let day = try startOfDay(daysAgo: 1)
        let early = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: 8, to: day))
        let late = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: 20, to: day))
        appState.setRecentResults([
            makePipsResult(puzzleNumber: "10", difficulty: "Easy", totalSeconds: 65, date: early),
            makePipsResult(puzzleNumber: "10", difficulty: "Hard", totalSeconds: 252, date: late)
        ])

        let group = try XCTUnwrap(appState.getGroupedResults(for: Game.pips).first)

        // The calendar places the group on this date, so it must be the newest play.
        XCTAssertEqual(group.date, late)
    }

    // MARK: - Identity carried into the group

    func testGroupCarriesTheGameIdentityNotTheResultIdentity() throws {
        let appState = makeAppState()
        let today = try startOfDay(daysAgo: 0)
        appState.setRecentResults([
            makePipsResult(puzzleNumber: "10", difficulty: "Easy", totalSeconds: 65, date: today)
        ])

        let group = try XCTUnwrap(appState.getGroupedResults(for: Game.pips).first)

        XCTAssertEqual(group.gameId, Game.pips.id)
        XCTAssertEqual(group.gameName, Game.pips.name)
    }
}
