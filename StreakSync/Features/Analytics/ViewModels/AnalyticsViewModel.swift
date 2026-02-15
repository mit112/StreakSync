//
//  AnalyticsViewModel.swift
//  StreakSync
//
//  Analytics view model for state management and business logic
//

import Foundation
import SwiftUI
import OSLog

// MARK: - Analytics View Model
@MainActor
final class AnalyticsViewModel: ObservableObject {
    
    // MARK: - Dependencies
    let analyticsService: AnalyticsService
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AnalyticsViewModel")
    
    // MARK: - Published Properties
    @Published var scope: AnalyticsScope = AnalyticsScope.loadSaved()
    @Published var selectedTimeRange: AnalyticsTimeRange = .week
    @Published var selectedGame: Game?
    @Published var analyticsData: AnalyticsData?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Task Management
    private var loadTask: Task<Void, Never>?
    
    
    // MARK: - Computed Properties
    var hasData: Bool {
        analyticsData != nil
    }
    
    var currentStreakTrends: [StreakTrendPoint] {
        analyticsData?.streakTrends ?? []
    }
    
    var currentGameAnalytics: GameAnalytics? {
        guard let selectedGame = selectedGame else { return nil }
        return analyticsData?.gameAnalytics.first { $0.game.id == selectedGame.id }
    }
    
    var availableGames: [Game] {
        // Get games from app state instead of waiting for analytics data
        return analyticsService.games
    }
    
    var favoriteGames: [Game] {
        analyticsService.favoriteGames
    }
    
    var personalBests: [PersonalBest] {
        analyticsData?.personalBests ?? []
    }
    
    var overview: AnalyticsOverview? {
        analyticsData?.overview
    }
    
    var achievementAnalytics: AchievementAnalytics? {
        analyticsData?.achievementAnalytics
    }
    
