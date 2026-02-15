//
//  WeeklySummarySection.swift
//  StreakSync
//
//  Weekly recap section for analytics dashboard.
//

import SwiftUI

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
        .cardStyle()
    }
}

// MARK: - Weekly Summary Row
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
