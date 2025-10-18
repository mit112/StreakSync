//
//  AnalyticsViewModel.swift
//  StreakSync
//
//  Analytics view model for state management and business logic
//

/*
 * ANALYTICSVIEWMODEL - DATA INSIGHTS AND STATISTICS COORDINATOR
 * 
 * WHAT THIS FILE DOES:
 * This file is the "data analyst" of the app. It takes all the user's game results and turns
 * them into meaningful insights and statistics. Think of it as a "report generator" that
 * analyzes patterns in the user's gaming behavior and presents them in an easy-to-understand
 * way. It handles things like streak trends, personal bests, game performance, and achievement
 * progress to help users understand their gaming habits and improve their performance.
 * 
 * WHY IT EXISTS:
 * Users want to understand their progress and see how they're improving over time. This view
 * model processes raw game data and transforms it into actionable insights. It provides
 * different time ranges (week, month, year) and game-specific analytics to give users a
 * comprehensive view of their gaming performance. Without this, users would just see a list
 * of results without any meaningful analysis.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides the insights that make the app valuable beyond just tracking
 * - Transforms raw data into meaningful statistics and trends
 * - Supports multiple time ranges and game-specific analysis
 * - Handles complex calculations like streak trends and personal bests
 * - Provides data for charts and visualizations
 * - Manages loading states and error handling for analytics
 * - Persists user preferences for analytics scope and time ranges
 * 
 * WHAT IT REFERENCES:
 * - AnalyticsService: The core service that performs data analysis
 * - AppState: Access to all game data, results, and streaks
 * - AnalyticsData: The processed analytics results
 * - AnalyticsScope: User preferences for analytics view
 * - AnalyticsTimeRange: Time periods for analysis (week, month, year)
 * - Game: Individual games for game-specific analytics
 * 
 * WHAT REFERENCES IT:
 * - AnalyticsDashboardView: The main analytics screen that displays insights
 * - StreakTrendsDetailView: Detailed view of streak trends
 * - Analytics chart components: Use this for data visualization
 * - AppContainer: Creates and manages the AnalyticsViewModel
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. STATE MANAGEMENT IMPROVEMENTS:
 *    - The current state management is good but could be more sophisticated
 *    - Consider using a state machine for complex loading states
 *    - Add support for partial data loading and progressive updates
 *    - Implement proper state validation and error recovery
 * 
 * 2. PERFORMANCE OPTIMIZATIONS:
 *    - The current analytics loading could be optimized
 *    - Consider caching analytics results for better performance
 *    - Add background processing for heavy calculations
 *    - Implement incremental updates for large datasets
 * 
 * 3. DATA PROCESSING IMPROVEMENTS:
 *    - The current data processing is basic - could be more sophisticated
 *    - Add support for more complex statistical analysis
 *    - Implement machine learning for pattern recognition
 *    - Add support for predictive analytics
 * 
 * 4. USER EXPERIENCE IMPROVEMENTS:
 *    - The current loading states could be more informative
 *    - Add progress indicators for long-running operations
 *    - Implement smart defaults based on user behavior
 *    - Add support for custom time ranges
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for all analytics logic
 *    - Test different time ranges and data scenarios
 *    - Add performance tests for large datasets
 *    - Test error handling and edge cases
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for analytics calculations
 *    - Document the data flow and processing steps
 *    - Add examples of different analytics scenarios
 *    - Create analytics flow diagrams
 * 
 * 7. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new analytics types
 *    - Add support for custom analytics plugins
 *    - Implement analytics templates
 *    - Add support for user-defined analytics
 * 
 * 8. VISUALIZATION IMPROVEMENTS:
 *    - Add support for more chart types and visualizations
 *    - Implement interactive charts and drill-down capabilities
 *    - Add support for data export and sharing
 *    - Consider adding animated charts for better user experience
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - View models: Bridge between UI and business logic
 * - Analytics: The process of analyzing data to find insights
 * - State management: Keeping track of what the UI should show
 * - Async/await: Handling operations that take time to complete
 * - Data processing: Transforming raw data into useful information
 * - Time ranges: Different periods for analyzing data
 * - Loading states: Showing users when data is being processed
 * - Error handling: What to do when something goes wrong
 * - Computed properties: Values calculated from other data
 * - Published properties: Values that trigger UI updates when they change
 */

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
        return analyticsService.appState.games
    }
    
    var favoriteGames: [Game] {
        analyticsService.appState.favoriteGames
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
            self.selectedGame = analyticsService.appState.games.first { $0.id == gid }
        }
    }
    
    // MARK: - Public Methods
    
    /// Load analytics data for the current time range and selected game
    func loadAnalytics() async {
        await loadAnalytics(for: selectedTimeRange, game: selectedGame)
    }
    
    /// Load analytics data for a specific time range and game
    func loadAnalytics(for timeRange: AnalyticsTimeRange, game: Game? = nil) async {
        logger.info("📊 Loading analytics for \(timeRange.displayName) - \(game?.displayName ?? "All Games")")
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        let data = await analyticsService.getAnalyticsData(for: timeRange, game: game)
        
        await MainActor.run {
            self.analyticsData = data
            self.selectedTimeRange = timeRange
            self.isLoading = false
            
            // Don't auto-select games - let the user choose between "All Games" and specific games
        }
        // Persist scope
        await MainActor.run {
            self.scope.timeRange = timeRange
            self.scope.gameId = self.selectedGame?.id
            self.scope.save()
        }
        
        logger.info("✅ Analytics loaded successfully for \(timeRange.displayName) - \(game?.displayName ?? "All Games")")
    }
    
    /// Refresh analytics data
    func refreshAnalytics() async {
        logger.info("🔄 Refreshing analytics data for \(self.selectedGame?.displayName ?? "All Games")")
        analyticsService.clearCache()
        await loadAnalytics(for: selectedTimeRange, game: selectedGame)
    }
    
    /// Change time range and reload data
    func changeTimeRange(to timeRange: AnalyticsTimeRange) async {
        guard timeRange != selectedTimeRange else { return }
        
        logger.info("📅 Changing time range to \(timeRange.displayName) for \(self.selectedGame?.displayName ?? "All Games")")
        await loadAnalytics(for: timeRange, game: selectedGame)
    }
    
    /// Select a game for detailed analytics
    func selectGame(_ game: Game?) {
        guard game?.id != selectedGame?.id else { return }
        
        if let game = game {
            logger.info("🎮 Selecting game: \(game.displayName)")
        } else {
            logger.info("🎮 Selecting all games")
        }
        
        selectedGame = game
        analyticsService.clearCache()
        
        // Update analytics data for new selection
        Task {
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
    
    /// Get chart data for game performance
    func getGamePerformanceChartData() -> [GamePerformanceChartPoint] {
        guard let gameAnalytics = currentGameAnalytics else { return [] }
        
        return gameAnalytics.recentResults.map { result in
            let score = result.score ?? (result.maxAttempts + 1)
            return GamePerformanceChartPoint(
                date: result.date,
                value: Double(score),
                label: result.displayScore,
                gameName: result.gameName,
                score: result.score,
                completed: result.completed
            )
        }
    }
    
    /// Get completion rate trend data
    func getCompletionRateTrendData() -> [StreakTrendChartPoint] {
        return currentStreakTrends.map { trend in
            StreakTrendChartPoint(
                date: trend.date,
                value: trend.completionRate * 100, // Convert to percentage
                label: "Completion Rate",
                secondaryValue: Double(trend.gamesPlayed)
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
