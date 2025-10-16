//
//  AnalyticsChartSections.swift
//  StreakSync
//
//  Chart sections for the analytics dashboard
//

import SwiftUI
import Charts

// MARK: - Streak Trends Chart Section
struct StreakTrendsChartSection: View {
    let trends: [StreakTrendPoint]
    let timeRangeDisplayName: String
    let chartData: [StreakTrendChartPoint]
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Streak Trends")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Active streaks over \(timeRangeDisplayName.lowercased())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(getStreakTrendSummary())
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        if let latest = trends.last {
                            Text("Latest: \(latest.totalActiveStreaks) active")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                if #available(iOS 16.0, *) {
                    StreakTrendsChart(data: chartData)
                } else {
                    LegacyStreakTrendsView(trends: trends)
                }
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func getStreakTrendSummary() -> String {
        guard !trends.isEmpty else { return "No data available" }
        
        let latest = trends.last!
        let previous = trends.count > 1 ? trends[trends.count - 2] : latest
        
        let trend = latest.totalActiveStreaks - previous.totalActiveStreaks
        let trendText = trend > 0 ? "+\(trend)" : trend < 0 ? "\(trend)" : "No change"
        
        return "\(latest.totalActiveStreaks) active streaks (\(trendText))"
    }
}

// MARK: - Modern Streak Trends Chart (iOS 16+)
@available(iOS 16.0, *)
struct StreakTrendsChart: View {
    let data: [StreakTrendChartPoint]
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }
    
    var body: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Active Streaks", point.value)
            )
            .foregroundStyle(.orange.gradient)
            .lineStyle(StrokeStyle(lineWidth: 3))
            
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Active Streaks", point.value)
            )
            .foregroundStyle(.orange.opacity(0.2).gradient)
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .frame(height: 120)
    }
}

