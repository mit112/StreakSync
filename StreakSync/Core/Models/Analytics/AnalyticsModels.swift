//
//  AnalyticsModels.swift
//  StreakSync
//
//  Analytics data models for statistics and insights
//

import Foundation
import SwiftUI

// MARK: - Scope & Aggregation
struct AnalyticsScope: Codable, Equatable, Sendable {
    enum Aggregation: String, Codable, CaseIterable, Sendable {
        case daily
        case weekly
        
        var displayName: String {
            switch self {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            }
        }
    }
    
    var timeRange: AnalyticsTimeRange
    var gameId: UUID? // nil = All Games
    var aggregation: Aggregation
    
    init(timeRange: AnalyticsTimeRange = .week, gameId: UUID? = nil, aggregation: Aggregation = .daily) {
        self.timeRange = timeRange
        self.gameId = gameId
        self.aggregation = aggregation
    }
}

extension AnalyticsScope {
    static let userDefaultsKey = "analyticsScope.v1"
    
    static func loadSaved(defaults: UserDefaults = .standard) -> AnalyticsScope {
        if let data = defaults.data(forKey: Self.userDefaultsKey),
           let scope = try? JSONDecoder().decode(AnalyticsScope.self, from: data) {
            return scope
        }
        return AnalyticsScope()
    }
    
    func save(defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.userDefaultsKey)
        }
    }
}

// MARK: - Time Range Enum
enum AnalyticsTimeRange: String, CaseIterable, Sendable, Codable {
    case today = "today"
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    case year = "year"
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .week: return "7 Days"
        case .month: return "30 Days"
        case .quarter: return "90 Days"
        case .year: return "1 Year"
        }
    }
    
    var days: Int {
        switch self {
        case .today: return 1
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        let end = Date()
        let calendar = Calendar.current
        
        // For "today", use start of day to end of day
        if self == .today {
            let startOfDay = calendar.startOfDay(for: end)
            return (startOfDay, end)
        }
        
        let start = calendar.date(byAdding: .day, value: -days, to: end) ?? end
        return (start, end)
    }
}

// MARK: - Streak Trend Data Point
struct StreakTrendPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let totalActiveStreaks: Int
    let longestStreak: Int
    let gamesPlayed: Int
    let gamesCompleted: Int
    let completionRate: Double
    
    init(
        date: Date,
        totalActiveStreaks: Int = 0,
        longestStreak: Int = 0,
        gamesPlayed: Int = 0,
        gamesCompleted: Int = 0
    ) {
        self.date = date
        self.totalActiveStreaks = totalActiveStreaks
        self.longestStreak = longestStreak
        self.gamesPlayed = gamesPlayed
        self.gamesCompleted = gamesCompleted
        self.completionRate = gamesPlayed > 0 ? Double(gamesCompleted) / Double(gamesPlayed) : 0.0
    }
}

// MARK: - Game Analytics
struct GameAnalytics: Identifiable, Sendable {
    let id: UUID
    let game: Game
    let streak: GameStreak?
    let recentResults: [GameResult]
    let trendData: [StreakTrendPoint]
    let personalBest: Int
    let averageScore: Double
    let completionRate: Double
    let lastPlayedDate: Date?
    let streakStatus: StreakStatus
    
    init(
        game: Game,
        streak: GameStreak?,
        recentResults: [GameResult],
        trendData: [StreakTrendPoint] = [],
        personalBest: Int = 0,
        averageScore: Double = 0.0
    ) {
        self.id = game.id
        self.game = game
        self.streak = streak
        self.recentResults = recentResults
        self.trendData = trendData
        self.personalBest = personalBest
        self.averageScore = averageScore
        self.completionRate = streak?.completionRate ?? 0.0
        self.lastPlayedDate = streak?.lastPlayedDate
        self.streakStatus = streak?.isActive == true ? .active : .inactive
    }
    
    var isActive: Bool {
        streak?.isActive ?? false
    }
    
    var currentStreak: Int {
        streak?.currentStreak ?? 0
    }
    
    var maxStreak: Int {
        streak?.maxStreak ?? 0
    }
    
    var totalGamesPlayed: Int {
        streak?.totalGamesPlayed ?? 0
    }
}

// MARK: - Achievement Analytics
struct AchievementAnalytics: Sendable {
    let totalUnlocked: Int
    let totalAvailable: Int
    let recentUnlocks: [AchievementUnlock]
    let categoryProgress: [AchievementCategory: Double]
    let tierDistribution: [AchievementTier: Int]
    let unlockRate: Double
    
    init(
        totalUnlocked: Int = 0,
        totalAvailable: Int = 0,
        recentUnlocks: [AchievementUnlock] = [],
        categoryProgress: [AchievementCategory: Double] = [:],
        tierDistribution: [AchievementTier: Int] = [:]
    ) {
        self.totalUnlocked = totalUnlocked
        self.totalAvailable = totalAvailable
        self.recentUnlocks = recentUnlocks
        self.categoryProgress = categoryProgress
        self.tierDistribution = tierDistribution
        self.unlockRate = totalAvailable > 0 ? Double(totalUnlocked) / Double(totalAvailable) : 0.0
    }
    
    var completionPercentage: String {
        String(format: "%.1f%%", unlockRate * 100)
    }
}

// MARK: - Personal Best
struct PersonalBest: Identifiable, Sendable {
    let id = UUID()
    let type: PersonalBestType
    let value: Int
    let game: Game?
    let date: Date
    let description: String
    
    enum PersonalBestType: String, CaseIterable {
        case longestStreak = "longest_streak"
        case bestScore = "best_score"
        case mostGamesInDay = "most_games_day"
        case perfectWeek = "perfect_week"
        case fastestCompletion = "fastest_completion"
        
