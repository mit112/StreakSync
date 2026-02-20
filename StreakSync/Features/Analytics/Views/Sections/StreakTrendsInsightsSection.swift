//
//  StreakTrendsInsightsSection.swift
//  StreakSync
//
//  Insights grid showing peak period, average streaks, productivity, and consistency.
//

import SwiftUI

struct StreakTrendsInsightsSection: View {
    let trends: [StreakTrendPoint]

    var body: some View {
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
        .cardStyle()
    }

    // MARK: - Insight Card

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
                .fill(Color(.secondarySystemGroupedBackground))
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        }
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
}
