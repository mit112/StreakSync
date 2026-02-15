//
//  OverviewStatsSection.swift
//  StreakSync
//
//  Overview statistics grid with stat cards for the analytics dashboard.
//

import SwiftUI

// MARK: - Overview Stats Section
struct OverviewStatsSection: View {
    let overview: AnalyticsOverview
    let analyticsService: AnalyticsService
    let timeRange: AnalyticsTimeRange
    let selectedGame: Game?
    @Environment(\.colorScheme) private var colorScheme

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
                    tooltip: "\(overview.totalGamesCompleted) of \(overview.totalGamesPlayed) completed"
                )

                AnalyticsStatCardWithTooltip(
                    title: "Longest Streak",
                    value: "\(overview.longestCurrentStreak)",
                    icon: "flame.fill",
                    color: .orange,
                    tooltip: "Within selected period"
                )

                AnalyticsStatCardWithTooltip(
                    title: "Consistency",
                    value: overview.streakConsistencyPercentage,
                    icon: "calendar.badge.checkmark",
                    color: .purple,
                    tooltip: {
                        let consistencyDays = analyticsService.getConsistencyDays(for: timeRange, game: selectedGame)
                        return "\(consistencyDays.active) of \(consistencyDays.total) days active"
                    }()
                )
            }
        }
        .animation(nil, value: timeRange)
        .padding()
        .cardStyle()
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

// MARK: - Analytics Stat Card With Tooltip
struct AnalyticsStatCardWithTooltip: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let tooltip: String

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
