//
//  GameResult+Firestore.swift
//  StreakSync
//
//  GameResult to and from the users/{uid}/gameResults document shape
//

import FirebaseFirestore
import Foundation

// MARK: - GameResult ↔ Firestore Conversion

extension GameResult {
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "gameId": gameId.uuidString,
            "gameName": gameName,
            "date": Timestamp(date: date),
            "maxAttempts": maxAttempts,
            "completed": completed,
            "sharedText": String(sharedText.prefix(2000)),
            "parsedData": parsedData.mapValues { String($0.prefix(500)) },
            "lastModified": Timestamp(date: lastModified),
            // Set by the server at commit; incremental sync keys off it, not lastModified.
            "serverModified": FieldValue.serverTimestamp()
        ]
        if let score = score {
            data["score"] = score
        }
        return data
    }

    init?(fromFirestore data: [String: Any], documentId: String) {
        guard
            let id = UUID(uuidString: documentId),
            let gameIdStr = data["gameId"] as? String,
            let gameId = UUID(uuidString: gameIdStr),
            let gameName = data["gameName"] as? String,
            let timestamp = data["date"] as? Timestamp,
            let maxAttempts = data["maxAttempts"] as? Int,
            let completed = data["completed"] as? Bool,
            let sharedText = data["sharedText"] as? String
        else {
            return nil
        }

        let score = data["score"] as? Int
        let parsedData = data["parsedData"] as? [String: String] ?? [:]
        let lastModified = (data["lastModified"] as? Timestamp)?.dateValue()

        // Trust Firestore data that was valid when written. Score validation
        // happens at ingestion (addGameResult → isValid) — not during sync,
        // where a scoring model change could silently drop historical results.

        self.init(
            id: id,
            gameId: gameId,
            gameName: gameName,
            date: timestamp.dateValue(),
            score: score,
            maxAttempts: maxAttempts,
            completed: completed,
            sharedText: sharedText,
            parsedData: parsedData,
            lastModified: lastModified
        )
    }
}
