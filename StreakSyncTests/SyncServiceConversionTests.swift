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

    // MARK: - Share Extension → Main App Cross-Serialization

    /// Verifies that the Share Extension's JSONSerialization + ISO8601DateFormatter
    /// output is decodable by the main app's JSONDecoder with .iso8601 strategy.
    func testShareExtensionSerializationRoundTrip() throws {
        let id = UUID()
        let gameId = UUID()
        let date = Date(timeIntervalSince1970: 1_739_000_000)
        let lastModified = Date(timeIntervalSince1970: 1_739_000_123)

        // Replicate ShareViewController.saveResult() serialization exactly
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let dict: [String: Any] = [
            "id": id.uuidString,
            "gameId": gameId.uuidString,
            "gameName": "wordle",
            "date": isoFormatter.string(from: date),
            "lastModified": isoFormatter.string(from: lastModified),
            "maxAttempts": 6,
            "completed": true,
            "sharedText": "Wordle 123 3/6",
            "score": 3,
            "parsedData": ["puzzleNumber": "123", "source": "shareExtension"]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: dict)

        // Decode using the same decoder as AppGroupDataManager
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GameResult.self, from: jsonData)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.gameId, gameId)
        XCTAssertEqual(decoded.gameName, "wordle")
        XCTAssertEqual(decoded.score, 3)
        XCTAssertEqual(decoded.maxAttempts, 6)
        XCTAssertEqual(decoded.completed, true)
        XCTAssertEqual(decoded.sharedText, "Wordle 123 3/6")
        XCTAssertEqual(decoded.parsedData["puzzleNumber"], "123")
        XCTAssertEqual(decoded.parsedData["source"], "shareExtension")
        // Date comparison: allow up to 1ms tolerance for fractional second rounding
        XCTAssertEqual(decoded.date.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decoded.lastModified.timeIntervalSince1970, lastModified.timeIntervalSince1970, accuracy: 0.001)
    }

    /// Verifies the round-trip works when score is nil (omitted from dict).
    func testShareExtensionSerializationWithNilScore() throws {
        let id = UUID()
        let gameId = UUID()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let dict: [String: Any] = [
            "id": id.uuidString,
            "gameId": gameId.uuidString,
            "gameName": "connections",
            "date": isoFormatter.string(from: Date()),
            "lastModified": isoFormatter.string(from: Date()),
            "maxAttempts": 4,
            "completed": false,
            "sharedText": "Connections Puzzle #500",
            "parsedData": ["source": "shareExtension"]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: dict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GameResult.self, from: jsonData)

        XCTAssertNil(decoded.score)
        XCTAssertEqual(decoded.completed, false)
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
