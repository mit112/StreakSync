//
//  DashboardAchievementsSection.swift
//  StreakSync
//
//  Recent achievements section for dashboard
//

import SwiftUI

// MARK: - Dashboard Achievements Section
struct DashboardAchievementsSection: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationCoordinator.self) private var coordinator
    
    private var recentAchievements: [Achievement] {
        appState.unlockedAchievements
            .sorted { first, second in
                let firstDate = first.unlockedDate ?? .distantPast
                let secondDate = second.unlockedDate ?? .distantPast
                return firstDate > secondDate
            }
            .prefix(2)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: NSLocalizedString("dashboard.recent_achievements", comment: "Recent Achievements"),
                icon: "trophy.fill",
                action: {
                    coordinator.navigateTo(.achievements)
                }
            )
            .accessibilityAddTraits(.isHeader)
            
            if recentAchievements.isEmpty {
                EmptyAchievementsCard()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recentAchievements) { achievement in
                        AchievementRowView(achievement: achievement)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recent Achievements")
    }
}

// MARK: - Empty Achievements Card
private struct EmptyAchievementsCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.title2)
                .foregroundStyle(.tertiary)
            
            Text("No achievements yet")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            
            Text("Complete games to unlock achievements!")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview
#Preview {
    DashboardAchievementsSection()
        .environment(AppState())
        .environment(NavigationCoordinator())
        .padding()
}
