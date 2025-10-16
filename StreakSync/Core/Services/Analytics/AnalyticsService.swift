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
    // Track freshness per cache key to avoid cross-key staleness
    private var lastCacheUpdateByKey: [String: Date] = [:]
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    init(appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Public Methods
    
    /// Get comprehensive analytics data for a specific time range and optional game
    func getAnalyticsData(for timeRange: AnalyticsTimeRange, game: Game? = nil) async -> AnalyticsData {
        let cacheKey = "\(timeRange.rawValue)_\(game?.id.uuidString ?? "all")"
        
        // Check cache first (per-key freshness)
        if let cached = cachedAnalytics[cacheKey],
           let lastUpdate = lastCacheUpdateByKey[cacheKey],
           Date().timeIntervalSince(lastUpdate) < cacheValidityDuration {
            logger.info("📊 Returning cached analytics for \(timeRange.displayName) - \(game?.displayName ?? "All Games")")
            return cached
        }
        
        logger.info("📊 Calculating analytics for \(timeRange.displayName) - \(game?.displayName ?? "All Games")")
        
        // Snapshot state once to avoid racing AppState during background compute
        let snapshotGames = appState.games
        let snapshotStreaks = appState.streaks
        let snapshotResults = appState.recentResults
        let snapshotTiered = appState.tieredAchievements
        
        // Compute components concurrently off the main actor
        async let overviewTask: AnalyticsOverview = Task.detached(priority: .userInitiated) {
            AnalyticsComputer.computeOverview(
                timeRange: timeRange,
                game: game,
                games: snapshotGames,
                streaks: snapshotStreaks,
                results: snapshotResults
            )
        }.value
        
        async let streakTrendsTask: [StreakTrendPoint] = Task.detached(priority: .utility) {
            AnalyticsComputer.computeStreakTrends(
                timeRange: timeRange,
                game: game,
                results: snapshotResults
            )
        }.value
        
        async let gameAnalyticsTask: [GameAnalytics] = Task.detached(priority: .utility) {
            await AnalyticsComputer.computeGameAnalytics(
                timeRange: timeRange,
                games: snapshotGames,
                streaks: snapshotStreaks,
                results: snapshotResults
            )
        }.value
        
        async let achievementAnalyticsTask: AchievementAnalytics = Task.detached(priority: .background) {
            AnalyticsComputer.computeAchievementAnalytics(
                achievements: [],
                tieredAchievements: snapshotTiered
            )
        }.value
        
        async let personalBestsTask: [PersonalBest] = Task.detached(priority: .utility) {
            AnalyticsComputer.computePersonalBests(
                games: snapshotGames,
                streaks: snapshotStreaks,
                results: snapshotResults
            )
        }.value
        
        async let weeklySummariesTask: [WeeklySummary] = Task.detached(priority: .utility) {
            AnalyticsComputer.computeWeeklySummaries(
                timeRange: timeRange,
                games: snapshotGames,
                results: snapshotResults,
                streaks: snapshotStreaks
            )
        }.value
        
        let overview = await overviewTask
        let streakTrends = await streakTrendsTask
        let gameAnalytics = await gameAnalyticsTask
        let achievementAnalytics = await achievementAnalyticsTask
        let personalBests = await personalBestsTask
        let weeklySummaries = await weeklySummariesTask
        
        let analyticsData = AnalyticsData(
            overview: overview,
            streakTrends: streakTrends,
            gameAnalytics: gameAnalytics,
            achievementAnalytics: achievementAnalytics,
            personalBests: personalBests,
            weeklySummaries: weeklySummaries,
            timeRange: timeRange
        )
        
        // Cache the result (per-key)
        cachedAnalytics[cacheKey] = analyticsData
        lastCacheUpdateByKey[cacheKey] = Date()
        
        logger.info("✅ Analytics calculation complete for \(timeRange.displayName) - \(game?.displayName ?? "All Games")")
        return analyticsData
    }
    
    /// Get streak trends for a specific time range
    func getStreakTrends(for timeRange: AnalyticsTimeRange) async -> [StreakTrendPoint] {
        let snapshotResults = appState.recentResults
        return AnalyticsComputer.computeStreakTrends(timeRange: timeRange, results: snapshotResults)
    }
    
    /// Get analytics for a specific game
    func getGameAnalytics(for gameId: UUID, timeRange: AnalyticsTimeRange = .week) async -> GameAnalytics? {
        let games = appState.games
        let streaks = appState.streaks
        let results = appState.recentResults
        return AnalyticsComputer.computeGameAnalytics(for: gameId, timeRange: timeRange, games: games, streaks: streaks, results: results)
    }
    
    /// Get achievement analytics (tiered-only)
    func getAchievementAnalytics() async -> AchievementAnalytics {
        let tiered = appState.tieredAchievements
        return AnalyticsComputer.computeAchievementAnalytics(achievements: [], tieredAchievements: tiered)
    }
    
    /// Get personal bests
    func getPersonalBests() async -> [PersonalBest] {
        return AnalyticsComputer.computePersonalBests(games: appState.games, streaks: appState.streaks, results: appState.recentResults)
    }
    
    /// Clear analytics cache
    func clearCache() {
        cachedAnalytics.removeAll()
        lastCacheUpdateByKey.removeAll()
        logger.info("🗑️ Analytics cache cleared")
    }
    
    // MARK: - Helper Methods (keep public helper that relies on snapshots internally)
    
    func getConsistencyDays(for timeRange: AnalyticsTimeRange, game: Game? = nil) -> (active: Int, total: Int) {
        let snapshotResults = appState.recentResults
        return AnalyticsComputer.computeConsistencyDays(timeRange: timeRange, game: game, results: snapshotResults)
    }
}

