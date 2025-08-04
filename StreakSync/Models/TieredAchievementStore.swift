//
//  TieredAchievementStore.swift
//  StreakSync
//
//  Observable wrapper for tiered achievements
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class TieredAchievementStore {
    private(set) var achievements: [TieredAchievement] = []
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
        self.achievements = appState.tieredAchievements
        setupObservers()
    }
    
    private func setupObservers() {
        // Listen for achievement unlocks
        NotificationCenter.default.addObserver(
            forName: Notification.Name("TieredAchievementUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
        
        // Listen for game data updates
        NotificationCenter.default.addObserver(
            forName: Notification.Name("GameDataUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }
    
    func refresh() {
        achievements = appState.tieredAchievements
    }
}
