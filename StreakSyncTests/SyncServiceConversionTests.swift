//
//  SyncServiceConversionTests.swift
//  StreakSyncTests
//
//  Focused tests for Firestore sync model conversion.
//

import XCTest
import FirebaseFirestore
@testable import StreakSync

final class SyncServiceConversionTests: XCTestCase {

    func testGameResultToFirestoreDataIncludesExpectedFields() {
        let gameId = UUID()
        let result = GameResult(
            id: UUID(),
            gameId: gameId,
            gameName: "wordle",
            date: Date(timeIntervalSince1970: 1_739_000_000),
            score: 3,
            maxAttempts: 6,
            completed: true,
            sharedText: "Wordle 123 3/6"
        )

        let data = result.toFirestoreData()

        XCTAssertEqual(data["gameId"] as? String, gameId.uuidString)
        XCTAssertEqual(data["gameName"] as? String, "wordle")
        XCTAssertEqual(data["score"] as? Int, 3)
        XCTAssertEqual(data["maxAttempts"] as? Int, 6)
        XCTAssertEqual(data["completed"] as? Bool, true)
        XCTAssertNotNil(data["date"] as? Timestamp)
        XCTAssertNotNil(data["lastModified"] as? Timestamp)
    }

    func testGameResultFromFirestoreRoundTripPreservesValues() {
        let id = UUID()
        let gameId = UUID()
        let date = Date(timeIntervalSince1970: 1_739_000_000)
        let lastModified = Date(timeIntervalSince1970: 1_739_000_123)

        let data: [String: Any] = [
            "gameId": gameId.uuidString,
            "gameName": "connections",
            "date": Timestamp(date: date),
            "score": 0,
            "maxAttempts": 4,
            "completed": true,
            "sharedText": "Connections Puzzle #500",
            "parsedData": ["foo": "bar"],
            "lastModified": Timestamp(date: lastModified)
        ]

        let reconstructed = GameResult(fromFirestore: data, documentId: id.uuidString)

        XCTAssertNotNil(reconstructed)
        XCTAssertEqual(reconstructed?.id, id)
        XCTAssertEqual(reconstructed?.gameId, gameId)
        XCTAssertEqual(reconstructed?.gameName, "connections")
        XCTAssertEqual(reconstructed?.score, 0)
        XCTAssertEqual(reconstructed?.maxAttempts, 4)
        XCTAssertEqual(reconstructed?.completed, true)
        XCTAssertEqual(reconstructed?.parsedData["foo"], "bar")
        XCTAssertEqual(reconstructed?.date, date)
        XCTAssertEqual(reconstructed?.lastModified, lastModified)
    }

    func testGameResultFromFirestoreRejectsInvalidDocumentId() {
        let data: [String: Any] = [
            "gameId": UUID().uuidString,
            "gameName": "wordle",
            "date": Timestamp(date: Date()),
            "maxAttempts": 6,
            "completed": true,
            "sharedText": "Wordle 123 3/6"
        ]

        let reconstructed = GameResult(fromFirestore: data, documentId: "not-a-uuid")

        XCTAssertNil(reconstructed)
    }
}
