//
//  StreakTrendsDetailView.swift
//  StreakSync
//
//  Detailed streak trends analysis with interactive chart and insights
//

import SwiftUI
import Charts

// MARK: - Streak Trends Detail View
struct StreakTrendsDetailView: View {
    let analyticsService: AnalyticsService
    let timeRange: AnalyticsTimeRange
    let selectedGame: Game?
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var trends: [StreakTrendPoint] = []
    @State private var selectedDate: Date?
    @State private var isLoading = true
    
    private var selectedPoint: StreakTrendPoint? {
        guard let date = selectedDate else { return nil }
        return trends.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    private var gameDisplayName: String {
        selectedGame?.displayName ?? "All Games"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Interactive Chart
                interactiveChartSection
                
                // Insights
                if !trends.isEmpty {
                    insightsSection
                }
                
                // Daily Activity Feed
                dailyActivitySection
            }
            .padding()
        }
        .navigationTitle("Streak Trends")
        .navigationBarTitleDisplayMode(.large)
        .background(StreakSyncColors.background(for: colorScheme))
        .task {
            await loadData()
        }
    }
    
    // MARK: - Interactive Chart Section
    private var interactiveChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Activity Timeline")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("\(gameDisplayName) • \(timeRange.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
            } else if trends.isEmpty {
                emptyChartView
            } else {
                VStack(spacing: 12) {
                    // Chart
                    Chart {
                        ForEach(trends, id: \.date) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Active Streaks", point.totalActiveStreaks)
                            )
                            .foregroundStyle(.blue.gradient)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                            
                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Active Streaks", point.totalActiveStreaks)
                            )
                            .foregroundStyle(.blue.opacity(0.1).gradient)
                            .interpolationMethod(.catmullRom)
                            
                            if let selected = selectedPoint, selected.date == point.date {
                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Active Streaks", point.totalActiveStreaks)
                                )
                                .foregroundStyle(.blue)
                                .symbol(.circle)
                                .symbolSize(100)
                            }
                        }
                    }
                    .frame(height: 300)
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXSelection(value: $selectedDate)
                    
                    // Selected Point Detail
                    if let point = selectedPoint {
                        selectedPointCard(point)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        tapToInspectHint
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
    
    private func selectedPointCard(_ point: StreakTrendPoint) -> some View {
        VStack(spacing: 14) {
            // Header with date and streak status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(point.date, format: .dateTime.month().day().year())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(point.date, format: .dateTime.weekday(.wide))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                streakStatusBadge(for: point)
            }
            
            // Stats (Option A)
            HStack(spacing: 12) {
                statPill(
                    value: "\(point.totalActiveStreaks)",
                    label: "Active",
                    color: .blue
                )
                
                statPill(
                    value: "\(point.gamesCompleted)",
                    label: "Completed",
                    color: .green
                )
                
                statPill(
                    value: successRate(for: point),
                    label: "Success Rate",
                    color: .purple
                )
            }
            
            // Game breakdown chips
            if point.gamesPlayed > 0 {
                gameBreakdownChips(for: point)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(color.opacity(0.1))
        }
    }
    
    // MARK: - Helper Functions
    
    private func successRate(for point: StreakTrendPoint) -> String {
        guard point.gamesPlayed > 0 else { return "0%" }
        let rate = (Double(point.gamesCompleted) / Double(point.gamesPlayed)) * 100
        return String(format: "%.0f%%", rate)
    }
    
    private func streakStatusBadge(for point: StreakTrendPoint) -> some View {
        let (icon, text, color) = getStreakStatus(for: point)
        
        return HStack(spacing: 4) {
            Image.safeSystemName(icon, fallback: "questionmark.circle")
                .font(.caption2)
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(color.opacity(0.15))
        }
    }
    
    private func getStreakStatus(for point: StreakTrendPoint) -> (icon: String, text: String, color: Color) {
        let calendar = Calendar.current
        let pointIndex = trends.firstIndex { calendar.isDate($0.date, inSameDayAs: point.date) } ?? 0
        
        // Check if this is the first day or if there's a previous day
        if pointIndex > 0 {
            let previousPoint = trends[pointIndex - 1]
            
            if point.gamesPlayed > 0 {
                if previousPoint.totalActiveStreaks == 0 && point.totalActiveStreaks > 0 {
                    return ("sparkles", "Started", .green)
                } else if point.totalActiveStreaks > previousPoint.totalActiveStreaks {
                    return ("arrow.up.circle.fill", "Grew", .green)
                } else if point.totalActiveStreaks == previousPoint.totalActiveStreaks && point.gamesPlayed > 0 {
                    return ("checkmark.circle.fill", "Maintained", .blue)
                } else if point.totalActiveStreaks < previousPoint.totalActiveStreaks {
                    return ("exclamationmark.triangle.fill", "Lost", .orange)
                }
            } else if previousPoint.totalActiveStreaks > 0 && point.totalActiveStreaks > 0 {
                return ("pause.circle.fill", "Safe Skip", .yellow)
            } else if previousPoint.totalActiveStreaks > 0 && point.totalActiveStreaks == 0 {
                return ("xmark.circle.fill", "Broken", .red)
            }
        } else if point.gamesPlayed > 0 {
            return ("sparkles", "Started", .green)
        }
        
        return ("minus.circle.fill", "No Activity", .secondary)
    }
    
    private func gameBreakdownChips(for point: StreakTrendPoint) -> some View {
        let calendar = Calendar.current
        let dayResults = appState.recentResults.filter { calendar.isDate($0.date, inSameDayAs: point.date) }
        let uniqueGames = Dictionary(grouping: dayResults, by: { $0.gameId })
        
        return VStack(alignment: .leading, spacing: 8) {
            Text("Games Played")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            // Simple horizontal scroll for game chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(uniqueGames.keys), id: \.self) { gameId in
                        if let game = appState.games.first(where: { $0.id == gameId }) {
                            let gameResults = uniqueGames[gameId] ?? []
                            let completed = gameResults.filter(\.completed).count
                            let total = gameResults.count
                            
                            gameChip(
                                game: game,
                                completed: completed,
                                total: total
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func gameChip(game: Game, completed: Int, total: Int) -> some View {
        HStack(spacing: 6) {
            Image.safeSystemName(game.iconSystemName, fallback: "gamecontroller")
                .font(.caption)
                .foregroundStyle(game.backgroundColor.color)
            
            Text(game.displayName)
                .font(.caption)
                .fontWeight(.medium)
            
            if completed == total {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else {
                Text("\(completed)/\(total)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.regularMaterial)
                .overlay(
                    Capsule()
                        .stroke(game.backgroundColor.color.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var tapToInspectHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("Tap chart to see daily details")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        }
    }
    
    private var emptyChartView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            
            Text("No Activity Data")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Start playing games to see your trends")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
    }
    
    // MARK: - Insights Section
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                insightCard(
                    title: "Peak Period",
                    value: peakPeriod,
                    icon: SFSymbolCompatibility.getSymbol("chart.line.uptrend.xyaxis"),
                    color: .green
                )
                
                insightCard(
                    title: "Avg Active Streaks",
                    value: String(format: "%.1f", averageActiveStreaks),
                    icon: "flame.fill",
                    color: .orange
                )
                
                insightCard(
                    title: "Most Productive",
                    value: mostProductiveDay,
                    icon: "star.fill",
                    color: .yellow
                )
                
                insightCard(
                    title: "Consistency",
                    value: consistencyScore,
                    icon: "checkmark.circle.fill",
                    color: .blue
                )
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
    
    private func insightCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image.safeSystemName(icon, fallback: "chart.bar")
                .font(.title3)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        }
    }
    
    // MARK: - Daily Activity Section
    private var dailyActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Breakdown")
                .font(.headline)
                .fontWeight(.semibold)
            
            if trends.isEmpty {
                emptyActivityView
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(trends.reversed(), id: \.date) { point in
                        dailyActivityRow(point)
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
    
    private func dailyActivityRow(_ point: StreakTrendPoint) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(point.date, format: .dateTime.month().day())
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(point.date, format: .dateTime.weekday(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 60, alignment: .leading)
            
            if point.gamesPlayed > 0 {
                HStack(spacing: 8) {
                    Label("\(point.totalActiveStreaks)", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    
                    Label("\(point.gamesPlayed)", systemImage: "gamecontroller.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    
                    if point.gamesCompleted > 0 {
                        Label("\(point.gamesCompleted)", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(.regularMaterial)
                }
            } else {
                Text("No activity")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(point.gamesPlayed > 0 ? Color.blue.opacity(0.05) : Color.clear)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedDate = (selectedDate != nil && Calendar.current.isDate(selectedDate!, inSameDayAs: point.date)) ? nil : point.date
            }
            HapticManager.shared.trigger(.buttonTap)
        }
    }
    
    private var emptyActivityView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("No daily activity to show")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    // MARK: - Computed Properties
    private var peakPeriod: String {
        guard let maxPoint = trends.max(by: { $0.totalActiveStreaks < $1.totalActiveStreaks }),
              maxPoint.totalActiveStreaks > 0 else {
            return "N/A"
        }
        return maxPoint.date.formatted(.dateTime.month(.abbreviated).day())
    }
    
    private var averageActiveStreaks: Double {
        guard !trends.isEmpty else { return 0 }
        let sum = trends.reduce(0) { $0 + $1.totalActiveStreaks }
        return Double(sum) / Double(trends.count)
    }
    
    private var mostProductiveDay: String {
        guard let maxPoint = trends.max(by: { $0.gamesPlayed < $1.gamesPlayed }),
              maxPoint.gamesPlayed > 0 else {
            return "N/A"
        }
        return maxPoint.date.formatted(.dateTime.weekday(.abbreviated))
    }
    
    private var consistencyScore: String {
        let activeDays = trends.filter { $0.gamesPlayed > 0 }.count
        let totalDays = trends.count
        guard totalDays > 0 else { return "0%" }
        let percentage = (Double(activeDays) / Double(totalDays)) * 100
        return String(format: "%.0f%%", percentage)
    }
    
    // MARK: - Data Loading
    private func loadData() async {
        isLoading = true
        let data = await analyticsService.getAnalyticsData(for: timeRange, game: selectedGame)
        trends = data.streakTrends
        isLoading = false
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        StreakTrendsDetailView(
            analyticsService: AnalyticsService(appState: AppState()),
            timeRange: .week,
            selectedGame: nil
        )
        .environment(AppState())
    }
}
