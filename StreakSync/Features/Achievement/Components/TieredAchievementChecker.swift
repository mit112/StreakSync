//
//  TieredAchievementChecker.swift
//  StreakSync
//
//  Achievement progress tracking and checking system
//

import Foundation
import OSLog

// MARK: - Achievement Checker
struct TieredAchievementChecker {
    
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AchievementChecker")
    
    // MARK: - Check All Achievements
    
    func checkAllAchievements(
        for result: GameResult,
        allResults: [GameResult],
        streaks: [GameStreak],
        games: [Game],
        currentAchievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []
        
        // Check each achievement category
        unlocks.append(contentsOf: checkStreakMaster(result: result, streaks: streaks, achievements: &currentAchievements))
        unlocks.append(contentsOf: checkGameCollector(allResults: allResults, achievements: &currentAchievements))
        unlocks.append(contentsOf: checkPerfectionist(result: result, allResults: allResults, achievements: &currentAchievements))
        unlocks.append(contentsOf: checkDailyDevotee(allResults: allResults, achievements: &currentAchievements))
        unlocks.append(contentsOf: checkVarietyPlayer(result: result, allResults: allResults, games: games, achievements: &currentAchievements))
        unlocks.append(contentsOf: checkSpeedDemon(
            result: result,
            allResults: allResults,
            games: games,
            achievements: &currentAchievements
        ))
        unlocks.append(contentsOf: checkTimeBasedAchievements(result: result, allResults: allResults, achievements: &currentAchievements))
        unlocks.append(contentsOf: checkComebackChampion(result: result, streaks: streaks, allResults: allResults, achievements: &currentAchievements))
        unlocks.append(contentsOf: checkMarathonRunner(allResults: allResults, achievements: &currentAchievements))
        
        return unlocks
    }
    
    // MARK: - Streak Master
    
    private func checkStreakMaster(
        result: GameResult,
        streaks: [GameStreak],
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []
        
        guard let gameStreak = streaks.first(where: { $0.gameId == result.gameId }) else { return unlocks }
        
        // Check global streak master achievement
        if let index = achievements.firstIndex(where: {
            $0.category == .streakMaster &&
            $0.requirements.first?.specificGameId == nil
        }) {
            let oldTier = achievements[index].progress.currentTier
            achievements[index].updateProgress(value: gameStreak.currentStreak)
            
            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
 logger.info("Unlocked Streak Master \(newTier.displayName) - \(gameStreak.currentStreak) days")
            }
        }
        
        // Could also check game-specific streak achievements here if needed
        
