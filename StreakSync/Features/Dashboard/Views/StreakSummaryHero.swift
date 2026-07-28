//
//  StreakSummaryHero.swift
//  StreakSync
//
//  Compact streak summary displayed at the top of the Home tab.
//

import SwiftUI

struct StreakSummaryHero: View {
    let activeStreakCount: Int
    let longestCurrentStreak: Int
    let atRiskCount: Int
    let completedTodayCount: Int

    @Environment(\.colorScheme) private var colorScheme

    private var hasAnyActivity: Bool {
        activeStreakCount > 0 || longestCurrentStreak > 0
    }

    private var metrics: [Metric] {
        var metrics = [
            Metric(
                icon: "flame.fill",
                value: "\(longestCurrentStreak)",
                label: "day streak",
                tint: StreakSyncBrand.streak,
                isPrimary: true
            ),
            Metric(
                icon: "gamecontroller.fill",
                value: "\(activeStreakCount)",
                label: "active",
                tint: .secondary,
                isPrimary: false
            )
        ]

        if atRiskCount > 0 {
            metrics.append(
                Metric(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(atRiskCount)",
                    label: "at risk",
                    tint: .orange,
                    isPrimary: false
                )
            )
        }

        if completedTodayCount > 0 {
            metrics.append(
                Metric(
                    icon: "checkmark.circle.fill",
                    value: "\(completedTodayCount)",
                    label: "today",
                    tint: StreakSyncBrand.success,
                    isPrimary: false
                )
            )
        }

        return metrics
    }

    private var metricRows: [[Metric]] {
        stride(from: 0, to: metrics.count, by: 2).map { startIndex in
            Array(metrics[startIndex..<min(startIndex + 2, metrics.count)])
        }
    }

    var body: some View {
        if hasAnyActivity {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    horizontalMetrics
                }

                Grid(horizontalSpacing: Spacing.lg, verticalSpacing: Spacing.md) {
                    gridMetricRows
                }

                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(metrics) { metric in
                        metricView(metric)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    // Use a brighter surface so the hero stands out against the grouped dashboard background.
                    .fill(Color(.systemBackground))
                    .strokeBorder(colorScheme == .dark ? Color(.separator) : Color.black.opacity(0.08), lineWidth: 0.75)
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.18 : 0.08),
                        radius: colorScheme == .dark ? 8 : 10,
                        x: 0,
                        y: colorScheme == .dark ? 4 : 4
                    )
            }
        }
    }

    @ViewBuilder
    private var horizontalMetrics: some View {
        ForEach(metrics.indices, id: \.self) { index in
            if index > 0 {
                Divider()
                    .frame(height: 32)
                    .padding(.horizontal, 4)
            }

            metricView(metrics[index])
        }
    }

    @ViewBuilder
    private var gridMetricRows: some View {
        ForEach(metricRows.indices, id: \.self) { rowIndex in
            GridRow {
                ForEach(metricRows[rowIndex]) { metric in
                    metricView(metric)
                }

                if metricRows[rowIndex].count == 1 {
                    Color.clear
                }
            }
        }
    }

    private func metricView(_ metric: Metric) -> some View {
        StreakSummaryMetricView(
            icon: metric.icon,
            value: metric.value,
            label: metric.label,
            tint: metric.tint,
            isPrimary: metric.isPrimary
        )
    }

    private struct Metric: Identifiable {
        let icon: String
        let value: String
        let label: String
        let tint: Color
        let isPrimary: Bool

        var id: String { icon }
    }
}

#Preview {
    VStack(spacing: 20) {
        StreakSummaryHero(activeStreakCount: 3, longestCurrentStreak: 14, atRiskCount: 2, completedTodayCount: 1)
        StreakSummaryHero(activeStreakCount: 1, longestCurrentStreak: 1, atRiskCount: 0, completedTodayCount: 0)
    }
    .padding()
}
