//
//  LeaderboardGroupStore.swift
//  StreakSync
//
//  Simple persistence for selected shared leaderboard group.
//

import Foundation

enum LeaderboardGroupStore {
    private static let groupIdKey = "selectedLeaderboardGroupId"
    private static let groupTitleKey = "selectedLeaderboardGroupTitle"
    
    static var selectedGroupId: UUID? {
        if let string = UserDefaults.standard.string(forKey: groupIdKey) {
            return UUID(uuidString: string)
        }
        return nil
    }
    
    static var selectedGroupTitle: String? {
        UserDefaults.standard.string(forKey: groupTitleKey)
    }
    
    static func setSelectedGroup(id: UUID, title: String?) {
        UserDefaults.standard.set(id.uuidString, forKey: groupIdKey)
        if let title, !title.isEmpty {
            UserDefaults.standard.set(title, forKey: groupTitleKey)
        }
    }
    
    static func clearSelectedGroup() {
        UserDefaults.standard.removeObject(forKey: groupIdKey)
        UserDefaults.standard.removeObject(forKey: groupTitleKey)
    }
}


