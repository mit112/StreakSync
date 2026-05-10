//
//  AppState+Import.swift
//  StreakSync
//
//  Created by MiT on 7/30/25.
//

import Foundation
import OSLog
import SwiftUI

extension AppState {
    // Legacy achievement import removed in tiered-only system
    
    /// Rebuild streaks from imported game results
    @MainActor
    func rebuildStreaksFromResults() async {
 logger.info("Rebuilding streaks from results")
        
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
            var lastCompletedDate: Date?
            
            // Process results to calculate streaks - only count completed games
            for result in sortedResults {
                if result.completed {
                    if currentStreak == 0 {
                        // Starting a new streak
                        currentStreak = 1
                        streakStartDate = result.date
                    } else if let previous = lastCompletedDate {
                        // Check if this continues the streak
                        let daysBetween = GameDateHelper.daysBetween(from: previous, to: result.date)

                        if daysBetween == 1 {
                            currentStreak += 1
                        } else if daysBetween > 1 {
                            // Streak broken by gap
                            maxStreak = max(maxStreak, currentStreak)
                            currentStreak = 1
                            streakStartDate = result.date
                        }
                        // daysBetween == 0: same day, streak count unchanged
                    }
                    lastCompletedDate = result.date
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
        
        // Ensure all games have streak entries (including games with zero results)
        self.streaks = ensureStreaksForAllGames(newStreaks)
        
 logger.info("Rebuilt \(newStreaks.count) streaks")
    }
    
    /// Fix existing Connections results with updated completion logic
    @MainActor
    public func fixExistingConnectionsResults() async {
        // One-time migration — skip entirely once completed for this user
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "connectionsFixV2Complete") { return }
        
        // Find all Connections results
        let connectionsResults = recentResults.filter { $0.gameName.lowercased() == "connections" }
        
 logger.info("Fixing existing Connections results with updated completion logic")
        
        guard !connectionsResults.isEmpty else {
 logger.info("ℹ No Connections results found to fix")
            defaults.set(true, forKey: "connectionsFixV2Complete")
            return
        }
        
        var updatedResults = recentResults
        var didUpdate = false
        
        for (index, result) in recentResults.enumerated() {
            if result.gameName.lowercased() == "connections" {
 logger.info("Checking Connections result: \(result.displayScore), completed: \(result.completed)")
                
                // Reparse the Connections result with updated logic
                if let game = games.first(where: { $0.name.lowercased() == "connections" }) {
                    do {
                        let parser = GameResultParser()
                        let fixedResult = try parser.parse(result.sharedText, for: game)
                        
 logger.info("Reparsed result: \(fixedResult.displayScore), completed: \(fixedResult.completed)")
                        
                        // Always update to ensure consistency (even if completion status is the same)
                        if fixedResult.completed != result.completed || fixedResult.score != result.score {
                            updatedResults[index] = fixedResult
                            didUpdate = true
 logger.info("Fixed Connections result: \(result.displayScore) -> \(fixedResult.displayScore), completed: \(result.completed) -> \(fixedResult.completed)")
                        } else {
 logger.info("ℹ No changes needed for this result")
                        }
                    } catch {
 logger.warning("Failed to reparse Connections result: \(error)")
 logger.warning("Original shared text: \(result.sharedText)")
                    }
                } else {
 logger.warning("Could not find Connections game in games list")
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
            NotificationCenter.default.post(name: .appGameDataUpdated, object: nil)
            
 logger.info("Fixed existing Connections results and rebuilt streaks")
        } else {
 logger.debug("ℹ No Connections results needed fixing")
        }
        
        // Mark migration as permanently complete
        defaults.set(true, forKey: "connectionsFixV2Complete")
    }
    
    /// Force fix all Connections results (for debugging/manual trigger)
    @MainActor
    public func forceFixConnectionsResults() async {
 logger.info("FORCE FIXING Connections results...")
        await fixExistingConnectionsResults()
    }
    
    /// Force rebuild all streaks from scratch (for debugging/manual trigger)
    @MainActor
    public func forceRebuildAllStreaks() async {
 logger.info("FORCE REBUILDING all streaks from scratch...")
        await rebuildStreaksFromResults()
        await saveStreaks()
        
        // Notify UI
        invalidateCache()
        NotificationCenter.default.post(name: .appGameDataUpdated, object: nil)
        
 logger.info("All streaks rebuilt and saved")
    }
    
    /// Debug function to check Connections results
    @MainActor
    public func debugConnectionsResults() {
 logger.info("DEBUG: Checking all Connections results")
        
        let connectionsResults = recentResults.filter { $0.gameName.lowercased() == "connections" }
 logger.info("Found \(connectionsResults.count) Connections results")
        
        for (index, result) in connectionsResults.enumerated() {
 logger.info("Result \(index + 1):")
 logger.info("- Display Score: \(result.displayScore)")
 logger.info("- Score: \(result.score ?? -1)")
 logger.info("- Max Attempts: \(result.maxAttempts)")
 logger.info("- Completed: \(result.completed)")
 logger.info("- Date: \(result.date)")
 logger.info("- Shared Text: \(result.sharedText)")
        }
        
        // Check if Connections game exists
        if let game = games.first(where: { $0.name.lowercased() == "connections" }) {
 logger.info("Connections game found: \(game.displayName)")
        } else {
 logger.warning("Connections game not found in games list")
        }
    }
    
    /// Save all data to persistence using the canonical save methods
    @MainActor
    func saveAllData() async {
        await saveGameResults()
        await saveStreaks()
        await saveTieredAchievements()
 logger.info("All data saved successfully")
    }

    // MARK: - App Store Review Mode

    /// Swaps to the demo social service and seeds 14 days of game results.
    /// Triggered by tapping the version label 5× in Settings → About.
    @MainActor
    func activateReviewMode() async {
        socialService = ReviewModeSocialService()
        reviewModeEnabled = true
        await applyReviewSeedData()
 logger.info("Review mode activated")
    }

    @MainActor
    private func applyReviewSeedData() async {
        let cal = Calendar.current
        let now = Date()

        func daysAgo(_ n: Int) -> Date {
            cal.startOfDay(for: cal.date(byAdding: .day, value: -n, to: now) ?? now)
        }

        let wordleId = UUID(staticString: "550e8400-e29b-41d4-a716-446655440000")
        let connectionsId = UUID(staticString: "550e8400-e29b-41d4-a716-446655440003")
        let strandsId = UUID(staticString: "550e8400-e29b-41d4-a716-446655440007")
        let miniXId = UUID(staticString: "550e8400-e29b-41d4-a716-446655440005")

        // 14-day Wordle streak
        let wordleScores = [3, 4, 3, 2, 5, 4, 3, 4, 3, 5, 4, 3, 4, 3]
        var results: [GameResult] = wordleScores.enumerated().map { idx, score in
            GameResult(
                gameId: wordleId, gameName: "wordle", date: daysAgo(idx),
                score: score, maxAttempts: 6, completed: true,
                sharedText: "Wordle \(1400 - idx) \(score)/6"
            )
        }

        // Connections (5 results)
        for (day, score) in [(0, 4), (1, 4), (3, 4), (5, 3), (7, 4)] {
            results.append(GameResult(
                gameId: connectionsId, gameName: "connections", date: daysAgo(day),
                score: score, maxAttempts: 4, completed: true,
                sharedText: "Connections Puzzle #\(500 - day) 🟩🟨🟦🟪"
            ))
        }

        // Strands (3 results)
        for (day, hints) in [(0, 1), (2, 0), (4, 2)] {
            results.append(GameResult(
                gameId: strandsId, gameName: "strands", date: daysAgo(day),
                score: hints, maxAttempts: 10, completed: true,
                sharedText: "Strands #\(400 - day)"
            ))
        }

        // Mini Crossword (2 results)
        for (day, secs) in [(1, 120), (3, 95)] {
            results.append(GameResult(
                gameId: miniXId, gameName: "minicrossword", date: daysAgo(day),
                score: secs, maxAttempts: 600, completed: true,
                sharedText: "Mini Crossword \(secs / 60):\(String(format: "%02d", secs % 60))"
            ))
        }

        results.sort { $0.date > $1.date }
        setRecentResults(results)
        buildResultsCache()
        invalidateCache()
        await rebuildStreaksFromResults()
        await normalizeStreaksForMissedDays()
        await checkAllAchievements()
 logger.info("Review seed data applied: \(results.count) results")
    }
}
