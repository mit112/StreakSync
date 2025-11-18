//
//  ActivityFeedService.swift
//  StreakSync
//

import Foundation

@MainActor
final class ActivityFeedService: ObservableObject {
    static let shared = ActivityFeedService()
    
    @Published private(set) var reactions: [Reaction]
    private let defaults = UserDefaults.standard
    private let key = "social_activity_reactions"
    private let maxReactions = 50
    
    private init() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Reaction].self, from: data) {
            reactions = decoded
        } else {
            reactions = []
        }
    }
    
    func record(_ reaction: Reaction) {
        reactions.insert(reaction, at: 0)
        if reactions.count > maxReactions {
            reactions = Array(reactions.prefix(maxReactions))
        }
        persist()
    }
    
    private func persist() {
        if let data = try? JSONEncoder().encode(reactions) {
            defaults.set(data, forKey: key)
        }
    }
}

