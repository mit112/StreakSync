//
//  GameDetailPerformanceView.swift
//  StreakSync
//
//  FIXED: Dynamic scale and simplified time ranges
//

import SwiftUI
import Charts

// MARK: - Enhanced Game Detail Performance View
struct GameDetailPerformanceView: View {
    let results: [GameResult]
    let streak: GameStreak
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Environment(AppState.self) private var appState
    
    @State private var selectedBar: DailyResult?
    @State private var showingExportMenu = false
    @State private var chartHasAppeared = false
    
    // Get the game for max attempts
    private var game: Game? {
        appState.games.first { $0.id == streak.gameId }
    }
    
    // Dynamic max value based on game type
    private var chartMaxValue: Int {
        // Special handling for time-based games like LinkedIn Zip, Tango, Queens, and Crossclimb
        if let game = game, (game.name.lowercased() == "linkedinzip" || game.name.lowercased() == "linkedintango" || game.name.lowercased() == "linkedinqueens" || game.name.lowercased() == "linkedincrossclimb") {
            // For Zip, Tango, Queens, and Crossclimb, use actual score values (time in seconds) instead of maxAttempts
            if let maxScore = results.compactMap(\.score).max() {
                return maxScore + 5 // Add some padding above the max score
            }
            return 30 // Default for time-based games if no results
        }
        
        // Special handling for guess-based games like LinkedIn Pinpoint
        if let game = game, game.name.lowercased() == "linkedinpinpoint" {
            // For Pinpoint, use maxAttempts (5) as the chart maximum
            return 5
        }
        
        // Special handling for hint-based games like NYT Strands
        if let game = game, game.name.lowercased() == "strands" {
            // For Strands, use maxAttempts (10) as the chart maximum
            return 10
        }
        
        // Standard games: Use the max attempts from actual results, or default to 6
        if let maxFromResults = results.map(\.maxAttempts).max() {
            return maxFromResults + 1 // Add 1 for failed attempts
        }
        return 7 // Default for most games
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Simplified header - just showing "Recent Performance"
            HStack {
                Label("Recent Performance", systemImage: SFSymbolCompatibility.getSymbol("chart.line.uptrend.xyaxis"))
                    .font(.headline)
                
                Spacer()
                
                // Export button
                Button {
                    showingExportMenu = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            
            // Chart - always 7 days for clarity
            PerformanceChart(
                results: results,
                streak: streak,
                maxValue: chartMaxValue,
                selectedBar: $selectedBar,
                hasAppeared: $chartHasAppeared
            ) {
                // Navigate to full history
                HapticManager.shared.trigger(.buttonTap)
                coordinator.navigateTo(.streakHistory(streak))
            }
        }
        .onAppear {
            withAnimation(.smooth.delay(0.3)) {
                chartHasAppeared = true
            }
        }
        .confirmationDialog("Export Performance Data", isPresented: $showingExportMenu) {
            Button("Copy Stats to Clipboard") { copyToClipboard() }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private func copyToClipboard() {
        HapticManager.shared.trigger(.buttonTap)
        let stats = """
        \(streak.gameName) Performance
        Last 7 Days
        Games Played: \(min(results.count, 7))
        Success Rate: \(streak.completionPercentage)
        Current Streak: \(streak.currentStreak) days
        """
        UIPasteboard.general.string = stats
    }
}

// MARK: - Simplified Performance Chart (7 days only)
private struct PerformanceChart: View {
    let results: [GameResult]
    let streak: GameStreak
    let maxValue: Int
    @Binding var selectedBar: DailyResult?
    @Binding var hasAppeared: Bool
    let onTap: () -> Void
    
    @State private var animateChart = false
    
    // Always show last 7 days
    private var dailyResults: [DailyResult] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var last7Days: [Date] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                last7Days.append(date)
            }
        }
        last7Days.reverse()
        
        return last7Days.map { dayStart in
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let dayResult = results.first { result in
                result.date >= dayStart && result.date < dayEnd
            }
            return DailyResult(date: dayStart, result: dayResult)
        }
    }
    
    private var stats: SimpleStats {
        SimpleStats(from: dailyResults)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stats header
            SimpleChartHeader(stats: stats)
            
            // Chart
            if !dailyResults.isEmpty {
                ModernChart(
                    dailyResults: dailyResults,
                    maxValue: maxValue,
                    selectedBar: $selectedBar,
                    animateChart: animateChart
                )
            }
            
            // Selected bar detail
            if let selected = selectedBar {
                SelectedBarDetail(dailyResult: selected)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.tertiary.opacity(0.3), lineWidth: 0.5)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear {
            withAnimation(.smooth.delay(0.1)) {
                animateChart = true
            }
        }
    }
}