// MARK: - Pure computation helpers (off-main)
private struct AnalyticsComputer {
    static func computeOverview(timeRange: AnalyticsTimeRange, game: Game?, games: [Game], streaks: [GameStreak], results: [GameResult]) -> AnalyticsOverview {
        // Filter streaks by game if specified
        let relevantStreaks = game != nil ? streaks.filter { $0.gameId == game!.id } : streaks
        let activeStreaks = relevantStreaks.filter { $0.isActive }
        let totalActiveStreaks = activeStreaks.count
        let longestCurrentStreak = relevantStreaks.map { $0.maxStreak }.max() ?? 0
        
        // Time range results (optionally filtered by game)
        let (startDate, endDate) = timeRange.dateRange
        var timeRangeResults = results.filter { $0.date >= startDate && $0.date <= endDate }
        if let game = game { timeRangeResults = timeRangeResults.filter { $0.gameId == game.id } }
        
        let totalGamesPlayed = timeRangeResults.count
        let totalGamesCompleted = timeRangeResults.filter { $0.completed }.count
        let averageCompletionRate = totalGamesPlayed > 0 ? Double(totalGamesCompleted) / Double(totalGamesPlayed) : 0.0
        let streakConsistency = computeStreakConsistency(timeRange: timeRange, game: game, results: results)
        
        let mostPlayedGame: Game?
        if game == nil {
            let gamePlayCounts = Dictionary(grouping: timeRangeResults, by: { $0.gameId }).mapValues { $0.count }
            mostPlayedGame = gamePlayCounts.max(by: { $0.value < $1.value }).flatMap { (gid, _) in games.first { $0.id == gid } }
        } else {
            mostPlayedGame = game
        }
        
        let recentActivity = timeRangeResults.sorted { $0.date > $1.date }
        
        return AnalyticsOverview(
            totalActiveStreaks: totalActiveStreaks,
            longestCurrentStreak: longestCurrentStreak,
            totalGamesPlayed: totalGamesPlayed,
            totalGamesCompleted: totalGamesCompleted,
            totalAchievementsUnlocked: 0,
            averageCompletionRate: averageCompletionRate,
            streakConsistency: streakConsistency,
            mostPlayedGame: mostPlayedGame,
            recentActivity: recentActivity
        )
    }
    
