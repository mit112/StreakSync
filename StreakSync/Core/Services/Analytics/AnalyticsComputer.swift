//
//  AnalyticsComputer.swift
//  StreakSync
//
//  Pure computation helpers for analytics — all static, no state, runs off main actor.
//

import Foundation

// MARK: - Pure computation helpers (off-main)
struct AnalyticsComputer {
    static func computeOverview(timeRange: AnalyticsTimeRange, game: Game?, games: [Game], streaks: [GameStreak], results: [GameResult]) -> AnalyticsOverview {
        // Filter streaks by game if specified
        let relevantStreaks = game != nil ? streaks.filter { $0.gameId == game!.id } : streaks
        let activeStreaks = relevantStreaks.filter { $0.isActive }
        let totalActiveStreaks = activeStreaks.count
        // Longest streak should respect the selected time range
        let (startDate, endDate) = timeRange.dateRange
        let longestCurrentStreak = longestStreakInRange(startDate: startDate, endDate: endDate, gameId: game?.id, results: results)
        
        // Time range results (optionally filtered by game)
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
            averageCompletionRate: averageCompletionRate,
            streakConsistency: streakConsistency,
            mostPlayedGame: mostPlayedGame,
            recentActivity: recentActivity
        )
    }

    /// Longest consecutive-day streak inside [startDate, endDate] for an optional game filter
    static func longestStreakInRange(startDate: Date, endDate: Date, gameId: UUID?, results: [GameResult]) -> Int {
        let calendar = Calendar.current
        // Filter results within range and by game
        var filtered = results.filter { $0.date >= startDate && $0.date <= endDate }
        if let gameId = gameId { filtered = filtered.filter { $0.gameId == gameId } }
        // Use unique played days (any result counts as activity)
        let uniqueDays = Set(filtered.map { calendar.startOfDay(for: $0.date) })
        guard !uniqueDays.isEmpty else { return 0 }
        let sortedDays = uniqueDays.sorted()
        var longest = 1
        var current = 1
        for i in 1..<sortedDays.count {
            let prev = sortedDays[i - 1]
            if let dayAfterPrev = calendar.date(byAdding: .day, value: 1, to: prev),
               calendar.isDate(sortedDays[i], inSameDayAs: dayAfterPrev) {
                current += 1
                if current > longest { longest = current }
            } else {
                current = 1
            }
        }
        return longest
    }
    
    static func computeStreakTrends(timeRange: AnalyticsTimeRange, game: Game? = nil, results: [GameResult]) -> [StreakTrendPoint] {
        let (startDate, endDate) = timeRange.dateRange
        let calendar = Calendar.current
        var relevantResults = results.filter { $0.date >= startDate && $0.date <= endDate }
        if let game = game { relevantResults = relevantResults.filter { $0.gameId == game.id } }
        
        // Pre-index: results grouped by startOfDay
        var resultsByDay: [Date: [GameResult]] = [:]
        // Pre-index: set of days each game was played (for streak lookback)
        var gameDays: [UUID: Set<Date>] = [:]
        // Also index results before the range for streak lookback (up to 30 days before start)
        let lookbackStart = calendar.date(byAdding: .day, value: -30, to: startDate) ?? startDate
        let lookbackResults = results.filter { $0.date >= lookbackStart && $0.date < startDate }
        if let game = game {
            for r in lookbackResults.filter({ $0.gameId == game.id }) {
                let day = calendar.startOfDay(for: r.date)
                gameDays[r.gameId, default: []].insert(day)
            }
        } else {
            for r in lookbackResults {
                let day = calendar.startOfDay(for: r.date)
                gameDays[r.gameId, default: []].insert(day)
            }
        }
        for r in relevantResults {
            let day = calendar.startOfDay(for: r.date)
            resultsByDay[day, default: []].append(r)
            gameDays[r.gameId, default: []].insert(day)
        }
        
        var trends: [StreakTrendPoint] = []
        var currentDate = startDate
        while currentDate <= endDate {
            let startOfDay = calendar.startOfDay(for: currentDate)
            let dayResults = resultsByDay[startOfDay] ?? []
            
            // Active streaks: unique games played yesterday or today
            let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
            let yesterdayResults = resultsByDay[yesterday] ?? []
            let todayGameIds = Set(dayResults.map { $0.gameId })
            let yesterdayGameIds = Set(yesterdayResults.map { $0.gameId })
            let activeGameIds = todayGameIds.union(yesterdayGameIds)
            
            // Longest streak: for each active game, walk backwards using the index
            var longestStreakLength = 0
            for gid in activeGameIds {
                guard let days = gameDays[gid] else { continue }
                var streak = 0
                var checkDate = startOfDay
                for _ in 0..<30 {
                    if days.contains(checkDate) {
                        streak += 1
                        guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                        checkDate = prev
                    } else { break }
                }
                longestStreakLength = max(longestStreakLength, streak)
            }
            
            let trendPoint = StreakTrendPoint(
                date: currentDate,
                totalActiveStreaks: activeGameIds.count,
                longestStreak: longestStreakLength,
                gamesPlayed: dayResults.count,
                gamesCompleted: dayResults.filter { $0.completed }.count
            )
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
    
    static func computeAchievementAnalytics(tieredAchievements: [TieredAchievement]?) -> AchievementAnalytics {
        guard let tiered = tieredAchievements, !tiered.isEmpty else {
            return AchievementAnalytics()
        }
        
        var tierDistribution: [AchievementTier: Int] = [:]
        var recentUnlocks: [AchievementUnlock] = []
        var categoryProgress: [AchievementCategory: Double] = [:]
        var nextActions: [String] = []
        
        let totalAvailable = tiered.count
        var totalUnlocked = 0
        
        for t in tiered {
            if let tier = t.progress.currentTier {
                tierDistribution[tier, default: 0] += 1
                totalUnlocked += 1
            }
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
        
        // Next actions: 3 closest next-tier thresholds
        var candidates: [(name: String, remaining: Int)] = []
        for t in tiered {
            if let next = t.nextTierRequirement {
                let remaining = max(0, next.threshold - t.progress.currentValue)
                candidates.append((name: t.displayName, remaining: remaining))
            }
        }
        candidates.sort { $0.remaining < $1.remaining }
        nextActions = Array(candidates.prefix(3)).map { "Play toward \($0.name): \($0.remaining) to next tier" }
        
        // Sort recent unlocks (desc) and limit to 5
        recentUnlocks.sort { $0.timestamp > $1.timestamp }
        recentUnlocks = Array(recentUnlocks.prefix(5))
        
        return AchievementAnalytics(
            totalUnlocked: totalUnlocked,
            totalAvailable: totalAvailable,
            recentUnlocks: recentUnlocks,
            categoryProgress: categoryProgress,
            tierDistribution: tierDistribution,
            nextActions: nextActions
        )
    }
    
    static func computePersonalBests(timeRange: AnalyticsTimeRange, game: Game?, games: [Game], streaks: [GameStreak], results: [GameResult]) -> [PersonalBest] {
        var personalBests: [PersonalBest] = []
        // Filter results by time range and optional game
        let (startDate, endDate) = timeRange.dateRange
        var filteredResults = results.filter { $0.date >= startDate && $0.date <= endDate }
        if let game = game { filteredResults = filteredResults.filter { $0.gameId == game.id } }
        // Candidate games within this range
        let candidateGameIds: [UUID]
        if let game = game {
            candidateGameIds = [game.id]
        } else {
            candidateGameIds = Array(Set(filteredResults.map { $0.gameId }))
        }
        // Longest streaks (per game) within range
        var longestEntries: [(game: Game, value: Int)] = []
        for gid in candidateGameIds {
            guard let g = games.first(where: { $0.id == gid }) else { continue }
            let value = longestStreakInRange(startDate: startDate, endDate: endDate, gameId: gid, results: filteredResults)
            if value > 0 {
                longestEntries.append((game: g, value: value))
            }
        }
        for entry in longestEntries.sorted(by: { $0.value > $1.value }).prefix(2) {
            personalBests.append(PersonalBest(type: .longestStreak, value: entry.value, game: entry.game, date: endDate, description: "\(entry.value) day streak in \(entry.game.displayName)"))
        }
        // Best score per game (completed only) within range
        let completed = filteredResults.filter { $0.completed }
        let grouped = Dictionary(grouping: completed.compactMap { ($0.gameId, $0) }) { $0.0 }
        var bests: [(UUID, Int, GameResult)] = []
        for (gid, tuples) in grouped {
            let rs = tuples.map { $0.1 }.filter { $0.score != nil }
            if let best = rs.min(by: { ($0.score ?? Int.max) < ($1.score ?? Int.max) }), let s = best.score { bests.append((gid, s, best)) }
        }
        for (gid, score, result) in bests.sorted(by: { $0.1 < $1.1 }).prefix(2) {
            if let g = games.first(where: { $0.id == gid }) {
                personalBests.append(PersonalBest(type: .bestScore, value: score, game: g, date: result.date, description: "\(result.displayScore) in \(g.displayName)"))
            }
        }
        // Most games in a day within range (meaningful if > 1)
        let byDay = Dictionary(grouping: filteredResults) { Calendar.current.startOfDay(for: $0.date) }
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
            // Longest streak within this week window (across all games)
            let longest = longestStreakInRange(startDate: weekStart, endDate: weekEnd, gameId: nil, results: weekResults)
            let mostPlayedGameId = Dictionary(grouping: weekResults, by: { $0.gameId }).mapValues { $0.count }.max(by: { $0.value < $1.value })?.key
            let mostPlayedGame = mostPlayedGameId.flatMap { gid in games.first { $0.id == gid } }
            let completionRate = totalPlayed > 0 ? Double(totalCompleted) / Double(totalPlayed) : 0.0
            // Consistency: days with at least one result this week divided by 7
            let daysWithActivity = Set(weekResults.map { calendar.startOfDay(for: $0.date) }).count
            let consistency = Double(daysWithActivity) / 7.0
            summaries.append(WeeklySummary(weekStart: weekStart, weekEnd: weekEnd, totalGamesPlayed: totalPlayed, totalGamesCompleted: totalCompleted, averageStreakLength: avgStreak, longestStreak: longest, mostPlayedGame: mostPlayedGame, completionRate: completionRate, streakConsistency: consistency))
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
