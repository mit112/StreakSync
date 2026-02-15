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
                
                StreakTrendsChart(data: chartData)
            }
            .padding()
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
    
    private func getStreakTrendSummary() -> String {
        guard !trends.isEmpty else { return "No data available" }
        let peak = trends.map { $0.totalActiveStreaks }.max() ?? 0
        return "Peak: \(peak) active"
    }
}

// MARK: - Streak Trends Chart
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
        .cardStyle()
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
            GamePerformanceChartView(results: gameAnalytics.recentResults)
        }
    }
}

// MARK: - Game Performance Chart
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
