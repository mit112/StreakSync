@testable import StreakSync
import XCTest

@MainActor
final class ShareExtensionIngestionTests: XCTestCase {
    // MARK: - Helpers

    /// Builds an ISO8601 date string with fractional seconds, matching the
    /// Share Extension's serialization format exactly.
    private func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    func testAddGameResult_UniqueThenDuplicateByID() {
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
        let added1 = app.addGameResult(result)
        XCTAssertTrue(added1, "First unique result should be added")
        XCTAssertEqual(app.recentResults.count, 1)
        
        // Adding the same instance should be detected by exact ID
        let added2 = app.addGameResult(result)
        XCTAssertFalse(added2, "Second add of the same instance should be detected as duplicate by ID")
        XCTAssertEqual(app.recentResults.count, 1)
    }
    
    func testAddGameResult_DuplicateByPuzzleNumber() {
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
        XCTAssertTrue(app.addGameResult(first))
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
        XCTAssertFalse(app.addGameResult(second), "Duplicate by puzzle number should be rejected")
        XCTAssertEqual(app.recentResults.count, 1)
    }

    // MARK: - App Group Queue Mechanic

    func testAppGroupQueue_WriteLoadClear() async throws {
        // Use a unique suiteName so this test is fully isolated from the real App Group
        // and from other test runs. AppGroupDataManager creates UserDefaults(suiteName:)
        // internally, so passing a unique ID is sufficient for in-process isolation.
        let suiteName = "test.shareext.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }

        // 1. Write a result in Share Extension format:
        //    JSONSerialization dictionary + ISO8601 date strings with fractional seconds.
        let resultId = UUID()
        let gameId = Game.wordle.id
        let resultDate = Date()

        let dict: [String: Any] = [
            "id": resultId.uuidString,
            "gameId": gameId.uuidString,
            "gameName": "wordle",
            "date": isoString(from: resultDate),
            "lastModified": isoString(from: resultDate),
            "score": 3,
            "maxAttempts": 6,
            "completed": true,
            "sharedText": "Wordle 1700 3/6",
            "parsedData": ["puzzleNumber": "1700", "source": "shareExtension"]
        ]
        let resultData = try JSONSerialization.data(withJSONObject: dict, options: [])

        let resultKey = "gameResult_\(resultId.uuidString)"
        userDefaults.set(resultData, forKey: resultKey)

        let keysData = try JSONSerialization.data(withJSONObject: [resultKey], options: [])
        userDefaults.set(keysData, forKey: "gameResultKeys")
        userDefaults.synchronize()

        // 2. Instantiate AppGroupDataManager pointed at the isolated suite
        let manager = AppGroupDataManager(appGroupID: suiteName)

        // 3. Load the queue — expect one decoded result
        let (results, processedKeys) = await manager.loadGameResultQueue()
        XCTAssertEqual(results.count, 1, "Expected one result in the queue")
        XCTAssertEqual(processedKeys, [resultKey])

        let loaded = try XCTUnwrap(results.first)
        XCTAssertEqual(loaded.id, resultId)
        XCTAssertEqual(loaded.gameId, gameId)
        XCTAssertEqual(loaded.gameName, "wordle")
        XCTAssertEqual(loaded.score, 3)
        XCTAssertEqual(loaded.maxAttempts, 6)
        XCTAssertTrue(loaded.completed)
        XCTAssertEqual(loaded.sharedText, "Wordle 1700 3/6")

        // 4. Clear the processed keys
        manager.clearProcessedKeys(processedKeys)

        // 5. Queue should now be empty
        let (resultsAfterClear, keysAfterClear) = await manager.loadGameResultQueue()
        XCTAssertTrue(resultsAfterClear.isEmpty, "Queue should be empty after clearing processed keys")
        XCTAssertTrue(keysAfterClear.isEmpty)

        // 6. Individual result key should also be gone
        XCTAssertNil(userDefaults.data(forKey: resultKey), "Individual result key should be removed")
    }
}
