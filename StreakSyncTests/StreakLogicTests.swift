//
//  StreakLogicTests.swift
//  StreakSyncTests
//
//  Tests for streak calculation (AppState+GameLogic) and duplicate detection (AppState+DuplicateDetection).
//

import XCTest
@testable import StreakSync

@MainActor
final class StreakLogicTests: XCTestCase {
    
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
    
    private func makeStreak(
        current: Int = 0,
        max: Int = 0,
        played: Int = 0,
        completed: Int = 0,
        lastPlayed: Date? = nil,
        start: Date? = nil
    ) -> GameStreak {
        GameStreak(
            gameId: gameId,
            gameName: "testgame",
            currentStreak: current,
            maxStreak: max,
            totalGamesPlayed: played,
            totalGamesCompleted: completed,
            lastPlayedDate: lastPlayed,
            streakStartDate: start
        )
    }
    
    private func makeResult(
        date: Date = Date(),
        completed: Bool = true,
        score: Int? = 3,
        puzzleNumber: String? = nil,
        gameName: String = "testgame"
    ) -> GameResult {
        var parsedData: [String: String] = [:]
        if let pn = puzzleNumber { parsedData["puzzleNumber"] = pn }
        return GameResult(
            gameId: gameId,
            gameName: gameName,
            date: date,
            score: score,
            maxAttempts: 6,
            completed: completed,
            sharedText: "Test result",
            parsedData: parsedData
        )
    }
    
