//
//  StreakTrendsDetailView.swift
//  StreakSync
//
//  Detailed streak trends analysis with interactive chart and insights
//

import SwiftUI

// MARK: - Streak Trends Detail View
struct StreakTrendsDetailView: View {
    let analyticsService: AnalyticsService
    let timeRange: AnalyticsTimeRange
    let selectedGame: Game?

    @Environment(\.colorScheme) private var colorScheme
    @State private var trends: [StreakTrendPoint] = []
    @State private var rangeResults: [GameResult] = []
    @State private var rangeGames: [Game] = []
    @State private var selectedDate: Date?
    @State private var isLoading = true

    private var gameDisplayName: String {
        selectedGame?.displayName ?? "All Games"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                StreakTrendsDetailChartSection(
                    trends: trends,
                    rangeResults: rangeResults,
                    rangeGames: rangeGames,
                    isLoading: isLoading,
                    timeRange: timeRange,
                    gameDisplayName: gameDisplayName,
                    selectedDate: $selectedDate
                )

                if !trends.isEmpty {
                    StreakTrendsInsightsSection(trends: trends)
                }

                StreakTrendsDailySection(
                    trends: trends,
                    selectedDate: $selectedDate
                )
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

    // MARK: - Data Loading
    private func loadData() async {
        isLoading = true
        let data = await analyticsService.getAnalyticsData(for: timeRange, game: selectedGame)
        trends = data.streakTrends
        rangeResults = data.overview.recentActivity
        rangeGames = data.gameAnalytics.map { $0.game }
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
    }
}
