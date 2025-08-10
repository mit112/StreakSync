//
//  TieredAchievementsViewModel.swift
//  StreakSync
//
//  View model for tiered achievements grid
//

import SwiftUI

@MainActor
final class TieredAchievementsViewModel: ObservableObject {
    @Published var selectedCategory: AchievementCategory?
    @Published var hasAppeared = false
    
    internal let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Grouped Achievements
    var groupedAchievements: [(category: AchievementCategory, achievements: [TieredAchievement])] {
        Dictionary(grouping: appState.tieredAchievements) { $0.category }
            .map { (category: $0.key, achievements: $0.value) }
            .sorted { $0.category.displayName < $1.category.displayName }
    }
    
    // MARK: - Filtered Achievements
    var filteredAchievements: [TieredAchievement] {
        if let category = selectedCategory {
            return appState.tieredAchievements.filter { $0.category == category }
        }
        return appState.tieredAchievements
    }
    
    // MARK: - Statistics
    var unlockedCount: Int {
        appState.tieredAchievements.filter { $0.isUnlocked }.count
    }
    
    var totalTiers: Int {
        appState.tieredAchievements.reduce(0) { total, achievement in
            total + (achievement.progress.tierUnlockDates.count)
        }
    }
    
    var completionPercentage: Int {
        let totalPossibleTiers = appState.tieredAchievements.reduce(0) { total, achievement in
            total + achievement.requirements.count
        }
        guard totalPossibleTiers > 0 else { return 0 }
        return Int((Double(totalTiers) / Double(totalPossibleTiers)) * 100)
    }
    
    // MARK: - Available Categories
    var availableCategories: [AchievementCategory] {
        let categories = Set(appState.tieredAchievements.map { $0.category })
        return AchievementCategory.allCases.filter { categories.contains($0) }
    }
}
