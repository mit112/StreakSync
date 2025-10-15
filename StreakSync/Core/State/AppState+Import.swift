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
            
            // Process results to calculate streaks - only count completed games
            for (index, result) in sortedResults.enumerated() {
                if result.completed {
                    if currentStreak == 0 {
                        // Starting a new streak
                        currentStreak = 1
                        streakStartDate = result.date
                    } else {
                        // Check if this continues the streak
                        let previousCompletedResult = sortedResults.prefix(index).last { $0.completed }
                        if let previous = previousCompletedResult {
                            let daysBetween = Calendar.current.dateComponents([.day],
                                                                             from: previous.date,
                                                                             to: result.date).day ?? 0
                            
                            if daysBetween == 1 {
                                currentStreak += 1
                            } else if daysBetween > 1 {
                                // Streak broken by gap
                                maxStreak = max(maxStreak, currentStreak)
                                currentStreak = 1
                                streakStartDate = result.date
                            }
                        } else {
                            // First completed game
                            currentStreak = 1
                            streakStartDate = result.date
                        }
                    }
                } else {
                    // Failed game - break current streak
                    if currentStreak > 0 {
                        maxStreak = max(maxStreak, currentStreak)
                        currentStreak = 0
                        streakStartDate = nil
                    }
                }
                
                lastPlayedDate = result.date
            }
            
            maxStreak = max(maxStreak, currentStreak)
            
            // FIXED: Don't automatically break streaks based on time alone
            // Streaks should only be broken if there's an actual gap in completed games
            // The streak calculation above already handles this correctly by counting consecutive days
            
            // Count completed games (games that were actually completed)
            let completedCount = results.filter { $0.completed }.count
            
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
    
    /// Fix existing Connections results with updated completion logic
    @MainActor
    public func fixExistingConnectionsResults() async {
        logger.info("🔧 Fixing existing Connections results with updated completion logic")
        
        // Find all Connections results
        let connectionsResults = recentResults.filter { $0.gameName.lowercased() == "connections" }
        logger.info("🔍 Found \(connectionsResults.count) Connections results to check")
        
        guard !connectionsResults.isEmpty else {
            logger.info("ℹ️ No Connections results found to fix")
            return
        }
        
        var updatedResults = recentResults
        var didUpdate = false
        
        for (index, result) in recentResults.enumerated() {
            if result.gameName.lowercased() == "connections" {
                logger.info("🔍 Checking Connections result: \(result.displayScore), completed: \(result.completed)")
                
                // Reparse the Connections result with updated logic
                if let game = games.first(where: { $0.name.lowercased() == "connections" }) {
                    do {
                        let parser = GameResultParser()
                        let fixedResult = try parser.parse(result.sharedText, for: game)
                        
                        logger.info("🔍 Reparsed result: \(fixedResult.displayScore), completed: \(fixedResult.completed)")
                        
                        // Always update to ensure consistency (even if completion status is the same)
                        if fixedResult.completed != result.completed || fixedResult.score != result.score {
                            updatedResults[index] = fixedResult
                            didUpdate = true
                            logger.info("🔧 Fixed Connections result: \(result.displayScore) -> \(fixedResult.displayScore), completed: \(result.completed) -> \(fixedResult.completed)")
                        } else {
                            logger.info("ℹ️ No changes needed for this result")
                        }
                    } catch {
                        logger.warning("⚠️ Failed to reparse Connections result: \(error)")
                        logger.warning("⚠️ Original shared text: \(result.sharedText)")
                    }
                } else {
                    logger.warning("⚠️ Could not find Connections game in games list")
                }
            }
        }
        
        if didUpdate {
            // Update the results
            setRecentResults(updatedResults.sorted { $0.date > $1.date })
            buildResultsCache()
            
            // Rebuild streaks with corrected data
            await rebuildStreaksFromResults()
            
            // Save the corrected data
            await saveGameResults()
            await saveStreaks()
            
            // Notify UI
            invalidateCache()
            NotificationCenter.default.post(name: NSNotification.Name("GameDataUpdated"), object: nil)
            
            logger.info("✅ Fixed existing Connections results and rebuilt streaks")
        } else {
            logger.info("ℹ️ No Connections results needed fixing")
        }
    }
    
    /// Force fix all Connections results (for debugging/manual trigger)
    @MainActor
    public func forceFixConnectionsResults() async {
        logger.info("🔧 FORCE FIXING Connections results...")
        await fixExistingConnectionsResults()
    }
    
    /// Force rebuild all streaks from scratch (for debugging/manual trigger)
    @MainActor
    public func forceRebuildAllStreaks() async {
        logger.info("🔧 FORCE REBUILDING all streaks from scratch...")
        await rebuildStreaksFromResults()
        await saveStreaks()
        
        // Notify UI
        invalidateCache()
        NotificationCenter.default.post(name: NSNotification.Name("GameDataUpdated"), object: nil)
        
        logger.info("✅ All streaks rebuilt and saved")
    }
    
    /// Debug function to check Connections results
    @MainActor
    public func debugConnectionsResults() {
        logger.info("🔍 DEBUG: Checking all Connections results")
        
        let connectionsResults = recentResults.filter { $0.gameName.lowercased() == "connections" }
        logger.info("🔍 Found \(connectionsResults.count) Connections results")
        
        for (index, result) in connectionsResults.enumerated() {
            logger.info("🔍 Result \(index + 1):")
            logger.info("  - Display Score: \(result.displayScore)")
            logger.info("  - Score: \(result.score ?? -1)")
            logger.info("  - Max Attempts: \(result.maxAttempts)")
            logger.info("  - Completed: \(result.completed)")
            logger.info("  - Date: \(result.date)")
            logger.info("  - Shared Text: \(result.sharedText)")
        }
        
        // Check if Connections game exists
        if let game = games.first(where: { $0.name.lowercased() == "connections" }) {
            logger.info("✅ Connections game found: \(game.displayName)")
        } else {
            logger.warning("⚠️ Connections game not found in games list")
        }
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
