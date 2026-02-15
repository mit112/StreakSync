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
    internal static let uniqueGamesEverKey = "uniqueGamesEver"
    

    
    var tieredAchievements: [TieredAchievement] {
        get {
            if _tieredAchievements == nil {
                // Try to load from persistence
                if let saved = persistenceService.load([TieredAchievement].self, forKey: Self.tieredAchievementsKey) {
                    // Deduplicate by category (keep the first occurrence of each category)
                    var deduplicated: [TieredAchievement] = []
                    var seenCategories: Set<AchievementCategory> = []
                    for achievement in saved {
                        if !seenCategories.contains(achievement.category) {
                            deduplicated.append(achievement)
                            seenCategories.insert(achievement.category)
                        }
                    }
                    _tieredAchievements = deduplicated
                    if deduplicated.count != saved.count {
 logger.debug("Removed \(saved.count - deduplicated.count) duplicate achievements from persistence")
                    }
                } else {
                    // Create default achievements if none exist
                    _tieredAchievements = AchievementFactory.createDefaultAchievements()
                }
            }
            return _tieredAchievements ?? []
        }
        set {
            // Deduplicate by category before setting
            var deduplicated: [TieredAchievement] = []
            var seenCategories: Set<AchievementCategory> = []
            for achievement in newValue {
                if !seenCategories.contains(achievement.category) {
                    deduplicated.append(achievement)
                    seenCategories.insert(achievement.category)
                }
            }
            _tieredAchievements = deduplicated
            if deduplicated.count != newValue.count {
 logger.debug("Removed \(newValue.count - deduplicated.count) duplicate achievements")
            }
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
        
        // Enforce all-time unique union for Variety Player to avoid regressions on partial histories
        if let idx = currentAchievements.firstIndex(where: { $0.category == .varietyPlayer }) {
            let fromHistory = Set(recentResults.map(\.gameId))
            let unionCount = fromHistory.union(uniqueGamesEver).count
            let monotonicValue = max(currentAchievements[idx].progress.currentValue, unionCount)
            currentAchievements[idx].updateProgress(value: monotonicValue)
        }
        
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
 logger.info("Tiered Achievement Unlocked: \(unlock.achievement.displayName) - \(unlock.tier.displayName)")
        
        // Queue celebration directly (deterministic, no fire-and-forget)
        celebrationCoordinator?.queueCelebration(unlock)
        
        // Trigger haptic feedback
        HapticManager.shared.trigger(.achievement)
    }
    
    // MARK: - Persistence
    
    func saveTieredAchievements() async {
        // In Guest Mode we never persist changes to tiered achievements. Host
        // achievements are part of the snapshot managed by GuestSessionManager.
        if isGuestMode {
 logger.debug("Guest Mode active – skipping saveTieredAchievements()")
            return
        }
        guard let achievements = _tieredAchievements else { return }
        
        do {
            try persistenceService.save(achievements, forKey: Self.tieredAchievementsKey)
            self.tieredAchievementSavesSinceLaunch += 1
 logger.debug("Tiered achievements saved (count since launch: \(self.tieredAchievementSavesSinceLaunch))")
 logger.info("Saved \(achievements.count) tiered achievements")
        } catch {
 logger.error("Failed to save tiered achievements: \(error)")
        }
    }
    
    // MARK: - Unique Games Ever Persistence
    var uniqueGamesEver: Set<UUID> {
        get {
            if _uniqueGamesEver == nil {
                _uniqueGamesEver = persistenceService.load(Set<UUID>.self, forKey: Self.uniqueGamesEverKey) ?? []
            }
            return _uniqueGamesEver ?? []
        }
        set {
            _uniqueGamesEver = newValue
            Task {
                await saveUniqueGamesEver()
            }
        }
    }
    
    func saveUniqueGamesEver() async {
        // In Guest Mode we do not mutate the persisted unique-games set.
        if isGuestMode {
 logger.debug("Guest Mode active – skipping saveUniqueGamesEver()")
            return
        }
        let setToSave = _uniqueGamesEver ?? []
        do {
            try persistenceService.save(setToSave, forKey: Self.uniqueGamesEverKey)
 logger.info("Saved unique games ever set with \(setToSave.count) entries")
        } catch {
 logger.error("Failed to save unique games set: \(error)")
        }
    }
    
    func loadTieredAchievements() async {
        if let saved = persistenceService.load([TieredAchievement].self, forKey: Self.tieredAchievementsKey) {
            _tieredAchievements = saved
 logger.info("Loaded \(saved.count) tiered achievements")
        } else {
            // Initialize with default achievements
            _tieredAchievements = AchievementFactory.createDefaultAchievements()
            await saveTieredAchievements()
 logger.info("Initialized default tiered achievements")
        }
    }
    
    // (Legacy achievement helpers removed)
}

// MARK: - Update loadPersistedData
extension AppState {
    
    // Recalculate progress from existing data
        internal func recalculateAllTieredAchievementProgress() {
 logger.info("Recomputing tiered achievements from all results...")
            
            // Create a map of existing achievements by category to preserve their IDs
            var existingByCategory: [AchievementCategory: TieredAchievement] = [:]
            for existing in tieredAchievements {
                existingByCategory[existing.category] = existing
            }
            
            // Create new achievements with consistent IDs, but preserve existing IDs if they exist
            var current = AchievementFactory.createDefaultAchievements()
            for i in current.indices {
                // If we have an existing achievement for this category, preserve its ID
                if let existing = existingByCategory[current[i].category] {
                    // Preserve the existing ID to prevent duplicates
                    current[i] = TieredAchievement(
                        id: existing.id,
                        category: current[i].category,
                        requirements: current[i].requirements,
                        progress: current[i].progress
                    )
                }
            }
            
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
            // Enforce union with cached unique games to avoid regressions on partial histories
            if let idx = current.firstIndex(where: { $0.category == .varietyPlayer }) {
                let fromHistory = Set(recentResults.map(\.gameId))
                let unionCount = fromHistory.union(uniqueGamesEver).count
                let monotonicValue = max(current[idx].progress.currentValue, unionCount)
                current[idx].updateProgress(value: monotonicValue)
            }
            // Persist if changed
            if current != tieredAchievements {
                tieredAchievements = current
 logger.info("Tiered achievements recomputed")
            } else {
 logger.info("ℹ Tiered achievements already up to date")
            }
        }
}
