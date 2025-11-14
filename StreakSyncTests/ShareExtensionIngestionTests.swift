import XCTest
@testable import StreakSync

final class ShareExtensionIngestionTests: XCTestCase {
    
    func testAddGameResultReturningAdded_UniqueThenDuplicateByID() {
        let app = AppState()
        let wordle = Game.wordle
        
        let result = GameResult(
            gameId: wordle.id,
            gameName: wordle.name,
            date: Date(),
            score: 3,
            maxAttempts: 6,
            completed: true,
            sharedText: "Wordle 1605 3/6",
            parsedData: ["puzzleNumber": "1605"]
        )
        
        // First add should succeed
        let added1 = app.addGameResultReturningAdded(result)
        XCTAssertTrue(added1, "First unique result should be added")
        XCTAssertEqual(app.recentResults.count, 1)
        
        // Adding the same instance should be detected by exact ID
        let added2 = app.addGameResultReturningAdded(result)
        XCTAssertFalse(added2, "Second add of the same instance should be detected as duplicate by ID")
        XCTAssertEqual(app.recentResults.count, 1)
    }
    
    func testAddGameResultReturningAdded_DuplicateByPuzzleNumber() {
        let app = AppState()
        let wordle = Game.wordle
        
        let first = GameResult(
            gameId: wordle.id,
            gameName: wordle.name,
            date: Date(),
            score: 2,
            maxAttempts: 6,
            completed: true,
            sharedText: "Wordle 1606 2/6",
            parsedData: ["puzzleNumber": "1606"]
        )
        XCTAssertTrue(app.addGameResultReturningAdded(first))
        XCTAssertEqual(app.recentResults.count, 1)
        
        // New instance with same puzzleNumber should be duplicate
        let second = GameResult(
            gameId: wordle.id,
            gameName: wordle.name,
            date: Date().addingTimeInterval(60),
            score: 4,
            maxAttempts: 6,
            completed: true,
            sharedText: "Wordle 1606 4/6",
            parsedData: ["puzzleNumber": "1606"]
        )
        XCTAssertFalse(app.addGameResultReturningAdded(second), "Duplicate by puzzle number should be rejected")
        XCTAssertEqual(app.recentResults.count, 1)
    }
}


