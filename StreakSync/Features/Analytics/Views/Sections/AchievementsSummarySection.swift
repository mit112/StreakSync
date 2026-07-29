//
//  AchievementsSummarySection.swift
//  StreakSync
//
//  Achievements summary and next actions sections for analytics dashboard.
//

import SwiftUI

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
        .cardStyle()
    }

    private func summaryPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Number stays neutral; hue only tints the pill chrome (DESIGN_AUDIT §3-C).
            Text(value).font(.title3).fontWeight(.bold).foregroundStyle(.primary)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CornerRadius.control).fill(color.opacity(0.08)))
    }
}