// MARK: - Legacy Streak Trends View
struct LegacyStreakTrendsView: View {
    let trends: [StreakTrendPoint]
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(trends.suffix(7), id: \.date) { trend in
                HStack {
                    Text(dateString(trend.date))
                        .font(.caption)
                        .frame(width: 40, alignment: .leading)
                    
                    HStack(spacing: 4) {
                        ForEach(0..<trend.totalActiveStreaks, id: \.self) { _ in
                            Circle()
                                .fill(.orange)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(trend.totalActiveStreaks)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .frame(height: 120)
    }
    
    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

// MARK: - Game Performance Section
struct GamePerformanceSection: View {
    let gameAnalytics: GameAnalytics?
    let selectedGameDisplayName: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Game Performance")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Show which game is selected
                Text(selectedGameDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let gameAnalytics = gameAnalytics {
                GamePerformanceChart(gameAnalytics: gameAnalytics)
            } else {
                EmptyGamePerformanceView()
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Game Performance Chart
struct GamePerformanceChart: View {
    let gameAnalytics: GameAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Game info
            HStack {
                Image.safeSystemName(gameAnalytics.game.iconSystemName, fallback: "gamecontroller")
                    .font(.title3)
                    .foregroundStyle(gameAnalytics.game.backgroundColor.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(gameAnalytics.game.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Current Streak: \(gameAnalytics.currentStreak) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(gameAnalytics.totalGamesPlayed)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Games Played")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Performance chart
            if #available(iOS 16.0, *) {
                GamePerformanceChartView(results: gameAnalytics.recentResults)
            } else {
                LegacyGamePerformanceView(results: gameAnalytics.recentResults)
            }
        }
    }
}

// MARK: - Modern Game Performance Chart (iOS 16+)
@available(iOS 16.0, *)
struct GamePerformanceChartView: View {
    let results: [GameResult]
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }
    
    // Dynamic max value based on actual scores
    private var chartMaxValue: Int {
        let scores = results.compactMap { $0.score }
        if let maxScore = scores.max() {
            return maxScore + 5 // Add some padding above the max score
        }
        return 7 // Default for most games
    }
    
    var body: some View {
        Chart(results.suffix(7)) { result in
            BarMark(
                x: .value("Date", result.date),
                y: .value("Score", Double(result.score ?? (result.maxAttempts + 1)))
            )
            .foregroundStyle(result.completed ? .green : .red)
            .cornerRadius(4)
            .annotation(position: .overlay, alignment: .top) {
                // For failed results, show an "X" overlay for quick recognition
                if !result.completed {
                    Text("X").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .chartYScale(domain: 0...chartMaxValue)
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                AxisValueLabel(centered: true) {
                    // Format Y-axis for time-based games (when values are large like seconds)
                    if let doubleValue = value.as(Double.self) {
                        let intVal = Int(doubleValue)
                        if intVal >= 60 && intVal % 30 == 0 {
                            let minutes = intVal / 60
                            let seconds = intVal % 60
                            Text(String(format: "%d:%02d", minutes, seconds))
                                .font(.caption2)
                        } else {
                            Text("\(intVal)")
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .frame(height: 100)
    }
}

// MARK: - Legacy Game Performance View
struct LegacyGamePerformanceView: View {
    let results: [GameResult]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(results.suffix(7), id: \.id) { result in
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(result.completed ? .green : .red)
                        .frame(width: 20, height: CGFloat(result.score ?? (result.maxAttempts + 1)) * 8)
                    
                    Text(dateString(result.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 100)
    }
    
    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

// MARK: - Personal Bests Section
struct PersonalBestsSection: View {
    let personalBests: [PersonalBest]
    @Environment(\.colorScheme) private var colorScheme
    
    private var meaningfulPersonalBests: [PersonalBest] {
        personalBests.filter { personalBest in
            // Filter out meaningless metrics
            switch personalBest.type {
            case .mostGamesInDay:
                return personalBest.value > 1 // Only show if more than 1 game in a day
            case .longestStreak:
                return personalBest.value > 0 // Only show if there's an actual streak
            case .bestScore:
                return personalBest.value > 0 // Only show if there's a score
            case .perfectWeek:
                return personalBest.value > 0 // Only show if there's a perfect week
            case .fastestCompletion:
                return personalBest.value > 0 // Only show if there's a completion time
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Bests")
                .font(.headline)
                .fontWeight(.semibold)
            
            if meaningfulPersonalBests.isEmpty {
                EmptyPersonalBestsView()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(meaningfulPersonalBests, id: \.id) { personalBest in
                        PersonalBestCard(personalBest: personalBest)
                    }
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Personal Best Card
struct PersonalBestCard: View {
    let personalBest: PersonalBest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image.safeSystemName(personalBest.type.iconSystemName, fallback: "trophy.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(personalBest.value)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(personalBest.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let game = personalBest.game {
                Text(game.displayName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        }
    }
}

// MARK: - Most Active Games Section
struct MostActiveGamesSection: View {
    let activeGames: [GameAnalytics]
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Most Active Games")
                .font(.headline)
                .fontWeight(.semibold)
            
            if activeGames.isEmpty {
                EmptyActiveGamesView()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(activeGames, id: \.id) { gameAnalytics in
                        MostActiveGameRow(gameAnalytics: gameAnalytics)
                    }
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Most Active Game Row
struct MostActiveGameRow: View {
    let gameAnalytics: GameAnalytics
    
    var body: some View {
        HStack(spacing: 12) {
            // Game icon
            ZStack {
                Circle()
                    .fill(gameAnalytics.game.backgroundColor.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image.safeSystemName(gameAnalytics.game.iconSystemName, fallback: "gamecontroller")
                    .font(.title3)
                    .foregroundStyle(gameAnalytics.game.backgroundColor.color)
            }
            
            // Game info
            VStack(alignment: .leading, spacing: 2) {
                Text(gameAnalytics.game.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(gameAnalytics.currentStreak) day streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(gameAnalytics.totalGamesPlayed)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Games")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty Game Performance View
struct EmptyGamePerformanceView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image.compatibleSystemName("chart.bar.xaxis")
                .font(.title)
                .foregroundStyle(.orange.gradient)
            
            Text("No Performance Data")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text("Start playing this game to track your performance and build streaks")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Empty Personal Bests View
struct EmptyPersonalBestsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title)
                .foregroundStyle(.yellow.gradient)
            
            Text("No Personal Bests Yet")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            VStack(spacing: 4) {
                Text("Play games to set your first record!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("• Longest streaks")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("• Best scores")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Empty Active Games View
struct EmptyActiveGamesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gamecontroller.fill")
                .font(.title)
                .foregroundStyle(.blue.gradient)
            
            Text("No Game Activity")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            VStack(spacing: 4) {
                Text("Share game results to start tracking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Tap the share button after completing a game")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AnalyticsDashboardView(analyticsService: AnalyticsService(appState: AppState()))
    }
}
