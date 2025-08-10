//
//  AchievementUnlock+Identifiable.swift
//  StreakSync
//
//  Extension to make AchievementUnlock identifiable
//

import Foundation

// MARK: - Achievement Unlock Model Extension
extension AchievementUnlock: Identifiable {
    var id: String {
        // Create a unique ID from achievement ID, tier, and timestamp
        "\(achievement.id.uuidString)-\(tier.rawValue)-\(timestamp.timeIntervalSince1970)"
    }
}

// Make sure AchievementUnlock is Equatable for item binding
extension AchievementUnlock: Equatable {
    static func == (lhs: AchievementUnlock, rhs: AchievementUnlock) -> Bool {
        lhs.achievement.id == rhs.achievement.id &&
        lhs.tier == rhs.tier &&
        lhs.timestamp == rhs.timestamp
    }
}
