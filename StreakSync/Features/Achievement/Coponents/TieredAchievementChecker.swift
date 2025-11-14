//
//  TieredAchievementChecker.swift
//  StreakSync
//
//  Achievement progress tracking and checking system
//

/*
 * TIEREDACHIEVEMENTCHECKER - ACHIEVEMENT PROGRESS AND UNLOCK SYSTEM
 * 
 * WHAT THIS FILE DOES:
 * This file is the "achievement engine" of the app. It monitors all user activity and determines
 * when achievements should be unlocked or progressed. Think of it as a "progress tracker" that
 * watches everything the user does and rewards them with achievements when they reach certain
 * milestones. It handles complex logic like streak tracking, game variety, speed records, and
 * other accomplishments that make the app more engaging and rewarding.
 * 
 * WHY IT EXISTS:
 * Achievements make apps more engaging and give users goals to work toward. This file centralizes
 * all the logic for determining when achievements should be unlocked, making it easy to add new
 * achievements or modify existing ones. It also ensures that achievements are fair and consistent
 * across all users, regardless of when they started using the app.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This system drives user engagement and retention
 * - Tracks progress toward various achievement categories (streaks, games played, speed, etc.)
 * - Handles complex achievement logic like consecutive days, game variety, and comeback streaks
 * - Provides immediate feedback when achievements are unlocked
 * - Supports tiered achievements (bronze, silver, gold) for different difficulty levels
 * - Integrates with the celebration system for user satisfaction
 * 
 * WHAT IT REFERENCES:
 * - GameResult: Individual game results to analyze
 * - GameStreak: Streak data for streak-based achievements
 * - Game: Game information for variety and specific game achievements
 * - TieredAchievement: The achievement definitions and progress tracking
 * - AchievementUnlock: Results when achievements are unlocked
 * - Logger: For debugging and monitoring achievement unlocks
 * 
 * WHAT REFERENCES IT:
 * - AppState: Uses this to check achievements when new results are added
 * - Achievement views: Display progress and unlocked achievements
 * - Celebration system: Shows achievements when they're unlocked
 * - Analytics: Tracks achievement unlock rates and user progress
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. CODE ORGANIZATION:
 *    - This file is very large (400+ lines) - should be split into smaller files
 *    - Consider separating into: StreakAchievements.swift, GameAchievements.swift, SpeedAchievements.swift
 *    - Create a protocol-based approach for different achievement types
 *    - Use a factory pattern to create achievement checkers
 * 
 * 2. ACHIEVEMENT LOGIC IMPROVEMENTS:
 *    - The current logic is hard-coded - could be more flexible
 *    - Consider using a configuration-based approach for achievements
 *    - Add support for custom achievement definitions
 *    - Implement achievement dependencies and prerequisites
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation checks all achievements on every result - could be optimized
 *    - Consider incremental achievement checking
 *    - Add caching for expensive calculations
 *    - Implement background processing for complex achievements
 * 
 * 4. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for all achievement logic
 *    - Test edge cases and boundary conditions
 *    - Add property-based testing for achievement progress
 *    - Test achievement unlock timing and conditions
 * 
 * 5. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for each achievement type
 *    - Document the achievement unlock conditions
 *    - Add examples of how achievements work
 *    - Create achievement flow diagrams
 * 
 * 6. ERROR HANDLING:
 *    - The current error handling is basic - could be more robust
 *    - Add validation for achievement data
 *    - Implement fallback strategies for failed checks
 *    - Add logging for achievement system issues
 * 
 * 7. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new achievement types
 *    - Add support for dynamic achievements
 *    - Implement achievement templates
 *    - Add support for user-defined achievements
 * 
 * 8. ANALYTICS INTEGRATION:
 *    - Add detailed analytics for achievement progress
 *    - Track achievement unlock rates and patterns
 *    - Monitor user engagement with achievements
 *    - Add A/B testing support for achievement changes
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Achievement systems: Reward systems that encourage user engagement
 * - Progress tracking: Monitoring user activity to determine achievements
 * - Tiered systems: Different levels of difficulty (bronze, silver, gold)
 * - State management: Keeping track of achievement progress over time
 * - Event-driven programming: Responding to user actions with achievements
 * - Data analysis: Processing user data to determine achievements
 * - User engagement: Making apps more fun and rewarding to use
 * - Gamification: Adding game-like elements to non-game apps
 */

import Foundation
import OSLog

// MARK: - Achievement Checker
@MainActor
final class TieredAchievementChecker {
    
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
                logger.info("🏆 Unlocked Streak Master \(newTier.displayName) - \(gameStreak.currentStreak) days")
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
                logger.info("🏆 Unlocked Game Collector \(newTier.displayName) - \(totalGamesPlayed) games")
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
                logger.info("🏆 Unlocked Perfectionist \(newTier.displayName) - \(successfulGames) perfect games")
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
                logger.info("🏆 Unlocked Daily Devotee \(newTier.displayName) - \(consecutiveDays) consecutive days")
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
                logger.info("🏆 Unlocked Variety Player \(newTier.displayName) - \(newValue) different games overall")
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
                logger.info("🏆 Unlocked Speed Demon \(newTier.displayName) - minimal-attempt wins: \(minimalAttemptWins)")
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
                logger.info("🏆 Unlocked Marathon Runner \(newTier.displayName) - \(uniqueDays) active days")
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
