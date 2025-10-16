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
    
    internal static let tieredAchievementsKey = "tieredAchievements"
    

    
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
    
    // MARK: - Tiered-only checkAchievements
    func checkAchievements(for result: GameResult) {
        // Check tiered achievements only
        checkTieredAchievements(for: result)
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
        
        // Post notification for UI with delay to prevent race conditions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: Notification.Name(AppConstants.Notification.tieredAchievementUnlocked),
                object: unlock
            )
        }
        
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
    
    // (Legacy achievement helpers removed)
}

// MARK: - Update loadPersistedData
extension AppState {
    
    // Recalculate progress from existing data
        internal func recalculateAllTieredAchievementProgress() {
            logger.info("🔄 Recomputing tiered achievements from all results...")
            var current = AchievementFactory.createDefaultAchievements()
            let checker = TieredAchievementChecker()
            // Iterate deterministically by date ascending so progression is stable
            let orderedResults = recentResults.sorted { $0.date < $1.date }
            for r in orderedResults {
                _ = checker.checkAllAchievements(
                    for: r,
                    allResults: recentResults,
                    streaks: streaks,
                    games: games,
                    currentAchievements: &current
                )
            }
            // Persist if changed
            if current != tieredAchievements {
                tieredAchievements = current
                logger.info("✅ Tiered achievements recomputed")
            } else {
                logger.info("ℹ️ Tiered achievements already up to date")
            }
        }
}
