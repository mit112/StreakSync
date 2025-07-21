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
        
        logger.info("Updated streak for \(result.gameName): \(currentStreak.currentStreak) → \(updatedStreak.currentStreak)")
        logger.info("Streaks array now contains \(self.streaks.count) streaks")
        logger.info("Updated streak verified: \(self.streaks[streakIndex].currentStreak) days, \(self.streaks[streakIndex].totalGamesPlayed) played")
        
        // NOTE: Caller is responsible for saving streaks
        logger.info("⚠️ Streak updated in memory - caller must save!")
    }
    
    internal func calculateUpdatedStreak(current: GameStreak, with result: GameResult) -> GameStreak {
        logger.info("📊 Calculating updated streak for \(result.gameName)")
        logger.info("  Current state: streak=\(current.currentStreak), played=\(current.totalGamesPlayed), completed=\(current.totalGamesCompleted)")
        
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
                logger.info("  Starting new streak")
            } else {
                // Check if this extends the streak
                if let lastPlayed = current.lastPlayedDate {
                    let calendar = Calendar.current
                    let lastPlayedDay = calendar.startOfDay(for: lastPlayed)
                    let resultDay = calendar.startOfDay(for: result.date)
                    let daysBetween = calendar.dateComponents([.day], from: lastPlayedDay, to: resultDay).day ?? 0
                    
                    logger.info("  Days between plays: \(daysBetween)")
                    
                    if daysBetween == 1 {
                        // Consecutive day - extend streak
                        newCurrentStreak += 1
                        logger.info("  Extending streak to \(newCurrentStreak)")
                    } else if daysBetween == 0 {
                        // Same day - don't increment streak
                        logger.info("  Same day play - maintaining streak at \(newCurrentStreak)")
                    } else {
                        // Streak broken - start new one
                        newCurrentStreak = 1
                        newStreakStartDate = result.date
                        logger.info("  Streak broken - starting new streak")
                    }
                } else {
                    // No previous play date - start streak at 1
                    newCurrentStreak = 1
                    newStreakStartDate = result.date
                    logger.info("  First play - starting streak at 1")
                }
            }
            
            // Update max streak if needed
            newMaxStreak = max(newMaxStreak, newCurrentStreak)
        } else {
            // Failed game - break streak
            newCurrentStreak = 0
            newStreakStartDate = nil
            logger.info("  Failed game - breaking streak")
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
        
        logger.info("  New state: streak=\(updatedStreak.currentStreak), played=\(updatedStreak.totalGamesPlayed), completed=\(updatedStreak.totalGamesCompleted)")
        
        return updatedStreak
    }
    
    // MARK: - Achievement Checking
    func checkAchievements(for result: GameResult) {
        var newlyUnlocked: [Achievement] = []
        
        newlyUnlocked.append(contentsOf: checkFirstGameAchievements())
        newlyUnlocked.append(contentsOf: checkStreakAchievements(for: result))
        newlyUnlocked.append(contentsOf: checkTotalGamesAchievements())
        newlyUnlocked.append(contentsOf: checkMultipleGamesAchievements())
        
        for achievement in newlyUnlocked {
            unlockAchievement(achievement)
        }
    }
    
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