    // MARK: - Initialization
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
        // Seed from saved scope
        self.selectedTimeRange = scope.timeRange
        if let gid = scope.gameId {
            self.selectedGame = analyticsService.games.first { $0.id == gid }
        }
    }
    
    // MARK: - Public Methods
    
    /// Load analytics data for the current time range and selected game
    func loadAnalytics() async {
        await loadAnalytics(for: selectedTimeRange, game: selectedGame)
    }
    
    /// Load analytics data for a specific time range and game
    func loadAnalytics(for timeRange: AnalyticsTimeRange, game: Game? = nil) async {
 logger.info("Loading analytics for \(timeRange.displayName) - \(game?.displayName ?? "All Games")")
        
        isLoading = true
        errorMessage = nil
        
        let data = await analyticsService.getAnalyticsData(for: timeRange, game: game)
        
        // Check cancellation before updating UI
        guard !Task.isCancelled else { return }
        
        analyticsData = data
        selectedTimeRange = timeRange
        isLoading = false
        
        // Persist scope
        scope.timeRange = timeRange
        scope.gameId = selectedGame?.id
        scope.save()
        
 logger.info("Analytics loaded successfully for \(timeRange.displayName) - \(game?.displayName ?? "All Games")")
    }
    
    /// Refresh analytics data
    func refreshAnalytics() async {
 logger.info("Refreshing analytics data for \(self.selectedGame?.displayName ?? "All Games")")
        analyticsService.clearCache()
        await loadAnalytics(for: selectedTimeRange, game: selectedGame)
    }
    
    /// Change time range and reload data
    func changeTimeRange(to timeRange: AnalyticsTimeRange) async {
        guard timeRange != selectedTimeRange else { return }
        
 logger.info("Changing time range to \(timeRange.displayName) for \(self.selectedGame?.displayName ?? "All Games")")
        await loadAnalytics(for: timeRange, game: selectedGame)
    }
    
    /// Select a game for detailed analytics
    func selectGame(_ game: Game?) {
        guard game?.id != selectedGame?.id else { return }
        
        if let game = game {
 logger.info("Selecting game: \(game.displayName)")
        } else {
 logger.info("Selecting all games")
        }
        
        selectedGame = game
        analyticsService.clearCache()
        
        // Cancel any in-flight load, start new one
        loadTask?.cancel()
        loadTask = Task {
            await loadAnalytics(for: selectedTimeRange, game: game)
        }
    }
    
    /// Get chart data for streak trends
    func getStreakTrendChartData() -> [StreakTrendChartPoint] {
        return currentStreakTrends.map { trend in
            StreakTrendChartPoint(
                date: trend.date,
                value: Double(trend.totalActiveStreaks),
                label: "Active Streaks",
                secondaryValue: Double(trend.longestStreak)
            )
        }
    }
    
    /// Get game category distribution
    func getGameCategoryDistribution() -> [GameCategory: Int] {
        guard let data = analyticsData else { return [:] }
        
        var distribution: [GameCategory: Int] = [:]
        for gameAnalytics in data.gameAnalytics {
            let category = gameAnalytics.game.category
            distribution[category, default: 0] += gameAnalytics.totalGamesPlayed
        }
        
        return distribution
    }
    
    /// Get most active games (by total games played)
    func getMostActiveGames(limit: Int = 5) -> [GameAnalytics] {
        guard let data = analyticsData else { return [] }
        
        return data.gameAnalytics
            .sorted { $0.totalGamesPlayed > $1.totalGamesPlayed }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Get longest streaks
    func getLongestStreaks(limit: Int = 5) -> [GameAnalytics] {
        guard let data = analyticsData else { return [] }
        
        return data.gameAnalytics
            .sorted { $0.maxStreak > $1.maxStreak }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Get recent activity summary
    func getRecentActivitySummary() -> (totalGames: Int, completionRate: Double, activeStreaks: Int) {
        guard let overview = overview else { return (0, 0.0, 0) }
        
        return (
            totalGames: overview.totalGamesPlayed,
            completionRate: overview.averageCompletionRate,
            activeStreaks: overview.totalActiveStreaks
        )
    }
    
    /// Check if data is stale and needs refresh
    func shouldRefreshData() -> Bool {
        guard let lastUpdated = analyticsData?.lastUpdated else { return true }
        return Date().timeIntervalSince(lastUpdated) > 300 // 5 minutes
    }
    
    /// Get time range display name - isolated to only change when time range changes
    var timeRangeDisplayName: String {
        selectedTimeRange.displayName
    }
    
    /// Get selected game display name - isolated to only change when game changes
    var selectedGameDisplayName: String {
        selectedGame?.displayName ?? "All Games"
    }
    
    /// Get selected game ID for animation tracking - only changes when game changes
    var selectedGameId: UUID? {
        selectedGame?.id
    }
    
    /// Get time range for animation tracking - only changes when time range changes
    var timeRangeForAnimation: AnalyticsTimeRange {
        selectedTimeRange
    }
    
    /// Check if current selection has data
    var hasDataForCurrentSelection: Bool {
        guard let data = analyticsData else { return false }
        
        if selectedGame == nil {
            // For "All Games", check if there's any data
            return !data.overview.recentActivity.isEmpty || data.overview.totalGamesPlayed > 0
        } else {
            // For specific game, check if there's data for that game
            return data.gameAnalytics.contains { $0.game.id == selectedGame?.id }
        }
    }
    
    /// Get appropriate message for empty state
    var emptyStateMessage: String {
        if selectedGame == nil {
            return "No games played in the selected time range"
        } else {
            return "No data for \(selectedGame?.displayName ?? "this game") in the selected time range"
        }
    }

    // MARK: - Export
    func exportCSV() -> String {
        guard let data = analyticsData else { return "" }
        var rows: [String] = []
        rows.append("date,game,score,maxAttempts,completed")
        for ga in data.gameAnalytics {
            for r in ga.recentResults {
                let dateStr = ISO8601DateFormatter().string(from: r.date)
                let scoreStr = r.score.map { String($0) } ?? ""
                rows.append("\(dateStr),\(ga.game.displayName),\(scoreStr),\(r.maxAttempts),\(r.completed)")
            }
        }
        return rows.joined(separator: "\n")
    }
}

// MARK: - Analytics View Model Extensions

extension AnalyticsViewModel {
    
    /// Get formatted streak trend summary
    func getStreakTrendSummary() -> String {
        guard !currentStreakTrends.isEmpty else { return "No data available" }
        
        let latest = currentStreakTrends.last!
        let previous = currentStreakTrends.count > 1 ? currentStreakTrends[currentStreakTrends.count - 2] : latest
        
        let trend = latest.totalActiveStreaks - previous.totalActiveStreaks
        let trendText = trend > 0 ? "+\(trend)" : trend < 0 ? "\(trend)" : "No change"
        
        return "\(latest.totalActiveStreaks) active streaks (\(trendText))"
    }
    
    /// Get formatted completion rate summary
    func getCompletionRateSummary() -> String {
        guard let overview = overview else { return "No data available" }
        
        let rate = overview.averageCompletionRate * 100
        return String(format: "%.1f%% completion rate", rate)
    }
    
    /// Get formatted streak consistency summary
    func getStreakConsistencySummary() -> String {
        guard let overview = overview else { return "No data available" }
        
        let consistency = overview.streakConsistency * 100
        return String(format: "%.1f%% consistency", consistency)
    }
}
