//
//  AnalyticsDashboardView.swift
//  StreakSync
//
//  Main analytics dashboard with comprehensive statistics and charts
//

import SwiftUI
import Charts

// MARK: - Analytics Dashboard View
struct AnalyticsDashboardView: View {
    @StateObject private var viewModel: AnalyticsViewModel
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var hasInitiallyAppeared = false
    
    init(analyticsService: AnalyticsService) {
        self._viewModel = StateObject(wrappedValue: AnalyticsViewModel(analyticsService: analyticsService))
    }
    
    var body: some View {
        if #available(iOS 26.0, *) {
            iOS26AnalyticsView
        } else {
            legacyAnalyticsView
        }
    }
    
    // MARK: - iOS 26 Implementation
    @available(iOS 26.0, *)
    private var iOS26AnalyticsView: some View {
        ScrollView {
            LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
                Section {
                    // Content with proper view identity to prevent glitches
                    contentSection
                        .id("\(viewModel.selectedTimeRange.rawValue)-\(viewModel.selectedGame?.id.uuidString ?? "all")")
                        .padding(.horizontal, 16)
                } header: {
                    // Time range filter as sticky header
                    timeRangeHeader
                        .background(StreakSyncColors.background(for: colorScheme))
                }
            }
            .padding(.bottom, 20)
        }
        .background(StreakSyncColors.background(for: colorScheme))
        .scrollBounceBehavior(.automatic)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Game filter in toolbar (native iOS pattern)
                HStack {
                    Button {
                        exportCSV()
                    } label: {
                        Image.safeSystemName("square.and.arrow.up", fallback: "square.and.arrow.up")
                    }
                    gameFilterMenu
                }
            }
        }
        .refreshable {
            await viewModel.refreshAnalytics()
        }
        // Respond to data changes
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GameDataUpdated"))) { _ in
            Task { @MainActor in
                await viewModel.refreshAnalytics()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GameResultAdded"))) { _ in
            Task { @MainActor in
                await viewModel.refreshAnalytics()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshGameData"))) { _ in
            Task { @MainActor in
                await viewModel.refreshAnalytics()
            }
        }
        .onAppear {
            if !hasInitiallyAppeared {
                Task {
                    await viewModel.loadAnalytics()
                }
                hasInitiallyAppeared = true
            }
        }
    }
    
    // MARK: - Content Section
    @ViewBuilder
    private var contentSection: some View {
        // Overview stats
        if let overview = viewModel.overview {
            OverviewStatsSection(overview: overview, analyticsService: viewModel.analyticsService, timeRange: viewModel.selectedTimeRange, selectedGame: viewModel.selectedGame)
        }
        
        // At-Risk Today (only when viewing All Games)
        if viewModel.selectedGame == nil {
            AtRiskTodaySection()
        }
        
        // Streak trends chart
        if !viewModel.currentStreakTrends.isEmpty {
            StreakTrendsChartSection(
                trends: viewModel.currentStreakTrends,
                timeRangeDisplayName: viewModel.timeRangeDisplayName,
                chartData: viewModel.getStreakTrendChartData(),
                onTap: {
                    coordinator.navigateTo(.streakTrendsDetail(
                        timeRange: viewModel.selectedTimeRange,
                        game: viewModel.selectedGame
                    ))
                }
            )
        }
        
        // Game performance section
        if viewModel.selectedGame != nil {
            GamePerformanceSection(
                gameAnalytics: viewModel.currentGameAnalytics,
                selectedGameDisplayName: viewModel.selectedGameDisplayName
            )
            if let ga = viewModel.currentGameAnalytics {
                GameDeepDiveSection(gameAnalytics: ga)
            }
        }
        
        // Personal bests
        if !viewModel.personalBests.isEmpty {
            PersonalBestsSection(personalBests: viewModel.personalBests)
        }
        
        // Achievements (hide when nothing unlocked)
        if let aa = viewModel.achievementAnalytics, (aa.totalUnlocked > 0 || !aa.tierDistribution.isEmpty) {
            AchievementsSummarySection(analytics: aa)
            if !aa.nextActions.isEmpty {
                NextActionsSection(actions: aa.nextActions)
            }
        }

        // Most active games
        if !viewModel.getMostActiveGames().isEmpty {
            MostActiveGamesSection(activeGames: viewModel.getMostActiveGames())
        }
        
        // Weekly summaries (hide if empty)
        if let data = viewModel.analyticsData, !data.weeklySummaries.isEmpty {
            WeeklySummarySection(summaries: data.weeklySummaries)
        }
    }
    
    // MARK: - Time Range Header (Sticky)
    private var timeRangeHeader: some View {
        VStack(spacing: 0) {
            Picker("Time Range", selection: Binding(
                get: { viewModel.selectedTimeRange },
                set: { newValue in
                    Task { await viewModel.changeTimeRange(to: newValue) }
                }
            )) {
                ForEach([AnalyticsTimeRange.today, .week, .month, .year], id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
        }
    }
    
    // MARK: - Game Filter Menu (Toolbar)
    private var gameFilterMenu: some View {
        Menu {
            Button {
                viewModel.selectGame(nil)
            } label: {
                Label("All Games", systemImage: viewModel.selectedGame == nil ? "checkmark" : "gamecontroller")
            }
            
            if !viewModel.availableGames.isEmpty {
                Divider()
                
                ForEach(viewModel.availableGames, id: \.id) { game in
                    Button {
                        viewModel.selectGame(game)
                    } label: {
                        Label(
                            game.displayName,
                            systemImage: viewModel.selectedGame?.id == game.id ? "checkmark" : (game.iconSystemName.isEmpty ? "gamecontroller" : game.iconSystemName)
                        )
                    }
                }
            }
        } label: {
            Image.safeSystemName(viewModel.selectedGame?.iconSystemName ?? "gamecontroller.fill", fallback: "gamecontroller.fill")
                .foregroundStyle(viewModel.selectedGame?.backgroundColor.color ?? .blue)
        }
    }

    // MARK: - CSV Export Helper
    private func exportCSV() {
        let csv = viewModel.exportCSV()
        guard !csv.isEmpty else { return }
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("streaksync-analytics.csv")
        try? csv.data(using: .utf8)?.write(to: tempURL)
        let av = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.rootViewController?
            .present(av, animated: true)
    }
    
    // MARK: - Legacy Implementation
    private var legacyAnalyticsView: some View {
        ScrollView {
            LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
                Section {
                    // Content with proper view identity
                    contentSection
                        .id("\(viewModel.selectedTimeRange.rawValue)-\(viewModel.selectedGame?.id.uuidString ?? "all")")
                        .padding(.horizontal, 16)
                } header: {
                    // Time range filter as sticky header
                    timeRangeHeader
                        .background(
                            StreakSyncColors.background(for: colorScheme)
                        )
                }
            }
            .padding(.bottom, 20)
        }
        .background(
            StreakSyncColors.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()
        )
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Game filter in toolbar (native iOS pattern)
                gameFilterMenu
            }
        }
        .refreshable {
            await viewModel.refreshAnalytics()
        }
        .onAppear {
            if !hasInitiallyAppeared {
                Task {
                    await viewModel.loadAnalytics()
                }
                hasInitiallyAppeared = true
            }
        }
    }
    
}

