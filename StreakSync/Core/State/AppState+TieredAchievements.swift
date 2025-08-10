//
//  AppState+TieredAchievements.swift
//  StreakSync
//
//  Extension to add tiered achievement support to existing AppState
//

import Foundation
import SwiftUI
import OSLog

extension AppState {
    
    // MARK: - Tiered Achievement Storage
    
    private static let tieredAchievementsKey = "tieredAchievements"
    

    
    var tieredAchievements: [TieredAchievement] {
        get {
            if _tieredAchievements == nil {
                // Try to load from persistence
                if let saved = persistenceService.load([TieredAchievement].self, forKey: Self.tieredAchievementsKey) {
                    _tieredAchievements = saved
                } else {
                    // Create default achievements if none exist
                    _tieredAchievements = AchievementFactory.createDefaultAchievements()
                }
            }
            return _tieredAchievements ?? []
        }
        set {
            _tieredAchievements = newValue
            // Save immediately
            Task {
                await saveTieredAchievements()
            }
        }
    }
    
    // MARK: - Modified checkAchievements to support both systems
    
    func checkAchievements(for result: GameResult) {
        // Check old achievements (existing code)
        checkLegacyAchievements(for: result)
        
        // Check new tiered achievements
        checkTieredAchievements(for: result)
    }
    
    // Move existing achievement checking to this method
    private func checkLegacyAchievements(for result: GameResult) {
        var newlyUnlocked: [Achievement] = []
        
        newlyUnlocked.append(contentsOf: checkFirstGameAchievements())
        newlyUnlocked.append(contentsOf: checkStreakAchievements(for: result))
        newlyUnlocked.append(contentsOf: checkTotalGamesAchievements())
        newlyUnlocked.append(contentsOf: checkMultipleGamesAchievements())
        
        for achievement in newlyUnlocked {
            unlockAchievement(achievement)
        }
    }
    
    // New tiered achievement checking
    internal func checkTieredAchievements(for result: GameResult) {
        let checker = TieredAchievementChecker()
        
        var currentAchievements = tieredAchievements
        let unlocks = checker.checkAllAchievements(
            for: result,
            allResults: recentResults,
            streaks: streaks,
            games: games,
            currentAchievements: &currentAchievements
        )
        
        // Update achievements if changed
        if currentAchievements != tieredAchievements {
            tieredAchievements = currentAchievements
        }
        
        // Handle unlocks
        for unlock in unlocks {
            handleTieredAchievementUnlock(unlock)
        }
    }
    
    private func handleTieredAchievementUnlock(_ unlock: AchievementUnlock) {
        logger.info("🎉 Tiered Achievement Unlocked: \(unlock.achievement.displayName) - \(unlock.tier.displayName)")
        
        // Post notification for UI
        NotificationCenter.default.post(
            name: Notification.Name("TieredAchievementUnlocked"),
            object: unlock
        )
        
        // Trigger haptic feedback
        HapticManager.shared.trigger(.achievement)
    }
    
    // MARK: - Persistence
    
    func saveTieredAchievements() async {
        guard let achievements = _tieredAchievements else { return }
        
        do {
            try persistenceService.save(achievements, forKey: Self.tieredAchievementsKey)
            logger.info("✅ Saved \(achievements.count) tiered achievements")
        } catch {
            logger.error("❌ Failed to save tiered achievements: \(error)")
        }
    }
    
    func loadTieredAchievements() async {
        if let saved = persistenceService.load([TieredAchievement].self, forKey: Self.tieredAchievementsKey) {
            _tieredAchievements = saved
            logger.info("✅ Loaded \(saved.count) tiered achievements")
        } else {
            // Initialize with default achievements
            _tieredAchievements = AchievementFactory.createDefaultAchievements()
            await saveTieredAchievements()
            logger.info("📱 Initialized default tiered achievements")
        }
    }
    
    // MARK: - Helper Methods for Legacy Achievement Checking
    
    private func checkFirstGameAchievements() -> [Achievement] {
        guard self.recentResults.count == 1 else { return [] }
        
        return self.achievements.filter { achievement in
            if case .firstGame = achievement.requirement {
                return !achievement.isUnlocked
            }
            return false
        }
    }
    
    private func checkStreakAchievements(for result: GameResult) -> [Achievement] {
        guard let gameStreak = self.streaks.first(where: { $0.gameId == result.gameId }) else { return [] }
        
        return self.achievements.filter { achievement in
            if case .streakLength(let days) = achievement.requirement {
                return !achievement.isUnlocked && gameStreak.currentStreak >= days
            }
            return false
        }
    }
    
    private func checkTotalGamesAchievements() -> [Achievement] {
        return self.achievements.filter { achievement in
            if case .totalGames(let count) = achievement.requirement {
                return !achievement.isUnlocked && self.recentResults.count >= count
            }
            return false
        }
    }
    
    private func checkMultipleGamesAchievements() -> [Achievement] {
        let today = Calendar.current.startOfDay(for: Date())
        let todayResults = self.recentResults.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let uniqueGamesToday = Set(todayResults.map(\.gameId)).count
        
        return self.achievements.filter { achievement in
            if case .multipleGames(let count) = achievement.requirement {
                return !achievement.isUnlocked && uniqueGamesToday >= count
            }
            return false
        }
    }
}

// MARK: - Update loadPersistedData
extension AppState {
    
    // Recalculate progress from existing data
    internal func recalculateAllTieredAchievementProgress() {
        logger.info("🔄 Calculating tiered achievement progress from existing data...")
        
        var updatedAchievements = tieredAchievements
        
        // Game Collector - total games played
        if let index = updatedAchievements.firstIndex(where: { $0.category == .gameCollector }) {
            updatedAchievements[index].updateProgress(value: recentResults.count)
        }
        
        // Perfectionist - successful games
        let successfulGames = recentResults.filter { $0.isSuccess }.count
        if let index = updatedAchievements.firstIndex(where: { $0.category == .perfectionist }) {
            updatedAchievements[index].updateProgress(value: successfulGames)
        }
        
        // Marathon Runner - unique days
        let uniqueDays = Set(recentResults.map { result in
            Calendar.current.startOfDay(for: result.date)
        }).count
        if let index = updatedAchievements.firstIndex(where: { $0.category == .marathonRunner }) {
            updatedAchievements[index].updateProgress(value: uniqueDays)
        }
        
        // Streak Master - check current streaks
        if let longestCurrentStreak = streaks.map({ $0.currentStreak }).max() {
            if let index = updatedAchievements.firstIndex(where: {
                $0.category == .streakMaster &&
                $0.requirements.first?.specificGameId == nil
            }) {
                updatedAchievements[index].updateProgress(value: longestCurrentStreak)
            }
        }
        
        tieredAchievements = updatedAchievements
        logger.info("✅ Initial progress calculation complete")
    }
}