        return unlocks
    }
    
    // MARK: - Game Collector
    
    private func checkGameCollector(
        allResults: [GameResult],
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []
        
        let totalGamesPlayed = allResults.count
        
        if let index = achievements.firstIndex(where: { $0.category == .gameCollector }) {
            let oldTier = achievements[index].progress.currentTier
            achievements[index].updateProgress(value: totalGamesPlayed)
            
            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
 logger.info("Unlocked Game Collector \(newTier.displayName) - \(totalGamesPlayed) games")
            }
        }
        
        return unlocks
    }
    
    // MARK: - Perfectionist
    
    private func checkPerfectionist(
        result: GameResult,
        allResults: [GameResult],
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []
        
        // Count successful completions
        let successfulGames = allResults.filter { $0.isSuccess }.count
        
        if let index = achievements.firstIndex(where: { $0.category == .perfectionist }) {
            let oldTier = achievements[index].progress.currentTier
            achievements[index].updateProgress(value: successfulGames)
            
            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
 logger.info("Unlocked Perfectionist \(newTier.displayName) - \(successfulGames) perfect games")
            }
        }
        
        return unlocks
    }
    
    // MARK: - Daily Devotee
    
    private func checkDailyDevotee(
        allResults: [GameResult],
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []
        
        // Calculate consecutive days with at least one game
        let consecutiveDays = calculateConsecutiveDaysPlayed(results: allResults)
        
        if let index = achievements.firstIndex(where: { $0.category == .dailyDevotee }) {
            let oldTier = achievements[index].progress.currentTier
            achievements[index].updateProgress(value: consecutiveDays)
            
            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
 logger.info("Unlocked Daily Devotee \(newTier.displayName) - \(consecutiveDays) consecutive days")
            }
        }
        
        return unlocks
    }
    
    // MARK: - Variety Player
    
    private func checkVarietyPlayer(
        result: GameResult,
        allResults: [GameResult],
        games: [Game],
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []
        
        // Count unique games played across all time (all recorded results)
        let uniqueGamesEver = Set(allResults.map(\.gameId)).count
        
        if let index = achievements.firstIndex(where: { $0.category == .varietyPlayer }) {
            let oldTier = achievements[index].progress.currentTier
            // Make progress monotonic; never decrease even if history is partial
            let newValue = max(achievements[index].progress.currentValue, uniqueGamesEver)
            achievements[index].updateProgress(value: newValue)
            
            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
 logger.info("Unlocked Variety Player \(newTier.displayName) - \(newValue) different games overall")
            }
        }
        
        return unlocks
    }
    
    // MARK: - Speed Demon
    
    private func checkSpeedDemon(
        result: GameResult,
        allResults: [GameResult],
        games: [Game],
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []
        
        // Count only minimal-attempt wins per game
        let minimalAttemptWins = allResults.filter { r in
            guard let score = r.score, r.isSuccess else { return false }
            guard let minAttempts = minimalAttempts(for: r.gameId, games: games, defaultMax: r.maxAttempts) else { return false }
            return score == minAttempts
        }.count
        
        if let index = achievements.firstIndex(where: { $0.category == .speedDemon }) {
            let oldTier = achievements[index].progress.currentTier
            
            achievements[index].updateProgress(value: minimalAttemptWins)
            
            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
 logger.info("Unlocked Speed Demon \(newTier.displayName) - minimal-attempt wins: \(minimalAttemptWins)")
            }
        }
        
        return unlocks
    }
    
    // MARK: - Time-Based Achievements
    
    private func checkTimeBasedAchievements(
        result: GameResult,
        allResults: [GameResult],
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []
        
        let calendar = Calendar.current
        
        // Early Bird: 05:00–08:59 local time (exclusive band)
        let earlyBirdCount = allResults.filter { result in
            let hour = calendar.component(.hour, from: result.date)
            return hour >= 5 && hour < 9
        }.count
        
        if let index = achievements.firstIndex(where: { $0.category == .earlyBird }) {
            let oldTier = achievements[index].progress.currentTier
            achievements[index].updateProgress(value: earlyBirdCount)
            
            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
            }
        }
        
        // Night Owl: 00:00–04:59 local time (exclusive band)
        let nightOwlCount = allResults.filter { result in
            let hour = calendar.component(.hour, from: result.date)
            return hour < 5
        }.count
        
        if let index = achievements.firstIndex(where: { $0.category == .nightOwl }) {
            let oldTier = achievements[index].progress.currentTier
            achievements[index].updateProgress(value: nightOwlCount)
            
            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
            }
        }
        
        return unlocks
    }
    
    // MARK: - Comeback Champion
    
    private func checkComebackChampion(
        result: GameResult,
        streaks: [GameStreak],
        allResults: [GameResult],
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []
        
        // Calculate cumulative number of comeback runs across all games.
        // A "comeback run" is a new contiguous streak segment that begins
        // after a gap (> 1 day) between play days for a given game.
        let calendar = Calendar.current
        
        // Group by game and deduplicate multiple results on the same day
        let resultsByGame: [UUID: [Date]] = {
            var dict: [UUID: [Date]] = [:]
            for r in allResults {
                let day = calendar.startOfDay(for: r.date)
                if dict[r.gameId] == nil {
                    dict[r.gameId] = [day]
                } else {
                    // Append only if this day isn't already recorded
                    if dict[r.gameId]!.last != day && !(dict[r.gameId]!.contains(day)) {
                        dict[r.gameId]!.append(day)
                    }
                }
            }
            return dict
        }()
        
        var totalComebacks = 0
        for (_, daysUnsorted) in resultsByGame {
            let days = daysUnsorted.sorted()
            if days.count <= 1 { continue }
            for i in 1..<days.count {
                let delta = calendar.dateComponents([.day], from: days[i-1], to: days[i]).day ?? 0
                if delta > 1 { totalComebacks += 1 }
            }
        }
        
        if let index = achievements.firstIndex(where: { $0.category == .comebackChampion }) {
            let oldTier = achievements[index].progress.currentTier
            // Make progress monotonic in case of partial histories; never decrease
            let newValue = max(achievements[index].progress.currentValue, totalComebacks)
            achievements[index].updateProgress(value: newValue)
            
            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
            }
        }
        
        return unlocks
    }
    
    // MARK: - Marathon Runner
    
    private func checkMarathonRunner(
        allResults: [GameResult],
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []
        
        // Count total active days
        let uniqueDays = Set(allResults.map { result in
            Calendar.current.startOfDay(for: result.date)
        }).count
        
        if let index = achievements.firstIndex(where: { $0.category == .marathonRunner }) {
            let oldTier = achievements[index].progress.currentTier
            achievements[index].updateProgress(value: uniqueDays)
            
            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
 logger.info("Unlocked Marathon Runner \(newTier.displayName) - \(uniqueDays) active days")
            }
        }
        
        return unlocks
    }
    
    // MARK: - Helper Methods
    
    private func calculateConsecutiveDaysPlayed(results: [GameResult]) -> Int {
        guard !results.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let sortedDates = results
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()
        
        var currentStreak = 1
        var maxStreak = 1
        
        for i in 1..<sortedDates.count {
            let daysBetween = calendar.dateComponents(
                [.day],
                from: sortedDates[i-1],
                to: sortedDates[i]
            ).day ?? 0
            
            if daysBetween == 1 {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else if daysBetween > 1 {
                currentStreak = 1
            }
        }
        
        // Check if streak continues to today
        if let lastDate = sortedDates.last {
            let daysFromLastToToday = calendar.dateComponents(
                [.day],
                from: lastDate,
                to: calendar.startOfDay(for: Date())
            ).day ?? 0
            
            if daysFromLastToToday > 1 {
                return 0 // Streak is broken
            }
        }
        
        return currentStreak
    }

    /// Returns the minimal attempts required to win for a given game.
    /// If unknown, returns nil so the result won't count towards Speed Demon.
    private func minimalAttempts(for gameId: UUID, games: [Game], defaultMax: Int) -> Int? {
        guard let game = games.first(where: { $0.id == gameId }) else { return nil }
        let name = game.name.lowercased()
        switch name {
        case "wordle", "nerdle", "framed", "xordle", "kilordle", "primel", "rankdle":
            return 1
        case "quordle":
            // Consider minimal as solving in the first row across boards (best-case attempt count)
            return 1
        default:
            // Heuristic: if the game uses attempts (maxAttempts > 1), minimal is 1
            return defaultMax > 1 ? 1 : nil
        }
    }
}

// MARK: - Achievement Unlock Model
struct AchievementUnlock {
    let achievement: TieredAchievement
    let tier: AchievementTier
    let timestamp: Date
}