    static func computeStreakTrends(timeRange: AnalyticsTimeRange, game: Game? = nil, results: [GameResult]) -> [StreakTrendPoint] {
        let (startDate, endDate) = timeRange.dateRange
        let calendar = Calendar.current
        var trends: [StreakTrendPoint] = []
        var relevantResults = results.filter { $0.date >= startDate && $0.date <= endDate }
        if let game = game { relevantResults = relevantResults.filter { $0.gameId == game.id } }
        
        var currentDate = startDate
        while currentDate <= endDate {
            let dayResults = relevantResults.filter { calendar.isDate($0.date, inSameDayAs: currentDate) }
            // Simple active streak definition: played in last 2 days
            let uniqueGamesPlayedInWindow = Set(relevantResults.filter { r in
                guard r.date <= currentDate else { return false }
                if let daysDiff = calendar.dateComponents([.day], from: r.date, to: currentDate).day { return daysDiff >= 0 && daysDiff <= 1 }
                return false
            }.map { $0.gameId })
            let totalActiveStreaks = uniqueGamesPlayedInWindow.count
            
            var longestStreakLength = 0
            for gid in uniqueGamesPlayedInWindow {
                let gameResults = relevantResults.filter { $0.gameId == gid && $0.date <= currentDate }.sorted { $0.date > $1.date }
                var currentStreakLength = 0
                var checkDate = currentDate
                for _ in 0..<30 {
                    if gameResults.contains(where: { calendar.isDate($0.date, inSameDayAs: checkDate) }) {
                        currentStreakLength += 1
                        guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                        checkDate = previousDay
                    } else { break }
                }
                longestStreakLength = max(longestStreakLength, currentStreakLength)
            }
            let gamesPlayed = dayResults.count
            let gamesCompleted = dayResults.filter { $0.completed }.count
            let trendPoint = StreakTrendPoint(date: currentDate, totalActiveStreaks: totalActiveStreaks, longestStreak: longestStreakLength, gamesPlayed: gamesPlayed, gamesCompleted: gamesCompleted)
            trends.append(trendPoint)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        return trends
    }
    
    static func computeGameAnalytics(timeRange: AnalyticsTimeRange, games: [Game], streaks: [GameStreak], results: [GameResult]) async -> [GameAnalytics] {
        return await withTaskGroup(of: GameAnalytics?.self) { group in
            for game in games {
                group.addTask {
                    computeGameAnalytics(for: game.id, timeRange: timeRange, games: games, streaks: streaks, results: results)
                }
            }
            var out: [GameAnalytics] = []
            for await item in group { if let item { out.append(item) } }
            return out
        }
    }
    
    static func computeGameAnalytics(for gameId: UUID, timeRange: AnalyticsTimeRange, games: [Game], streaks: [GameStreak], results: [GameResult]) -> GameAnalytics? {
        guard let game = games.first(where: { $0.id == gameId }) else { return nil }
        let streak = streaks.first(where: { $0.gameId == game.id })
        let recentResults = getGameResults(for: gameId, in: timeRange, results: results)
        let trendData = computeGameTrendData(for: gameId, in: timeRange, results: results)
        let personalBest = computePersonalBest(for: gameId, results: results)
        let averageScore = computeAverageScore(for: gameId, in: timeRange, results: results)
        return GameAnalytics(game: game, streak: streak, recentResults: recentResults, trendData: trendData, personalBest: personalBest, averageScore: averageScore)
    }
    
    static func computeAchievementAnalytics(achievements: [Achievement], tieredAchievements: [TieredAchievement]?) -> AchievementAnalytics {
        // For tiered-only mode, the legacy `achievements` array will be empty.
        let unlocked = achievements.filter { $0.isUnlocked }
        var tierDistribution: [AchievementTier: Int] = [:]
        var recentUnlocks: [AchievementUnlock] = []
        var categoryProgress: [AchievementCategory: Double] = [:]
        var nextActions: [String] = []
        
        if let tiered = tieredAchievements {
            for t in tiered {
                if let tier = t.progress.currentTier { tierDistribution[tier, default: 0] += 1 }
                // Collect unlock events from tier dates
                for (tier, date) in t.progress.tierUnlockDates {
                    recentUnlocks.append(AchievementUnlock(achievement: t, tier: tier, timestamp: date))
                }
            }
            // Category progress: percent of achievements with any tier unlocked
            let grouped = Dictionary(grouping: tiered, by: { $0.category })
            for (category, items) in grouped {
                let unlockedCount = items.filter { $0.progress.currentTier != nil }.count
                categoryProgress[category] = items.isEmpty ? 0.0 : Double(unlockedCount) / Double(items.count)
            }
            // Compute next actions (ETA-style hints) by finding nearest thresholds
            // Heuristic: take 3 closest next tiers across categories
            var candidates: [(name: String, remaining: Int)] = []
            for t in tiered {
                if let next = t.nextTierRequirement {
                    let remaining = max(0, next.threshold - t.progress.currentValue)
                    candidates.append((name: t.displayName, remaining: remaining))
                }
            }
            candidates.sort { $0.remaining < $1.remaining }
            nextActions = Array(candidates.prefix(3)).map { "Play toward \($0.name): \($0.remaining) to next tier" }
        }
        
        // Sort recent unlocks (desc) and limit to 5 for dashboard
        recentUnlocks.sort { $0.timestamp > $1.timestamp }
        recentUnlocks = Array(recentUnlocks.prefix(5))
        
        let analytics = AchievementAnalytics(
            totalUnlocked: unlocked.count,
            totalAvailable: achievements.count,
            recentUnlocks: recentUnlocks,
            categoryProgress: categoryProgress,
            tierDistribution: tierDistribution,
            nextActions: nextActions
        )
        return analytics
    }
    
    static func computePersonalBests(games: [Game], streaks: [GameStreak], results: [GameResult]) -> [PersonalBest] {
        var personalBests: [PersonalBest] = []
        let topStreaks = streaks.sorted { $0.maxStreak > $1.maxStreak }.prefix(2)
        for streak in topStreaks where streak.maxStreak > 0 {
            if let game = games.first(where: { $0.id == streak.gameId }) {
                personalBests.append(PersonalBest(type: .longestStreak, value: streak.maxStreak, game: game, date: streak.streakStartDate ?? Date(), description: "\(streak.maxStreak) day streak in \(game.displayName)"))
            }
        }
        // Best score per game (lower better)
        let grouped = Dictionary(grouping: results.filter { $0.completed }.compactMap { ($0.gameId, $0) }) { $0.0 }
        var bests: [(UUID, Int, GameResult)] = []
        for (gid, tuples) in grouped {
            let rs = tuples.map { $0.1 }
            if let best = rs.min(by: { ($0.score ?? Int.max) < ($1.score ?? Int.max) }), let s = best.score { bests.append((gid, s, best)) }
        }
        for (gid, score, result) in bests.sorted(by: { $0.1 < $1.1 }).prefix(2) {
            if let game = games.first(where: { $0.id == gid }) {
                personalBests.append(PersonalBest(type: .bestScore, value: score, game: game, date: result.date, description: "\(result.displayScore) in \(game.displayName)"))
            }
        }
        // Most games in a day (meaningful if > 1)
        let byDay = Dictionary(grouping: results) { Calendar.current.startOfDay(for: $0.date) }
        if let most = byDay.max(by: { $0.value.count < $1.value.count }), most.value.count > 1 {
            personalBests.append(PersonalBest(type: .mostGamesInDay, value: most.value.count, game: nil, date: most.key, description: "\(most.value.count) games played in one day"))
        }
        return personalBests
    }
    
    static func computeWeeklySummaries(timeRange: AnalyticsTimeRange, games: [Game], results: [GameResult], streaks: [GameStreak]) -> [WeeklySummary] {
        // Group by ISO week within time range
        let (startDate, endDate) = timeRange.dateRange
        let calendar = Calendar.current
        let filtered = results.filter { $0.date >= startDate && $0.date <= endDate }
        let groups = Dictionary(grouping: filtered) { result -> Date in
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: result.date)
            return calendar.date(from: comps) ?? calendar.startOfDay(for: result.date)
        }
        var summaries: [WeeklySummary] = []
        for (weekStart, weekResults) in groups {
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let totalPlayed = weekResults.count
            let totalCompleted = weekResults.filter { $0.completed }.count
            // Average streak length (approx): average of current streaks at end of week
            let avgStreak = streaks.isEmpty ? 0.0 : Double(streaks.map { $0.currentStreak }.reduce(0, +)) / Double(streaks.count)
            // Longest streak all-time
            let longest = streaks.map { $0.maxStreak }.max() ?? 0
            let mostPlayedGameId = Dictionary(grouping: weekResults, by: { $0.gameId }).mapValues { $0.count }.max(by: { $0.value < $1.value })?.key
            let mostPlayedGame = mostPlayedGameId.flatMap { gid in games.first { $0.id == gid } }
            let completionRate = totalPlayed > 0 ? Double(totalCompleted) / Double(totalPlayed) : 0.0
            // Consistency: days with at least one result this week divided by 7
            let daysWithActivity = Set(weekResults.map { calendar.startOfDay(for: $0.date) }).count
            let consistency = Double(daysWithActivity) / 7.0
            summaries.append(WeeklySummary(weekStart: weekStart, weekEnd: weekEnd, totalGamesPlayed: totalPlayed, totalGamesCompleted: totalCompleted, averageStreakLength: avgStreak, longestStreak: longest, achievementsUnlocked: 0, mostPlayedGame: mostPlayedGame, completionRate: completionRate, streakConsistency: consistency))
        }
        return summaries.sorted { $0.weekStart > $1.weekStart }
    }
    
