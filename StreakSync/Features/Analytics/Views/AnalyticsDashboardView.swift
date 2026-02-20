//
//  AnalyticsDashboardView.swift
//  StreakSync
//
//  Main analytics dashboard with comprehensive statistics and charts.
//  Single implementation with iOS 26 enhancements applied conditionally.
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

    // MARK: - Body

    var body: some View {
        analyticsScrollView
            .background { pageBackground }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { analyticsToolbar }
            .refreshable { await viewModel.refreshAnalytics() }
            .modifier(AnalyticsDataRefreshModifier(viewModel: viewModel))
            .onAppear {
                if !hasInitiallyAppeared {
                    Task { await viewModel.loadAnalytics() }
                    hasInitiallyAppeared = true
                }
            }
    }

    // MARK: - Scroll View

    @ViewBuilder
    private var analyticsScrollView: some View {
        let scroll = ScrollView {
            LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
                Section {
                    if viewModel.isLoading && !viewModel.hasData {
                        // Initial load — no data yet
                        loadingPlaceholder
                            .padding(.horizontal, 16)
                    } else {
                        contentSection
                            .id("\(viewModel.selectedTimeRange.rawValue)-\(viewModel.selectedGame?.id.uuidString ?? "all")")
                            .padding(.horizontal, 16)
                            .opacity(viewModel.isLoading ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
                    }
                } header: {
                    timeRangeHeader
                        .background(Color(.systemGroupedBackground))
                }
            }
            .padding(.bottom, 20)
        }

        scroll.scrollBounceBehavior(.automatic)
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading analytics…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    @ViewBuilder
    private var pageBackground: some View {
        Color(.systemGroupedBackground)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var analyticsToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack {
                ShareLink(
                    item: viewModel.exportCSV(),
                    preview: SharePreview("StreakSync Analytics")
                ) {
                    Image.safeSystemName("square.and.arrow.up", fallback: "square.and.arrow.up")
                }
                .disabled(!viewModel.hasData)
                gameFilterMenu
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

}

// MARK: - Data Refresh Modifier (iOS 26 notification listeners)

/// On iOS 26, listens for data change notifications and refreshes analytics.
/// On pre-iOS 26 this is a no-op (legacy didn't have these listeners).
private struct AnalyticsDataRefreshModifier: ViewModifier {
    @ObservedObject var viewModel: AnalyticsViewModel

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .appGameDataUpdated)) { _ in
                Task { @MainActor in await viewModel.refreshAnalytics() }
            }
    }
}
