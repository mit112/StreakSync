//
//  AchievementProgressHeader.swift
//  StreakSync
//
//  Progress overview header for achievements
//

import SwiftUI

struct AchievementProgressHeader: View {
    let unlockedCount: Int
    let totalTiers: Int
    let completionPercentage: Int
    let hasAppeared: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                // Total unlocked
                StatCard(
                    icon: "trophy.fill",
                    value: "\(unlockedCount)",
                    label: "Unlocked",
                    gradient: LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Total tiers
                StatCard(
                    icon: "star.fill",
                    value: "\(totalTiers)",
                    label: "Total Tiers",
                    gradient: LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Completion percentage
                StatCard(
                    icon: "percent",
                    value: "\(completionPercentage)%",
                    label: "Complete",
                    gradient: LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .modifier(InitialAnimationModifier(
                hasAppeared: hasAppeared,
                index: 0,
                totalCount: 10
            ))
        }
    }
}

// MARK: - Preview
#Preview {
    AchievementProgressHeader(
        unlockedCount: 12,
        totalTiers: 36,
        completionPercentage: 75,
        hasAppeared: true
    )
    .padding()
}
