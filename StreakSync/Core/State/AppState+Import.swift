//
//  AppState+Import.swift
//  StreakSync
//
//  Created by MiT on 7/30/25.
//

import Foundation
import SwiftUI
import OSLog

extension AppState {
    /// Import achievements (merge with existing)
    @MainActor
    func importAchievements(_ newAchievements: [Achievement]) async {
        for achievement in newAchievements {
            if !achievements.contains(where: { $0.id == achievement.id }) {
                // Add the achievement if it's unlocked
                if achievement.isUnlocked {
                    achievements.append(achievement)
                }
            }
        }
    }
    
    /// Rebuild streaks from imported game results
    @MainActor
    func rebuildStreaksFromResults() async {
        logger.info("🔄 Rebuilding streaks from results")
        
        // Group results by game
        let resultsByGame = Dictionary(grouping: recentResults) { $0.gameId }
        
        // Create new streaks array
        var newStreaks: [GameStreak] = []
        
        // Rebuild streak for each game
        for (gameId, results) in resultsByGame {
            guard let game = games.first(where: { $0.id == gameId }) else { continue }
            
            // Sort results by date
            let sortedResults = results.sorted { $0.date < $1.date }
            
            // Calculate streak info
            var currentStreak = 0
            var maxStreak = 0
            var lastPlayedDate: Date?
            var streakStartDate: Date?
            
            // Process results to calculate streaks
            for (index, result) in sortedResults.enumerated() {
                if index == 0 {
                    currentStreak = 1
                    streakStartDate = result.date
                } else {
                    let previousResult = sortedResults[index - 1]
                    let daysBetween = Calendar.current.dateComponents([.day],
                                                                     from: previousResult.date,
                                                                     to: result.date).day ?? 0
                    
                    if daysBetween == 1 {
                        currentStreak += 1
                    } else if daysBetween > 1 {
                        // Streak broken
                        maxStreak = max(maxStreak, currentStreak)
                        currentStreak = 1
                        streakStartDate = result.date
                    }
                }
                
                lastPlayedDate = result.date
            }
            
            maxStreak = max(maxStreak, currentStreak)
            
            // Check if streak is still active (played today or yesterday)
            if let lastPlayed = lastPlayedDate {
                let daysSinceLastPlayed = Calendar.current.dateComponents([.day],
                                                                         from: lastPlayed,
                                                                         to: Date()).day ?? 0
                if daysSinceLastPlayed > 1 {
                    currentStreak = 0
                }
            }
            
            // Count completed games (games with scores)
            let completedCount = results.filter { $0.score != nil }.count
            
            // Create streak object
            let streak = GameStreak(
                gameId: game.id,
                gameName: game.displayName,
                currentStreak: currentStreak,
                maxStreak: maxStreak,
                totalGamesPlayed: results.count,
                totalGamesCompleted: completedCount,
                lastPlayedDate: lastPlayedDate,
                streakStartDate: streakStartDate
            )
            
            newStreaks.append(streak)
        }
        
        // Update streaks array
        self.streaks = newStreaks
        
        logger.info("✅ Rebuilt \(newStreaks.count) streaks")
    }
    
    /// Save all data to persistence
    @MainActor
    func saveAllData() async {
        // Manually trigger persistence for all data types
        do {
            // Save recent results
            try persistenceService.save(recentResults, forKey: PersistenceKeys.recentResults)
            
            // Save achievements
            try persistenceService.save(achievements, forKey: PersistenceKeys.achievements)
            
            // Save streaks
            try persistenceService.save(streaks, forKey: PersistenceKeys.streaks)
            
            logger.info("✅ All data saved successfully")
        } catch {
            logger.error("❌ Failed to save data: \(error)")
        }
    }
}

// MARK: - Persistence Keys
private enum PersistenceKeys {
    static let recentResults = "recentResults"
    static let achievements = "achievements"
    static let streaks = "streaks"
}
