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
                // Flame + longest streak — the hero metric. Flame keeps the
                // streak-fire orange (§3-C); the number is bumped for primacy (§5.1).
                heroMetric(
                    icon: "flame.fill",
                    iconColor: .orange,
                    value: "\(longestCurrentStreak)",
                    label: "day streak",
                    valueFont: .title.weight(.bold).monospacedDigit()
                )

                Divider()
                    .frame(height: 32)
                    .padding(.horizontal, 4)

                // Active streaks — neutral icon so the bar isn't four competing hues (§5.1).
                heroMetric(
                    icon: "gamecontroller.fill",
                    iconColor: .secondary,
                    value: "\(activeStreakCount)",
                    label: "active"
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

    private func heroMetric(
        icon: String,
        iconColor: Color,
        value: String,
        label: String,
        valueFont: Font = .title2.weight(.bold).monospacedDigit()
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iconColor)
                Text(value)
                    .font(valueFont)
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

#Preview {
    VStack(spacing: 20) {
        StreakSummaryHero(activeStreakCount: 3, longestCurrentStreak: 14, atRiskCount: 2, completedTodayCount: 1)
        StreakSummaryHero(activeStreakCount: 1, longestCurrentStreak: 1, atRiskCount: 0, completedTodayCount: 0)
    }
    .padding()
}
