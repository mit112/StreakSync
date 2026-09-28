//
//  LegacyDayKeyCleanup.swift
//  StreakSync
//
//  Which score documents published under the pre-1.26 UTC day key to delete
//

import Foundation

enum LegacyDayKeyCleanup {
    /// Score document IDs filed under a result's old UTC day where that differs from its
    /// local day, since `since`. An ID that any result claims under the current key is
    /// never returned: deleting it would remove a real score, not a stale copy.
    static func documentIDsToRetract(
        userId: String,
        results: [GameResult],
        since: Date,
        calendar: Calendar = .current
    ) -> [String] {
        let claimed = Set(results.map {
            documentID(userId: userId, dayKey: DailyGameScore.dayKey(for: $0.date, in: calendar), gameId: $0.gameId)
        })
        var stale: Set<String> = []
        for result in results where result.date >= since {
            let legacyKey = DailyGameScore.legacyDayKey(for: result.date)
            guard legacyKey != DailyGameScore.dayKey(for: result.date, in: calendar) else { continue }
            let id = documentID(userId: userId, dayKey: legacyKey, gameId: result.gameId)
            if !claimed.contains(id) { stale.insert(id) }
        }
        return stale.sorted()
    }

    static func documentID(userId: String, dayKey: Int, gameId: UUID) -> String {
        "\(userId)|\(dayKey)|\(gameId.uuidString)"
    }
}
