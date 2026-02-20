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

    var body: some View {
        if hasAnyActivity {
            HStack(spacing: 0) {
                // Flame + longest streak
                heroMetric(
                    icon: "flame.fill",
                    iconColor: .orange,
                    value: "\(longestCurrentStreak)",
                    label: longestCurrentStreak == 1 ? "day streak" : "day streak"
                )

                Divider()
                    .frame(height: 32)
                    .padding(.horizontal, 4)

                // Active streaks
                heroMetric(
                    icon: "gamecontroller.fill",
                    iconColor: .accentColor,
                    value: "\(activeStreakCount)",
                    label: activeStreakCount == 1 ? "active" : "active"
                )

                if atRiskCount > 0 {
                    Divider()
                        .frame(height: 32)
                        .padding(.horizontal, 4)

                    // At risk
                    heroMetric(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .yellow,
                        value: "\(atRiskCount)",
                        label: "at risk"
                    )
                }

                if completedTodayCount > 0 {
                    Divider()
                        .frame(height: 32)
                        .padding(.horizontal, 4)

                    // Done today
                    heroMetric(
                        icon: "checkmark.circle.fill",
                        iconColor: .green,
                        value: "\(completedTodayCount)",
                        label: "today"
                    )
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .strokeBorder(Color(.separator), lineWidth: 0.5)
            }
        }
    }

    private func heroMetric(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(value)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 20) {
        StreakSummaryHero(activeStreakCount: 3, longestCurrentStreak: 14, atRiskCount: 2, completedTodayCount: 1)
        StreakSummaryHero(activeStreakCount: 1, longestCurrentStreak: 1, atRiskCount: 0, completedTodayCount: 0)
    }
    .padding()
}