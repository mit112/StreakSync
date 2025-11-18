//
//  LeaderboardCacheStore.swift
//  StreakSync
//

import Foundation

struct LeaderboardCacheStore {
    private let key = "social_leaderboard_cache"
    private let defaults = UserDefaults.standard
    
    func load() -> [LeaderboardCacheKey: LeaderboardCacheEntry] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([LeaderboardCacheKey: LeaderboardCacheEntry].self, from: data)) ?? [:]
    }
    
    func save(_ cache: [LeaderboardCacheKey: LeaderboardCacheEntry]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(cache) {
            defaults.set(data, forKey: key)
        }
    }
    
    func clear() {
        defaults.removeObject(forKey: key)
    }
}

