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
final class AnalyticsService {
    
    // MARK: - Dependencies
    private let appState: AppState
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AnalyticsService")
    
    // MARK: - Public Accessors (avoid tunneling through appState)
    var games: [Game] { appState.games }
    var favoriteGames: [Game] { appState.favoriteGames }
    
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
        // Include data fingerprint in cache key so changes auto-invalidate
        let resultCount = appState.recentResults.count
        let lastResultDate = appState.recentResults.first?.date.timeIntervalSince1970 ?? 0
        let cacheKey = "\(timeRange.rawValue)_\(game?.id.uuidString ?? "all")_\(resultCount)_\(Int(lastResultDate))"
        
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
        
        // Compute all components concurrently off the main actor
        let analyticsData = await Self.computeAll(
            timeRange: timeRange,
            game: game,
            games: snapshotGames,
            streaks: snapshotStreaks,
            results: snapshotResults,
            tieredAchievements: snapshotTiered
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
        return AnalyticsComputer.computeAchievementAnalytics(tieredAchievements: tiered)
    }
    
    /// Get personal bests (scoped). Defaults to 7 days across all games.
    func getPersonalBests(for timeRange: AnalyticsTimeRange = .week, game: Game? = nil) async -> [PersonalBest] {
        return AnalyticsComputer.computePersonalBests(
            timeRange: timeRange,
            game: game,
            games: appState.games,
            streaks: appState.streaks,
            results: appState.recentResults
        )
    }
    
    /// Clear analytics cache
    func clearCache() {
        cachedAnalytics.removeAll()
        lastCacheUpdateByKey.removeAll()
        logger.info("🗑️ Analytics cache cleared")
    }
    
    // MARK: - Concurrent Computation (off main actor)
    
    /// Runs all analytics computations concurrently with structured concurrency.
    /// `nonisolated` so the work runs off the main actor while respecting cancellation.
    private nonisolated static func computeAll(
        timeRange: AnalyticsTimeRange,
        game: Game?,
        games: [Game],
        streaks: [GameStreak],
        results: [GameResult],
        tieredAchievements: [TieredAchievement]?
    ) async -> AnalyticsData {
        async let overview = AnalyticsComputer.computeOverview(
            timeRange: timeRange, game: game, games: games, streaks: streaks, results: results
        )
        async let streakTrends = AnalyticsComputer.computeStreakTrends(
            timeRange: timeRange, game: game, results: results
        )
        async let gameAnalytics = AnalyticsComputer.computeGameAnalytics(
            timeRange: timeRange, games: games, streaks: streaks, results: results
        )
        async let achievementAnalytics = AnalyticsComputer.computeAchievementAnalytics(
            tieredAchievements: tieredAchievements
        )
        async let personalBests = AnalyticsComputer.computePersonalBests(
            timeRange: timeRange, game: game, games: games, streaks: streaks, results: results
        )
        async let weeklySummaries = AnalyticsComputer.computeWeeklySummaries(
            timeRange: timeRange, games: games, results: results, streaks: streaks
        )
        
        return await AnalyticsData(
            overview: overview,
            streakTrends: streakTrends,
            gameAnalytics: gameAnalytics,
            achievementAnalytics: achievementAnalytics,
            personalBests: personalBests,
            weeklySummaries: weeklySummaries,
            timeRange: timeRange
        )
    }
    
    // MARK: - Helper Methods (keep public helper that relies on snapshots internally)
    
    func getConsistencyDays(for timeRange: AnalyticsTimeRange, game: Game? = nil) -> (active: Int, total: Int) {
        let snapshotResults = appState.recentResults
        return AnalyticsComputer.computeConsistencyDays(timeRange: timeRange, game: game, results: snapshotResults)
    }
}