        var displayName: String {
            switch self {
            case .longestStreak: return "Longest Streak"
            case .bestScore: return "Best Score"
            case .mostGamesInDay: return "Most Games in a Day"
            case .perfectWeek: return "Perfect Week"
            case .fastestCompletion: return "Fastest Completion"
            }
        }
        
        var iconSystemName: String {
            switch self {
            case .longestStreak: return "flame.fill"
            case .bestScore: return "star.fill"
            case .mostGamesInDay: return "gamecontroller.fill"
            case .perfectWeek: return "calendar.badge.checkmark"
            case .fastestCompletion: return "timer"
            }
        }
    }
}

// MARK: - Weekly Summary
struct WeeklySummary: Sendable {
    let weekStart: Date
    let weekEnd: Date
    let totalGamesPlayed: Int
    let totalGamesCompleted: Int
    let averageStreakLength: Double
    let longestStreak: Int
    let achievementsUnlocked: Int
    let mostPlayedGame: Game?
    let completionRate: Double
    let streakConsistency: Double // Percentage of days with at least one game played
    
    init(
        weekStart: Date,
        weekEnd: Date,
        totalGamesPlayed: Int = 0,
        totalGamesCompleted: Int = 0,
        averageStreakLength: Double = 0.0,
        longestStreak: Int = 0,
        achievementsUnlocked: Int = 0,
        mostPlayedGame: Game? = nil,
        completionRate: Double = 0.0,
        streakConsistency: Double = 0.0
    ) {
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.totalGamesPlayed = totalGamesPlayed
        self.totalGamesCompleted = totalGamesCompleted
        self.averageStreakLength = averageStreakLength
        self.longestStreak = longestStreak
        self.achievementsUnlocked = achievementsUnlocked
        self.mostPlayedGame = mostPlayedGame
        self.completionRate = completionRate
        self.streakConsistency = streakConsistency
    }
    
    var weekDisplayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
    }
}

// MARK: - Analytics Overview
struct AnalyticsOverview: Sendable {
    let totalActiveStreaks: Int
    let longestCurrentStreak: Int
    let totalGamesPlayed: Int
    let totalGamesCompleted: Int
    let totalAchievementsUnlocked: Int
    let averageCompletionRate: Double
    let streakConsistency: Double
    let mostPlayedGame: Game?
    let recentActivity: [GameResult]
    
    init(
        totalActiveStreaks: Int = 0,
        longestCurrentStreak: Int = 0,
        totalGamesPlayed: Int = 0,
        totalGamesCompleted: Int = 0,
        totalAchievementsUnlocked: Int = 0,
        averageCompletionRate: Double = 0.0,
        streakConsistency: Double = 0.0,
        mostPlayedGame: Game? = nil,
        recentActivity: [GameResult] = []
    ) {
        self.totalActiveStreaks = totalActiveStreaks
        self.longestCurrentStreak = longestCurrentStreak
        self.totalGamesPlayed = totalGamesPlayed
        self.totalGamesCompleted = totalGamesCompleted
        self.totalAchievementsUnlocked = totalAchievementsUnlocked
        self.averageCompletionRate = averageCompletionRate
        self.streakConsistency = streakConsistency
        self.mostPlayedGame = mostPlayedGame
        self.recentActivity = recentActivity
    }
    
    var overallCompletionRate: String {
        String(format: "%.1f%%", averageCompletionRate * 100)
    }
    
    var streakConsistencyPercentage: String {
        String(format: "%.1f%%", streakConsistency * 100)
    }
}

// MARK: - Analytics Data Container
struct AnalyticsData: Sendable {
    let overview: AnalyticsOverview
    let streakTrends: [StreakTrendPoint]
    let gameAnalytics: [GameAnalytics]
    let achievementAnalytics: AchievementAnalytics
    let personalBests: [PersonalBest]
    let weeklySummaries: [WeeklySummary]
    let timeRange: AnalyticsTimeRange
    let lastUpdated: Date
    
    init(
        overview: AnalyticsOverview,
        streakTrends: [StreakTrendPoint] = [],
        gameAnalytics: [GameAnalytics] = [],
        achievementAnalytics: AchievementAnalytics = AchievementAnalytics(),
        personalBests: [PersonalBest] = [],
        weeklySummaries: [WeeklySummary] = [],
        timeRange: AnalyticsTimeRange = .week
    ) {
        self.overview = overview
        self.streakTrends = streakTrends
        self.gameAnalytics = gameAnalytics
        self.achievementAnalytics = achievementAnalytics
        self.personalBests = personalBests
        self.weeklySummaries = weeklySummaries
        self.timeRange = timeRange
        self.lastUpdated = Date()
    }
}

// MARK: - Chart Data Point Protocol
protocol ChartDataPoint: Identifiable, Sendable {
    var date: Date { get }
    var value: Double { get }
    var label: String { get }
}

// MARK: - Streak Trend Chart Data Point
struct StreakTrendChartPoint: ChartDataPoint {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String
    let secondaryValue: Double?
    
    init(date: Date, value: Double, label: String, secondaryValue: Double? = nil) {
        self.date = date
        self.value = value
        self.label = label
        self.secondaryValue = secondaryValue
    }
}

// MARK: - Game Performance Chart Data Point
struct GamePerformanceChartPoint: ChartDataPoint {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String
    let gameName: String
    let score: Int?
    let completed: Bool
    
    init(date: Date, value: Double, label: String, gameName: String, score: Int? = nil, completed: Bool = false) {
        self.date = date
        self.value = value
        self.label = label
        self.gameName = gameName
        self.score = score
        self.completed = completed
    }
}