    static func getGameResults(for gameId: UUID, in timeRange: AnalyticsTimeRange, results: [GameResult]) -> [GameResult] {
        let (startDate, endDate) = timeRange.dateRange
        return results.filter { $0.gameId == gameId && $0.date >= startDate && $0.date <= endDate }.sorted { $0.date > $1.date }
    }
    
    static func computeGameTrendData(for gameId: UUID, in timeRange: AnalyticsTimeRange, results: [GameResult]) -> [StreakTrendPoint] {
        let (startDate, endDate) = timeRange.dateRange
        let calendar = Calendar.current
        var trends: [StreakTrendPoint] = []
        var currentDate = startDate
        while currentDate <= endDate {
            let dayResults = results.filter { $0.gameId == gameId && calendar.isDate($0.date, inSameDayAs: currentDate) }
            let trendPoint = StreakTrendPoint(date: currentDate, totalActiveStreaks: dayResults.isEmpty ? 0 : 1, longestStreak: 0, gamesPlayed: dayResults.count, gamesCompleted: dayResults.filter { $0.completed }.count)
            trends.append(trendPoint)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        return trends
    }
    
    static func computePersonalBest(for gameId: UUID, results: [GameResult]) -> Int {
        return results.filter { $0.gameId == gameId && $0.completed }.compactMap { $0.score }.min() ?? 0
    }
    
    static func computeAverageScore(for gameId: UUID, in timeRange: AnalyticsTimeRange, results: [GameResult]) -> Double {
        let rs = getGameResults(for: gameId, in: timeRange, results: results).filter { $0.completed }.compactMap { $0.score }
        guard !rs.isEmpty else { return 0.0 }
        return Double(rs.reduce(0, +)) / Double(rs.count)
    }
    
    static func computeStreakConsistency(timeRange: AnalyticsTimeRange, game: Game?, results: [GameResult]) -> Double {
        let (startDate, endDate) = timeRange.dateRange
        let calendar = Calendar.current
        var filtered = results.filter { $0.date >= startDate && $0.date <= endDate }
        if let game = game { filtered = filtered.filter { $0.gameId == game.id } }
        let daysWithActivity = Set(filtered.map { calendar.startOfDay(for: $0.date) }).count
        return Double(daysWithActivity) / Double(timeRange.days)
    }
    
    static func computeConsistencyDays(timeRange: AnalyticsTimeRange, game: Game?, results: [GameResult]) -> (active: Int, total: Int) {
        let (startDate, endDate) = timeRange.dateRange
        let calendar = Calendar.current
        var filtered = results.filter { $0.date >= startDate && $0.date <= endDate }
        if let game = game { filtered = filtered.filter { $0.gameId == game.id } }
        let daysWithActivity = Set(filtered.map { calendar.startOfDay(for: $0.date) }).count
        return (active: daysWithActivity, total: timeRange.days)
    }
}