// MARK: - Overview Stats Section
struct OverviewStatsSection: View {
    let overview: AnalyticsOverview
    let analyticsService: AnalyticsService
    let timeRange: AnalyticsTimeRange
    let selectedGame: Game?
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingCompletionRateTooltip = false
    @State private var showingConsistencyTooltip = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                AnalyticsStatCard(
                    title: "Total Games",
                    value: "\(overview.totalGamesPlayed)",
                    icon: "gamecontroller.fill",
                    color: .blue
                )
                
                AnalyticsStatCardWithTooltip(
                    title: "Completion Rate",
                    value: overview.overallCompletionRate,
                    icon: "checkmark.circle.fill",
                    color: .green,
                    tooltip: "\(overview.totalGamesCompleted) of \(overview.totalGamesPlayed) completed",
                    showingTooltip: $showingCompletionRateTooltip
                )
                
                AnalyticsStatCardWithTooltip(
                    title: "Longest Streak",
                    value: "\(overview.longestCurrentStreak)",
                    icon: "flame.fill",
                    color: .orange,
                    tooltip: "Within selected period",
                    showingTooltip: .constant(false)
                )
                
                AnalyticsStatCardWithTooltip(
                    title: "Consistency",
                    value: overview.streakConsistencyPercentage,
                    icon: "calendar.badge.checkmark",
                    color: .purple,
                    tooltip: {
                        let consistencyDays = analyticsService.getConsistencyDays(for: timeRange, game: selectedGame)
                        return "\(consistencyDays.active) of \(consistencyDays.total) days active"
                    }(),
                    showingTooltip: $showingConsistencyTooltip
                )
            }
        }
        .animation(nil, value: timeRange) // prevent implicit animations on time-range switch
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Analytics Stat Card
struct AnalyticsStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image.safeSystemName(icon, fallback: "chart.bar")
                    .font(.title3)
                    .foregroundStyle(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        }
    }
}

