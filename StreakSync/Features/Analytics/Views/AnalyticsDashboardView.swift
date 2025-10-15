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
    
    // MARK: - Content Section
    @ViewBuilder
    private var contentSection: some View {
        // Overview stats
        if let overview = viewModel.overview {
            OverviewStatsSection(overview: overview, analyticsService: viewModel.analyticsService, timeRange: viewModel.selectedTimeRange, selectedGame: viewModel.selectedGame)
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
        }
        
        // Personal bests
        if !viewModel.personalBests.isEmpty {
            PersonalBestsSection(personalBests: viewModel.personalBests)
        }
        
        // Most active games
        if !viewModel.getMostActiveGames().isEmpty {
            MostActiveGamesSection(activeGames: viewModel.getMostActiveGames())
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
                
                AnalyticsStatCard(
                    title: "Longest Streak",
                    value: "\(overview.longestCurrentStreak)",
                    icon: "flame.fill",
                    color: .orange
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



// MARK: - Preview
#Preview {
    NavigationStack {
        AnalyticsDashboardView(analyticsService: AnalyticsService(appState: AppState()))
    }
}
