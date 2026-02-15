//
//  AppState+GameLogic.swift
//  StreakSync
//
//  AppState extension for game logic and streak calculations
//

import Foundation
import OSLog

// MARK: - AppState Game Logic Extension
extension AppState {
    
    // MARK: - Streak Updates
    func updateStreak(for result: GameResult) {
        guard let streakIndex = self.streaks.firstIndex(where: { $0.gameId == result.gameId }) else {
 logger.warning("No streak found for game: \(result.gameName)")
            return
        }
        
        let currentStreak = self.streaks[streakIndex]
        let updatedStreak = calculateUpdatedStreak(current: currentStreak, with: result)
        
        // Update streaks array
        var updatedStreaks = self.streaks
        updatedStreaks[streakIndex] = updatedStreak
        setStreaks(updatedStreaks)
        
        #if DEBUG
 logger.info("Updated streak for \(result.gameName): \(currentStreak.currentStreak) → \(updatedStreak.currentStreak)")
 logger.info("Streaks array now contains \(self.streaks.count) streaks")
 logger.info("Updated streak verified: \(self.streaks[streakIndex].currentStreak) days, \(self.streaks[streakIndex].totalGamesPlayed) played")
        
        // NOTE: Caller is responsible for saving streaks
 logger.info("Streak updated in memory - caller must save!")
        #endif
    }
    
    internal func calculateUpdatedStreak(current: GameStreak, with result: GameResult) -> GameStreak {
        #if DEBUG
 logger.info("Calculating updated streak for \(result.gameName)")
 logger.info("Current state: streak=\(current.currentStreak), played=\(current.totalGamesPlayed), completed=\(current.totalGamesCompleted)")
        #endif
        
        let newTotalPlayed = current.totalGamesPlayed + 1
        let newTotalCompleted = current.totalGamesCompleted + (result.completed ? 1 : 0)
        
        var newCurrentStreak = current.currentStreak
        var newMaxStreak = current.maxStreak
        var newStreakStartDate = current.streakStartDate
        
        if result.completed {
            if current.currentStreak == 0 {
                // Starting a new streak
                newCurrentStreak = 1
                newStreakStartDate = result.date
                #if DEBUG
 logger.info("Starting new streak")
                #endif
            } else {
                // Check if this extends the streak
                if let lastPlayed = current.lastPlayedDate {
                    let calendar = Calendar.current
                    let lastPlayedDay = calendar.startOfDay(for: lastPlayed)
                    let resultDay = calendar.startOfDay(for: result.date)
                    let daysBetween = calendar.dateComponents([.day], from: lastPlayedDay, to: resultDay).day ?? 0
                    
                    #if DEBUG
 logger.info("Days between plays: \(daysBetween)")
                    #endif
                    
                    if daysBetween == 1 {
                        // Consecutive day - extend streak
                        newCurrentStreak += 1
                        #if DEBUG
 logger.info("Extending streak to \(newCurrentStreak)")
                        #endif
                    } else if daysBetween == 0 {
                        // Same day - don't increment streak
                        #if DEBUG
 logger.info("Same day play - maintaining streak at \(newCurrentStreak)")
                        #endif
                    } else {
                        // Streak broken - start new one
                        newCurrentStreak = 1
                        newStreakStartDate = result.date
                        #if DEBUG
 logger.info("Streak broken - starting new streak")
                        #endif
                    }
                } else {
                    // No previous play date - start streak at 1
                    newCurrentStreak = 1
                    newStreakStartDate = result.date
                    #if DEBUG
 logger.info("First play - starting streak at 1")
                    #endif
                }
            }
            
            // Update max streak if needed
            newMaxStreak = max(newMaxStreak, newCurrentStreak)
        } else {
            // Failed game - break streak
            newCurrentStreak = 0
            newStreakStartDate = nil
            #if DEBUG
 logger.info("Failed game - breaking streak")
            #endif
        }
        
        let updatedStreak = GameStreak(
            id: current.id,
            gameId: current.gameId,
            gameName: current.gameName,
            currentStreak: newCurrentStreak,
            maxStreak: newMaxStreak,
            totalGamesPlayed: newTotalPlayed,
            totalGamesCompleted: newTotalCompleted,
            lastPlayedDate: result.date,
            streakStartDate: newStreakStartDate
        )
        
        #if DEBUG
 logger.info("New state: streak=\(updatedStreak.currentStreak), played=\(updatedStreak.totalGamesPlayed), completed=\(updatedStreak.totalGamesCompleted)")
        #endif
        
        return updatedStreak
    }
    
    // Legacy achievement helper methods have been consolidated in
    // AppState+TieredAchievements to avoid duplication.
}
