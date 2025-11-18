//
//  CircleStore.swift
//  StreakSync
//

import Foundation

struct SocialCircleStore {
    private let key = "social_circles_v1"
    private let defaults = UserDefaults.standard
    
    func load() -> [SocialCircle] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([SocialCircle].self, from: data)) ?? []
    }
    
    func save(_ circles: [SocialCircle]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(circles) {
            defaults.set(data, forKey: key)
        }
    }
}

