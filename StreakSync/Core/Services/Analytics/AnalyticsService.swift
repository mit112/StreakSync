//
//  AnalyticsService.swift
//  StreakSync
//
//  Analytics data processing and calculations service
//

import Foundation
import OSLog

// MARK: - Analytics Service
@MainActor
final class AnalyticsService: ObservableObject {
    
    // MARK: - Dependencies
    let appState: AppState
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AnalyticsService")
    
    // MARK: - Cached Data
    private var cachedAnalytics: [String: AnalyticsData] = [:]
    private var lastCacheUpdate: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    init(appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Public Methods
    
    /// Get comprehensive analytics data for a specific time range and optional game
    func getAnalyticsData(for timeRange: AnalyticsTimeRange, game: Game? = nil) async -> AnalyticsData {
        let cacheKey = "\(timeRange.rawValue)_\(game?.id.uuidString ?? "all")"
        
        // Check cache first
        if let cached = cachedAnalytics[cacheKey],
           let lastUpdate = lastCacheUpdate,
           Date().timeIntervalSince(lastUpdate) < cacheValidityDuration {
            logger.info("📊 Returning cached analytics for \(timeRange.displayName) - \(game?.displayName ?? "All Games")")
            return cached
        }
        
        logger.info("📊 Calculating analytics for \(timeRange.displayName) - \(game?.displayName ?? "All Games")")
        
        // Calculate all analytics components
        let overview = await calculateOverview(for: timeRange, game: game)
        let streakTrends = await calculateStreakTrends(for: timeRange, game: game)
        let gameAnalytics = await calculateGameAnalytics(for: timeRange)
        let achievementAnalytics = await calculateAchievementAnalytics()
        let personalBests = await calculatePersonalBests()
        let weeklySummaries = await calculateWeeklySummaries(for: timeRange)
        
        let analyticsData = AnalyticsData(
            overview: overview,
            streakTrends: streakTrends,
            gameAnalytics: gameAnalytics,
            achievementAnalytics: achievementAnalytics,
            personalBests: personalBests,
            weeklySummaries: weeklySummaries,
            timeRange: timeRange
        )
        
        // Cache the result
        cachedAnalytics[cacheKey] = analyticsData
        lastCacheUpdate = Date()
        
        logger.info("✅ Analytics calculation complete for \(timeRange.displayName) - \(game?.displayName ?? "All Games")")
        return analyticsData
    }
    
    /// Get streak trends for a specific time range
    func getStreakTrends(for timeRange: AnalyticsTimeRange) async -> [StreakTrendPoint] {
        return await calculateStreakTrends(for: timeRange)
    }
    
    /// Get analytics for a specific game
    func getGameAnalytics(for gameId: UUID, timeRange: AnalyticsTimeRange = .week) async -> GameAnalytics? {
        guard let game = appState.games.first(where: { $0.id == gameId }) else {
            logger.warning("⚠️ Game not found for analytics: \(gameId)")
            return nil
        }
        
        let streak = appState.getStreak(for: game)
        let recentResults = getGameResults(for: gameId, in: timeRange)
        let trendData = await calculateGameTrendData(for: gameId, in: timeRange)
        let personalBest = calculatePersonalBest(for: gameId)
        let averageScore = calculateAverageScore(for: gameId, in: timeRange)
        
        return GameAnalytics(
            game: game,
            streak: streak,
            recentResults: recentResults,
            trendData: trendData,
            personalBest: personalBest,
            averageScore: averageScore
        )
    }
    
    /// Get achievement analytics
    func getAchievementAnalytics() async -> AchievementAnalytics {
        return await calculateAchievementAnalytics()
    }
    
    /// Get personal bests
    func getPersonalBests() async -> [PersonalBest] {
        return await calculatePersonalBests()
    }
    
    /// Clear analytics cache
    func clearCache() {
        cachedAnalytics.removeAll()
        lastCacheUpdate = nil
        logger.info("🗑️ Analytics cache cleared")
    }
    
    // MARK: - Private Calculation Methods
    
    private func calculateOverview(for timeRange: AnalyticsTimeRange, game: Game? = nil) async -> AnalyticsOverview {
        // Filter streaks by game if specified
        let relevantStreaks = game != nil ? 
            appState.streaks.filter { $0.gameId == game!.id } : 
            appState.streaks
        
        let activeStreaks = relevantStreaks.filter { $0.isActive }
        let totalActiveStreaks = activeStreaks.count
        
        // Use all-time max streak (best streak ever achieved)
        // Note: Despite the variable name, this represents the longest streak ever, not just current active streaks
        let longestCurrentStreak = relevantStreaks.map(\.maxStreak).max() ?? 0
        
        // Calculate games played and completed within the time range
        let (startDate, endDate) = timeRange.dateRange
        var timeRangeResults = appState.recentResults.filter { result in
            result.date >= startDate && result.date <= endDate
        }
        
        // Filter by game if specified
        if let game = game {
            timeRangeResults = timeRangeResults.filter { $0.gameId == game.id }
        }
        
        let totalGamesPlayed = timeRangeResults.count
        let totalGamesCompleted = timeRangeResults.filter(\.completed).count
        
        // Calculate completion rate for the time range
        let averageCompletionRate = totalGamesPlayed > 0 ? Double(totalGamesCompleted) / Double(totalGamesPlayed) : 0.0
        
        // Calculate streak consistency for the time range
        let streakConsistency = calculateStreakConsistency(for: timeRange, game: game)
        
        // Find most played game in the time range (only relevant when viewing all games)
        let mostPlayedGame: Game?
        if game == nil {
            let gamePlayCounts = Dictionary(grouping: timeRangeResults, by: { $0.gameId })
                .mapValues { $0.count }
            
            mostPlayedGame = gamePlayCounts
                .max(by: { $0.value < $1.value })
                .flatMap { (gameId, _) in
                    appState.games.first { $0.id == gameId }
                }
        } else {
            mostPlayedGame = game
        }
        
        // Get recent activity for the time range
        let recentActivity = timeRangeResults
            .sorted { $0.date > $1.date }
        
        return AnalyticsOverview(
            totalActiveStreaks: totalActiveStreaks,
            longestCurrentStreak: longestCurrentStreak,
            totalGamesPlayed: totalGamesPlayed,
            totalGamesCompleted: totalGamesCompleted,
            totalAchievementsUnlocked: 0, // TODO: Calculate from achievements
            averageCompletionRate: averageCompletionRate,
            streakConsistency: streakConsistency,
            mostPlayedGame: mostPlayedGame,
            recentActivity: recentActivity
        )
    }
    
    private func calculateStreakTrends(for timeRange: AnalyticsTimeRange, game: Game? = nil) async -> [StreakTrendPoint] {
        let (startDate, endDate) = timeRange.dateRange
        let calendar = Calendar.current
        var trends: [StreakTrendPoint] = []
        
        // Get all relevant results for the time range
        var relevantResults = appState.recentResults.filter { result in
            result.date >= startDate && result.date <= endDate
        }
        
        // Filter by game if specified
        if let game = game {
            relevantResults = relevantResults.filter { $0.gameId == game.id }
        }
        
        // Generate data points for each day in the range
        var currentDate = startDate
        while currentDate <= endDate {
            // Get results for this specific day
            let dayResults = relevantResults.filter { calendar.isDate($0.date, inSameDayAs: currentDate) }
            
            // Calculate active streaks as of this date
            // A streak is "active" if played today or yesterday (within last 2 days including today)
            // Day 1: Play game → Active on Day 1 and Day 2
            // Day 3: If no play on Day 2 → No longer active
            // IMPORTANT: Only consider results UP TO currentDate (not future results)
            let uniqueGamesPlayedInWindow = Set(relevantResults.filter { result in
                // Only look at results up to and including currentDate
                guard result.date <= currentDate else { return false }
                
                // Check if result is today (0) or yesterday (1)
                if let daysDiff = calendar.dateComponents([.day], from: result.date, to: currentDate).day {
                    return daysDiff >= 0 && daysDiff <= 1
                }
                return false
            }.map(\.gameId))
            
            let totalActiveStreaks = uniqueGamesPlayedInWindow.count
            
            // Calculate longest streak length as of this date
            // This would require reconstructing streak history, so we'll use a simplified version
            // Count consecutive days with at least one result per game up to this date
            var longestStreakLength = 0
            for gameId in uniqueGamesPlayedInWindow {
                let gameResults = relevantResults.filter { $0.gameId == gameId && $0.date <= currentDate }
                    .sorted { $0.date > $1.date }
                
                var currentStreakLength = 0
                var checkDate = currentDate
                
                for _ in 0..<30 { // Check up to 30 days back
                    if gameResults.contains(where: { calendar.isDate($0.date, inSameDayAs: checkDate) }) {
                        currentStreakLength += 1
                        guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                        checkDate = previousDay
                    } else {
                        break
                    }
                }
                
                longestStreakLength = max(longestStreakLength, currentStreakLength)
            }
            
            let gamesPlayed = dayResults.count
            let gamesCompleted = dayResults.filter(\.completed).count
            
            let trendPoint = StreakTrendPoint(
                date: currentDate,
                totalActiveStreaks: totalActiveStreaks,
                longestStreak: longestStreakLength,
                gamesPlayed: gamesPlayed,
                gamesCompleted: gamesCompleted
            )
            
            trends.append(trendPoint)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return trends
    }
    
    private func calculateGameAnalytics(for timeRange: AnalyticsTimeRange) async -> [GameAnalytics] {
        return await withTaskGroup(of: GameAnalytics?.self) { group in
            for game in appState.games {
                group.addTask {
                    await self.getGameAnalytics(for: game.id, timeRange: timeRange)
                }
            }
            
            var results: [GameAnalytics] = []
            for await result in group {
                if let gameAnalytics = result {
                    results.append(gameAnalytics)
                }
            }
            return results
        }
    }
    
    private func calculateAchievementAnalytics() async -> AchievementAnalytics {
        // TODO: Implement when achievement system is fully integrated
        return AchievementAnalytics()
    }
    
    private func calculatePersonalBests() async -> [PersonalBest] {
        var personalBests: [PersonalBest] = []
        
        // Longest streak per game - get top 2 games
        let topStreaks = appState.streaks
            .sorted { $0.maxStreak > $1.maxStreak }
            .prefix(2)
        
        for streak in topStreaks where streak.maxStreak > 0 {
            if let game = appState.games.first(where: { $0.id == streak.gameId }) {
                let personalBest = PersonalBest(
                    type: .longestStreak,
                    value: streak.maxStreak,
                    game: game,
                    date: streak.streakStartDate ?? Date(),
                    description: "\(streak.maxStreak) day streak in \(game.displayName)"
                )
                personalBests.append(personalBest)
            }
        }
        
        // Best score per game - get top 2 games with best scores
        // Group results by game and find best score for each
        let gameGroups = Dictionary(grouping: appState.recentResults.filter(\.completed)) { $0.gameId }
        
        var gameBestScores: [(gameId: UUID, score: Int, result: GameResult)] = []
        for (gameId, results) in gameGroups {
            if let bestResult = results.min(by: { ($0.score ?? 999) < ($1.score ?? 999) }),
               let score = bestResult.score {
                gameBestScores.append((gameId: gameId, score: score, result: bestResult))
            }
        }
        
        // Sort by score (lower is better for most word games) and take top 2
        let topScores = gameBestScores
            .sorted { $0.score < $1.score }
            .prefix(2)
        
        for (gameId, score, result) in topScores {
            if let game = appState.games.first(where: { $0.id == gameId }) {
                let personalBest = PersonalBest(
                    type: .bestScore,
                    value: score,
                    game: game,
                    date: result.date,
                    description: "\(result.displayScore) in \(game.displayName)"
                )
                personalBests.append(personalBest)
            }
        }
        
        // Most games in a day (optional - only if significant)
        let gamesByDay = Dictionary(grouping: appState.recentResults) { result in
            Calendar.current.startOfDay(for: result.date)
        }
        
        if let mostGamesDay = gamesByDay.max(by: { $0.value.count < $1.value.count }),
           mostGamesDay.value.count > 1 { // Only show if more than 1 game in a day
            let personalBest = PersonalBest(
                type: .mostGamesInDay,
                value: mostGamesDay.value.count,
                game: nil,
                date: mostGamesDay.key,
                description: "\(mostGamesDay.value.count) games played in one day"
            )
            personalBests.append(personalBest)
        }
        
        return personalBests
    }
    
    private func calculateWeeklySummaries(for timeRange: AnalyticsTimeRange) async -> [WeeklySummary] {
        // TODO: Implement weekly summaries
        return []
    }
    
    // MARK: - Helper Methods
    
    private func getGameResults(for gameId: UUID, in timeRange: AnalyticsTimeRange) -> [GameResult] {
        let (startDate, endDate) = timeRange.dateRange
        return appState.recentResults
            .filter { $0.gameId == gameId }
            .filter { $0.date >= startDate && $0.date <= endDate }
            .sorted { $0.date > $1.date }
    }
    
    private func calculateGameTrendData(for gameId: UUID, in timeRange: AnalyticsTimeRange) async -> [StreakTrendPoint] {
        let (startDate, endDate) = timeRange.dateRange
        let calendar = Calendar.current
        var trends: [StreakTrendPoint] = []
        
        var currentDate = startDate
        while currentDate <= endDate {
            let dayResults = appState.recentResults.filter { 
                $0.gameId == gameId && calendar.isDate($0.date, inSameDayAs: currentDate)
            }
            
            let trendPoint = StreakTrendPoint(
                date: currentDate,
                totalActiveStreaks: dayResults.isEmpty ? 0 : 1,
                longestStreak: 0,
                gamesPlayed: dayResults.count,
                gamesCompleted: dayResults.filter(\.completed).count
            )
            
            trends.append(trendPoint)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return trends
    }
    
    private func calculatePersonalBest(for gameId: UUID) -> Int {
        return appState.recentResults
            .filter { $0.gameId == gameId && $0.completed }
            .compactMap(\.score)
            .min() ?? 0
    }
    
    private func calculateAverageScore(for gameId: UUID, in timeRange: AnalyticsTimeRange) -> Double {
        let results = getGameResults(for: gameId, in: timeRange)
            .filter(\.completed)
            .compactMap(\.score)
        
        guard !results.isEmpty else { return 0.0 }
        return Double(results.reduce(0, +)) / Double(results.count)
    }
    
    private func calculateStreakConsistency(for timeRange: AnalyticsTimeRange, game: Game? = nil) -> Double {
        let calendar = Calendar.current
        let (startDate, endDate) = timeRange.dateRange
        
        var timeRangeResults = appState.recentResults.filter { result in
            result.date >= startDate && result.date <= endDate
        }
        
        // Filter by game if specified
        if let game = game {
            timeRangeResults = timeRangeResults.filter { $0.gameId == game.id }
        }
        
        let daysWithActivity = Set(timeRangeResults.map { calendar.startOfDay(for: $0.date) }).count
        let totalDays = timeRange.days
        
        return Double(daysWithActivity) / Double(totalDays)
    }
    
    func getConsistencyDays(for timeRange: AnalyticsTimeRange, game: Game? = nil) -> (active: Int, total: Int) {
        let calendar = Calendar.current
        let (startDate, endDate) = timeRange.dateRange
        
        var timeRangeResults = appState.recentResults.filter { result in
            result.date >= startDate && result.date <= endDate
        }
        
        // Filter by game if specified
        if let game = game {
            timeRangeResults = timeRangeResults.filter { $0.gameId == game.id }
        }
        
        let daysWithActivity = Set(timeRangeResults.map { calendar.startOfDay(for: $0.date) }).count
        
        return (active: daysWithActivity, total: timeRange.days)
    }
}
