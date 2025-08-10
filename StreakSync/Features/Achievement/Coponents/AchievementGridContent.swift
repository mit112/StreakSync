//
//  AchievementGridContent.swift
//  StreakSync
//
//  Achievement grid content for displaying achievement cards
//

import SwiftUI

struct AchievementGridContent: View {
    let achievements: [TieredAchievement]
    let hasAppeared: Bool
    @EnvironmentObject private var coordinator: NavigationCoordinator
    
    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 16
        ) {
            ForEach(Array(achievements.enumerated()), id: \.element.id) { index, achievement in
                TieredAchievementCard(
                    achievement: achievement,
                    onTap: {
                        coordinator.presentSheet(.tieredAchievementDetail(achievement))
                    }
                )
                .modifier(InitialAnimationModifier(
                    hasAppeared: hasAppeared,
                    index: index + 2,
                    totalCount: achievements.count + 2
                ))
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AchievementGridContent(
        achievements: [],
        hasAppeared: true
    )
    .environmentObject(NavigationCoordinator())
    .padding()
}