// MARK: - Analytics Stat Card With Help Text
struct AnalyticsStatCardWithTooltip: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let tooltip: String
    @Binding var showingTooltip: Bool // Keep for compatibility but unused
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image.safeSystemName(icon, fallback: "chart.bar")
                    .font(.title3)
                    .foregroundStyle(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Inline help text instead of info button
                Text(tooltip)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        }
    }
}



// MARK: - At-Risk Today Section (simple MVP)
struct AtRiskTodaySection: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    
    private var atRiskGames: [Game] {
        appState.getGamesAtRisk()
    }
    
    var body: some View {
        if atRiskGames.isEmpty { return AnyView(EmptyView()) }
        
        let count = atRiskGames.count
        let title = count == 1 ? "Don't lose your streak" : "Don't lose your streaks"
        let names = atRiskGames.prefix(3).map { $0.displayName }.joined(separator: ", ")
        let subtitle = count == 1 ? names : (count <= 3 ? names : "\(names), and \(count - 2) more")
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image.safeSystemName("flame.fill", fallback: "flame")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Quick actions
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(atRiskGames, id: \.id) { game in
                            Button {
                                BrowserLauncher.shared.launchGame(game)
                            } label: {
                                HStack(spacing: 6) {
                                    Image.safeSystemName(game.iconSystemName, fallback: "gamecontroller")
                                    Text("Play \(game.displayName)")
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(game.backgroundColor.color.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
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
        )
    }
}


// MARK: - Game Deep Dive
struct GameDeepDiveSection: View {
    let gameAnalytics: GameAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Deep Dive")
                .font(.headline)
                .fontWeight(.semibold)
            
            switch gameAnalytics.game.name.lowercased() {
            case "wordle", "nerdle":
                WordleDeepDive(results: gameAnalytics.recentResults)
            case "pips":
                PipsDeepDive(results: gameAnalytics.recentResults)
            case "linkedinpinpoint":
                PinpointDeepDive(results: gameAnalytics.recentResults)
            case "strands":
                StrandsDeepDive(results: gameAnalytics.recentResults)
            default:
                EmptyView()
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Achievements Summary
struct AchievementsSummarySection: View {
    let analytics: AchievementAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievements")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                summaryPill(title: "Unlocked", value: "\(analytics.totalUnlocked)/\(analytics.totalAvailable)", color: .yellow)
                summaryPill(title: "Completion", value: analytics.completionPercentage, color: .green)
            }
            
            // Tier distribution chips
            if !analytics.tierDistribution.isEmpty {
                HStack(spacing: 8) {
                    ForEach(AchievementTier.allCases, id: \.self) { tier in
                        let count = analytics.tierDistribution[tier] ?? 0
                        if count > 0 {
                            HStack(spacing: 4) {
                                Image.safeSystemName(tier.iconSystemName, fallback: "trophy.fill")
                                Text("\(count)")
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(tier.color.opacity(0.15)))
                            .foregroundStyle(tier.color)
                        }
                    }
                }
            }
            
            // Recent unlocks
            if !analytics.recentUnlocks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Unlocks")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    ForEach(analytics.recentUnlocks, id: \.id) { unlock in
                        HStack(spacing: 8) {
                            Image.safeSystemName(unlock.tier.iconSystemName, fallback: "trophy.fill")
                                .foregroundStyle(unlock.tier.color)
                            Text(unlock.achievement.displayName)
                                .font(.caption)
                            Spacer()
                            Text(unlock.timestamp, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
    
    private func summaryPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title3).fontWeight(.bold).foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.08)))
    }
}

// MARK: - Next Actions Section
struct NextActionsSection: View {
    let actions: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What to do next")
                .font(.headline)
                .fontWeight(.semibold)
            ForEach(actions.prefix(3), id: \.self) { action in
                HStack(spacing: 8) {
                    Image.safeSystemName("bolt.fill", fallback: "bolt.fill").foregroundStyle(.yellow)
                    Text(action).font(.subheadline)
                    Spacer()
                }
                .padding(.vertical, 6)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
}

private struct WordleDeepDive: View {
    let results: [GameResult]
    
