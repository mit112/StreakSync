//
//  PendingScoreStore.swift
//  StreakSync
//

import Foundation

struct PendingScoreStore {
    private let key = "social_pending_scores"
    private let defaults = UserDefaults.standard
    
    func load() -> [DailyGameScore] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([DailyGameScore].self, from: data)) ?? []
    }
    
    func save(_ scores: [DailyGameScore]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(scores) {
            defaults.set(data, forKey: key)
        }
    }
}

