//
//  PendingScoreStore.swift
//  StreakSync
//
//  Stores pending (failed-to-publish) scores in Keychain.
//  Scores contain userId and are retried on next app-active.
//

import Foundation

struct PendingScoreStore {
    private let key = "social_pending_scores"

    func load() -> [DailyGameScore] {
        // Try Keychain first
        if let scores = KeychainService.loadCodable([DailyGameScore].self, forKey: key) {
            return scores
        }
        // One-time migration from UserDefaults
        if let data = UserDefaults.standard.data(forKey: key) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let scores = try? decoder.decode([DailyGameScore].self, from: data) {
                // Migrate to Keychain and clean up UserDefaults
                KeychainService.saveCodable(scores, forKey: key)
                UserDefaults.standard.removeObject(forKey: key)
                return scores
            }
        }
        return []
    }

    func save(_ scores: [DailyGameScore]) {
        if scores.isEmpty {
            KeychainService.delete(forKey: key)
        } else {
            KeychainService.saveCodable(scores, forKey: key)
        }
    }
}