    private var guessDistribution: [Int: Int] {
        var dist: [Int: Int] = [:]
        for r in results {
            if let s = r.score { dist[s, default: 0] += 1 }
        }
        return dist
    }
    private var failRate: Double {
        let total = results.count
        guard total > 0 else { return 0 }
        let fails = results.filter { !$0.completed }.count
        return Double(fails) / Double(total)
    }
    private var averageGuesses: Double {
        let guesses = results.compactMap { $0.score }
        guard !guesses.isEmpty else { return 0 }
        return Double(guesses.reduce(0, +)) / Double(guesses.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: "Fail rate: %.0f%%", failRate * 100)).font(.caption)
            Text(String(format: "Average guesses: %.2f", averageGuesses)).font(.caption)
            HStack(spacing: 6) {
                ForEach((1...6), id: \.self) { g in
                    let count = guessDistribution[g] ?? 0
                    VStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.green)
                            .frame(width: 18, height: CGFloat(max(1, count)) * 6)
                        Text("\(g)").font(.caption2)
                    }
                }
            }
        }
    }
}

private struct PipsDeepDive: View {
    let results: [GameResult]
    
    private var easyTimes: [Int] { results.filter { $0.parsedData["difficulty"] == "Easy" }.compactMap { Int($0.parsedData["totalSeconds"] ?? "") } }
    private var mediumTimes: [Int] { results.filter { $0.parsedData["difficulty"] == "Medium" }.compactMap { Int($0.parsedData["totalSeconds"] ?? "") } }
    private var hardTimes: [Int] { results.filter { $0.parsedData["difficulty"] == "Hard" }.compactMap { Int($0.parsedData["totalSeconds"] ?? "") } }
    
    private func format(_ seconds: Int?) -> String {
        guard let s = seconds else { return "—" }
        return String(format: "%d:%02d", s / 60, s % 60)
    }
    private func avg(_ arr: [Int]) -> Int? { guard !arr.isEmpty else { return nil }; return arr.reduce(0, +) / arr.count }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Easy Best: \(format(easyTimes.min()))  Avg: \(format(avg(easyTimes)))").font(.caption)
            }
            HStack {
                Text("Medium Best: \(format(mediumTimes.min()))  Avg: \(format(avg(mediumTimes)))").font(.caption)
            }
            HStack {
                Text("Hard Best: \(format(hardTimes.min()))  Avg: \(format(avg(hardTimes)))").font(.caption)
            }
        }
    }
}

private struct PinpointDeepDive: View {
    let results: [GameResult]
    private var guessDistribution: [Int: Int] {
        var d: [Int: Int] = [:]
        for r in results { if let s = r.score { d[s, default: 0] += 1 } }
        return d
    }
    var body: some View {
        HStack(spacing: 6) {
            ForEach((1...5), id: \.self) { g in
                let count = guessDistribution[g] ?? 0
                VStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.blue)
                        .frame(width: 18, height: CGFloat(max(1, count)) * 6)
                    Text("\(g)").font(.caption2)
                }
            }
        }
    }
}

private struct StrandsDeepDive: View {
    let results: [GameResult]
    private var hintsDistribution: [Int: Int] {
        var d: [Int: Int] = [:]
        for r in results { if let s = r.score { d[s, default: 0] += 1 } }
        return d
    }
    var body: some View {
        HStack(spacing: 6) {
            ForEach((0...10), id: \.self) { h in
                let count = hintsDistribution[h] ?? 0
                VStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.purple)
                        .frame(width: 12, height: CGFloat(max(1, count)) * 6)
                    Text("\(h)").font(.caption2)
                }
            }
        }
    }
}
// MARK: - Weekly Summary Section
struct WeeklySummarySection: View {
    let summaries: [WeeklySummary]
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Recap")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 8) {
                ForEach(summaries.prefix(4), id: \.weekStart) { summary in
                    WeeklySummaryRow(summary: summary)
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

private struct WeeklySummaryRow: View {
    let summary: WeeklySummary
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.weekDisplayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(String(format: "%.0f%% completion", summary.completionRate * 100))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 12) {
                Label("\(summary.totalGamesPlayed)", systemImage: "gamecontroller.fill")
                    .font(.caption)
                Label("\(summary.longestStreak)", systemImage: "flame.fill")
                    .font(.caption)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.05))
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AnalyticsDashboardView(analyticsService: AnalyticsService(appState: AppState()))
    }
}
