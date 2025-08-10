//
//  GameDetailPerformanceView.swift
//  StreakSync
//
//  Performance chart component extracted from GameDetailView
//

import SwiftUI
import Charts

// MARK: - Game Detail Performance View
struct GameDetailPerformanceView: View {
    let results: [GameResult]
    let streak: GameStreak
    @EnvironmentObject private var coordinator: NavigationCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "Recent Performance", icon: "chart.line.uptrend.xyaxis")
            
            PerformanceChart(results: results, streak: streak) {
                // Navigate to streak history on tap
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                coordinator.navigateTo(.streakHistory(streak))
            }
        }
    }
}

// MARK: - Performance Chart
private struct PerformanceChart: View {
    let results: [GameResult]
    let streak: GameStreak
    let onTap: () -> Void
    
    // Group results by calendar day
    private var dailyResults: [DailyResult] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get last 7 days
        var last7Days: [Date] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                last7Days.append(date)
            }
        }
        last7Days.reverse() // Oldest to newest
        
        // Create daily results (one per day)
        return last7Days.map { dayStart in
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            
            // Find result for this day
            let dayResult = results.first { result in
                result.date >= dayStart && result.date < dayEnd
            }
            
            return DailyResult(date: dayStart, result: dayResult)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with stats
            ChartHeader(
                gamesPlayed: gamesPlayedCount,
                averageScore: averageScoreText
            )
            
            // Chart area
            chartArea
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
        }
        .padding()
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.tertiary.opacity(0.5), lineWidth: 0.5)
        )
    }
    
    @ViewBuilder
    private var chartArea: some View {
        if #available(iOS 16.0, *), hasAnyResults {
            ModernPerformanceChart(dailyResults: dailyResults)
        } else {
            LegacyPerformanceIndicators(dailyResults: dailyResults)
        }
    }
    
    private var hasAnyResults: Bool {
        dailyResults.contains { $0.result != nil }
    }
    
    private var gamesPlayedCount: Int {
        dailyResults.compactMap(\.result).count
    }
    
    private var averageScoreText: String {
        let completedResults = dailyResults.compactMap(\.result).filter { $0.completed && $0.score != nil }
        guard !completedResults.isEmpty else { return "No completions" }
        
        let total = completedResults.compactMap(\.score).reduce(0, +)
        let average = Double(total) / Double(completedResults.count)
        return String(format: "Avg: %.1f", average)
    }
}

// MARK: - Chart Header
private struct ChartHeader: View {
    let gamesPlayed: Int
    let averageScore: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Last 7 Days")
                    .font(.subheadline.weight(.medium))
                Text("\(gamesPlayed) games played")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                if gamesPlayed > 0 {
                    Text(averageScore)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Modern Performance Chart (iOS 16+)
@available(iOS 16.0, *)
private struct ModernPerformanceChart: View {
    let dailyResults: [DailyResult]
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E" // Mon, Tue, Wed, etc.
        return formatter
    }
    
    var body: some View {
        Chart {
            ForEach(Array(dailyResults.enumerated()), id: \.offset) { index, daily in
                if let result = daily.result {
                    // Show actual result
                    BarMark(
                        x: .value("Day", dayFormatter.string(from: daily.date)),
                        y: .value("Score", result.score ?? result.maxAttempts + 1)
                    )
                    .foregroundStyle(result.completed ? .green : .red)
                    .opacity(0.8)
                } else {
                    // Show empty day as minimal indicator
                    BarMark(
                        x: .value("Day", dayFormatter.string(from: daily.date)),
                        y: .value("Score", 0.5)
                    )
                    .foregroundStyle(.tertiary.opacity(0.3))
                }
            }
        }
        .chartYScale(domain: 0...6)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: [1, 2, 3, 4, 5, 6]) { value in
                AxisGridLine()
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .frame(height: 100)
    }
}

// MARK: - Legacy Performance Indicators
private struct LegacyPerformanceIndicators: View {
    let dailyResults: [DailyResult]
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(dailyResults.enumerated()), id: \.offset) { index, daily in
                VStack(spacing: 4) {
                    Circle()
                        .fill(circleColor(for: daily.result))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 1)
                        )
                    
                    Text(dayFormatter.string(from: daily.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private func circleColor(for result: GameResult?) -> Color {
        guard let result = result else { return .clear }
        return result.completed ? .green : .red
    }
}

// MARK: - Daily Result Helper
struct DailyResult {
    let date: Date
    let result: GameResult? // nil if no game played that day
}

// MARK: - Preview
#Preview {
    GameDetailPerformanceView(
        results: [],
        streak: GameStreak(
            gameId: Game.wordle.id,
            gameName: "wordle",
            currentStreak: 5,
            maxStreak: 12,
            totalGamesPlayed: 30,
            totalGamesCompleted: 25,
            lastPlayedDate: Date(),
            streakStartDate: Date()
        )
    )
    .environmentObject(NavigationCoordinator())
    .padding()
}