// MARK: - Modern Chart with Dynamic Scale
private struct ModernChart: View {
    let dailyResults: [DailyResult]
    let maxValue: Int
    @Binding var selectedBar: DailyResult?
    let animateChart: Bool
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E" // Always use weekday for 7 days
        return formatter
    }
    
    var body: some View {
        GeometryReader { geometry in
            Chart(dailyResults.indices, id: \.self) { index in
            let daily = dailyResults[index]
            let dayString = dayFormatter.string(from: daily.date)
            
            if let result = daily.result {
                // Use actual score or max+1 for failed
                let score = result.score ?? (result.maxAttempts + 1)
                let barColor = result.completed ? Color.green : Color.red
                
                BarMark(
                    x: .value("Day", dayString),
                    y: .value("Score", animateChart ? score : 0)
                )
                .foregroundStyle(barColor.gradient)
                .opacity(selectedBar == nil || selectedBar?.date == daily.date ? 1 : 0.5)
                .cornerRadius(4)
            } else {
                // Empty day indicator - very small
                BarMark(
                    x: .value("Day", dayString),
                    y: .value("Score", animateChart ? 0.2 : 0)
                )
                .foregroundStyle(.tertiary.opacity(0.2))
                .cornerRadius(2)
            }
        }
        .chartYScale(domain: 0...maxValue) // Dynamic scale!
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                if let intValue = value.as(Int.self) {
                    if intValue > 0 && intValue <= maxValue {
                        AxisGridLine()
                        AxisValueLabel {
                            Text("\(intValue)")
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .frame(height: 120)
        .animation(.smooth(duration: 0.6), value: animateChart)
        .onTapGesture { location in
            handleTap(at: location, geometry: geometry)
        }
        }
        .frame(height: 140) // Constrain GeometryReader to prevent background bleed/overlap
    }
    
    private func handleTap(at location: CGPoint, geometry: GeometryProxy) {
        let width = geometry.size.width - 64 // Account for padding
        let barWidth = width / 7 // Always 7 days
        let index = Int(location.x / barWidth)
        
        if index >= 0 && index < dailyResults.count {
            withAnimation(.smooth) {
                let daily = dailyResults[index]
                selectedBar = daily.result != nil ? daily : nil
            }
            HapticManager.shared.trigger(.buttonTap)
        }
    }
}

// MARK: - Simplified Chart Header
private struct SimpleChartHeader: View {
    let stats: SimpleStats
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(stats.gamesPlayed) games")
                    .font(.subheadline.weight(.medium))
                Text("Past week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                StatBadge(label: "Avg", value: stats.averageScore, color: .blue)
                StatBadge(label: "Best", value: "\(stats.bestScore)", color: .green)
                StatBadge(label: "Rate", value: stats.successRate, color: .purple)
            }
        }
        
        // Simple progress bar
        if stats.gamesPlayed > 0 {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(height: 3)
                    
                    Capsule()
                        .fill(Color.green.gradient)
                        .frame(width: geometry.size.width * stats.completionRatio, height: 3)
                }
            }
            .frame(height: 3)
        }
    }
}

// MARK: - Stat Badge (unchanged)
private struct StatBadge: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Selected Bar Detail (unchanged)
private struct SelectedBarDetail: View {
    let dailyResult: DailyResult
    
    var body: some View {
        HStack {
            Image(systemName: dailyResult.result?.completed == true ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(dailyResult.result?.completed == true ? .green : .orange)
            
            VStack(alignment: .leading) {
                Text(dailyResult.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption.weight(.medium))
                
                if let result = dailyResult.result {
                    Text("Score: \(result.displayScore)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No game played")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Simple Stats
private struct SimpleStats {
    let gamesPlayed: Int
    let averageScore: String
    let bestScore: Int
    let successRate: String
    let completionRatio: Double
    
    init(from dailyResults: [DailyResult]) {
        let results = dailyResults.compactMap(\.result)
        self.gamesPlayed = results.count
        
        // Calculate average
        let completedResults = results.filter { $0.completed && $0.score != nil }
        if !completedResults.isEmpty {
            let total = completedResults.compactMap(\.score).reduce(0, +)
            let avg = Double(total) / Double(completedResults.count)
            self.averageScore = String(format: "%.1f", avg)
        } else {
            self.averageScore = "—"
        }
        
        // Best score (lowest is best)
        self.bestScore = completedResults.compactMap(\.score).min() ?? 0
        
        // Success rate
        let successCount = results.filter(\.completed).count
        if gamesPlayed > 0 {
            let rate = Double(successCount) / Double(gamesPlayed) * 100
            self.successRate = "\(Int(rate))%"
            self.completionRatio = Double(successCount) / Double(gamesPlayed)
        } else {
            self.successRate = "—"
            self.completionRatio = 0
        }
    }
}

// MARK: - Performance Chart
private struct ModernPerformanceChart: View {
    let dailyResults: [DailyResult]
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E" // Mon, Tue, Wed, etc.
        return formatter
    }
    
    // Dynamic max value based on actual scores
    private var chartMaxValue: Int {
        let scores = dailyResults.compactMap { $0.result?.score }
        if let maxScore = scores.max() {
            return maxScore + 5 // Add some padding above the max score
        }
        return 7 // Default for most games
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
        .chartYScale(domain: 0...chartMaxValue)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: Array(1...chartMaxValue)) { value in
                AxisGridLine()
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .frame(height: 100)
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
