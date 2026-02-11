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
        NotificationCenter.default.addObserver(
            forName: .appTieredAchievementUnlocked,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .appGameDataUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    
    func refresh() {
        achievements = appState.tieredAchievements
    }
}