    private func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Calendar.current.startOfDay(for: Date()))!
    }
    
    // MARK: - calculateUpdatedStreak Tests
    
    func testNewStreakStartsAtOne() {
        let streak = makeStreak()
        let result = makeResult(date: Date(), completed: true)
        
        let updated = appState.calculateUpdatedStreak(current: streak, with: result)
        
        XCTAssertEqual(updated.currentStreak, 1)
        XCTAssertEqual(updated.maxStreak, 1)
        XCTAssertEqual(updated.totalGamesPlayed, 1)
        XCTAssertEqual(updated.totalGamesCompleted, 1)
        XCTAssertNotNil(updated.streakStartDate)
    }
    
    func testConsecutiveDayExtendsStreak() {
        let yesterday = date(daysAgo: 1)
        let today = date(daysAgo: 0)
        let streak = makeStreak(current: 3, max: 5, played: 10, completed: 8, lastPlayed: yesterday, start: date(daysAgo: 3))
        let result = makeResult(date: today, completed: true)
        
        let updated = appState.calculateUpdatedStreak(current: streak, with: result)
        
        XCTAssertEqual(updated.currentStreak, 4)
        XCTAssertEqual(updated.maxStreak, 5) // max unchanged
        XCTAssertEqual(updated.totalGamesPlayed, 11)
    }
    
    func testSameDayDoesNotIncrementStreak() {
        let today = date(daysAgo: 0)
        let streak = makeStreak(current: 2, max: 2, played: 5, completed: 4, lastPlayed: today, start: date(daysAgo: 1))
        let result = makeResult(date: today, completed: true)
        
        let updated = appState.calculateUpdatedStreak(current: streak, with: result)
        
        XCTAssertEqual(updated.currentStreak, 2) // unchanged
        XCTAssertEqual(updated.totalGamesPlayed, 6)
    }
    
    func testGapBreaksStreakAndStartsNew() {
        let threeDaysAgo = date(daysAgo: 3)
        let today = date(daysAgo: 0)
        let streak = makeStreak(current: 5, max: 5, played: 10, completed: 9, lastPlayed: threeDaysAgo, start: date(daysAgo: 7))
        let result = makeResult(date: today, completed: true)
        
        let updated = appState.calculateUpdatedStreak(current: streak, with: result)
        
        XCTAssertEqual(updated.currentStreak, 1) // reset
        XCTAssertEqual(updated.maxStreak, 5) // preserved
    }
    
    func testFailedGameBreaksStreak() {
        let yesterday = date(daysAgo: 1)
        let today = date(daysAgo: 0)
        let streak = makeStreak(current: 3, max: 3, played: 5, completed: 5, lastPlayed: yesterday)
        let result = makeResult(date: today, completed: false, score: nil)
        
        let updated = appState.calculateUpdatedStreak(current: streak, with: result)
        
        XCTAssertEqual(updated.currentStreak, 0)
        XCTAssertEqual(updated.maxStreak, 3) // preserved
        XCTAssertNil(updated.streakStartDate)
        XCTAssertEqual(updated.totalGamesPlayed, 6)
        XCTAssertEqual(updated.totalGamesCompleted, 5) // not incremented
    }
    
    func testMaxStreakUpdatesWhenCurrentExceeds() {
        let yesterday = date(daysAgo: 1)
        let today = date(daysAgo: 0)
        let streak = makeStreak(current: 5, max: 5, played: 10, completed: 10, lastPlayed: yesterday, start: date(daysAgo: 5))
        let result = makeResult(date: today, completed: true)
        
        let updated = appState.calculateUpdatedStreak(current: streak, with: result)
        
        XCTAssertEqual(updated.currentStreak, 6)
        XCTAssertEqual(updated.maxStreak, 6) // updated
    }
    
    func testFirstPlayWithNoLastPlayedDate() {
        let streak = makeStreak(current: 3, max: 3, played: 3, completed: 3, lastPlayed: nil)
        let result = makeResult(date: Date(), completed: true)
        
        let updated = appState.calculateUpdatedStreak(current: streak, with: result)
        
        XCTAssertEqual(updated.currentStreak, 1) // reset because no lastPlayed
    }
    
    // MARK: - Duplicate Detection Tests
    
    func testExactIdMatchIsDuplicate() {
        let result = makeResult(puzzleNumber: "100")
        appState.setRecentResults([result])
        appState.buildResultsCache()
        
        XCTAssertTrue(appState.isDuplicateResult(result))
    }
    
    func testSamePuzzleNumberIsDuplicate() {
        let result1 = makeResult(puzzleNumber: "100")
        appState.setRecentResults([result1])
        appState.buildResultsCache()
        
        let result2 = makeResult(puzzleNumber: "100") // different UUID, same puzzle
        XCTAssertTrue(appState.isDuplicateResult(result2))
    }
    
    func testDifferentPuzzleNumberIsNotDuplicate() {
        let result1 = makeResult(puzzleNumber: "100")
        appState.setRecentResults([result1])
        appState.buildResultsCache()
        
        let result2 = makeResult(puzzleNumber: "101")
        XCTAssertFalse(appState.isDuplicateResult(result2))
    }
    
    func testSameDayNoPuzzleNumberIsDuplicate() {
        let result1 = makeResult(date: Date()) // no puzzleNumber
        appState.setRecentResults([result1])
        appState.buildResultsCache()
        
        let result2 = makeResult(date: Date()) // same day, same game, no puzzle
        XCTAssertTrue(appState.isDuplicateResult(result2))
    }
    
    func testDifferentDayNoPuzzleNumberIsNotDuplicate() {
        let result1 = makeResult(date: date(daysAgo: 1))
        appState.setRecentResults([result1])
        appState.buildResultsCache()
        
        let result2 = makeResult(date: date(daysAgo: 0))
        XCTAssertFalse(appState.isDuplicateResult(result2))
    }
    
    func testPipsDuplicateCheckIncludesDifficulty() {
        let pipsId = UUID()
        let result1 = GameResult(
            gameId: pipsId, gameName: "pips", date: Date(),
            score: 1, maxAttempts: 3, completed: true, sharedText: "Pips test",
            parsedData: ["puzzleNumber": "50", "difficulty": "Easy"]
        )
        appState.setRecentResults([result1])
        appState.buildResultsCache()
        
        // Same puzzle, different difficulty — NOT duplicate
        let result2 = GameResult(
            gameId: pipsId, gameName: "pips", date: Date(),
            score: 2, maxAttempts: 3, completed: true, sharedText: "Pips test",
            parsedData: ["puzzleNumber": "50", "difficulty": "Medium"]
        )
        XCTAssertFalse(appState.isDuplicateResult(result2))
        
        // Same puzzle, same difficulty — IS duplicate
        let result3 = GameResult(
            gameId: pipsId, gameName: "pips", date: Date(),
            score: 1, maxAttempts: 3, completed: true, sharedText: "Pips test",
            parsedData: ["puzzleNumber": "50", "difficulty": "Easy"]
        )
        XCTAssertTrue(appState.isDuplicateResult(result3))
    }
    
    func testCacheRebuildsWhenEmpty() {
        let result = makeResult(puzzleNumber: "200")
        appState.setRecentResults([result])
        // Don't call buildResultsCache — isDuplicateResult should auto-build
        
        let result2 = makeResult(puzzleNumber: "200")
        XCTAssertTrue(appState.isDuplicateResult(result2))
    }
    
    func testCommaInPuzzleNumberNormalized() {
        let result1 = makeResult(puzzleNumber: "1,492")
        appState.setRecentResults([result1])
        appState.buildResultsCache()
        
        let result2 = makeResult(puzzleNumber: "1492") // no comma
        XCTAssertTrue(appState.isDuplicateResult(result2))
    }
}
