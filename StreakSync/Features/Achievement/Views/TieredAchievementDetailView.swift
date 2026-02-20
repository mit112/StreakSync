//
//  TieredAchievementDetailView.swift
//  StreakSync
//
//  Detail sheet for viewing achievement progress and tier requirements
//

import SwiftUI

struct TieredAchievementDetailView: View {
    let achievement: TieredAchievement
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTier: AchievementTier?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                achievementHeader
                progressSection
                tierProgressionSection
                
                if !achievement.isUnlocked {
                    tipsSection
                }
            }
            .padding()
        }
        .navigationTitle(achievement.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Achievement Header
    private var achievementHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                if achievement.isUnlocked {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    achievement.displayColor.opacity(0.3),
                                    achievement.displayColor.opacity(0.05)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                }
                
                Circle()
                    .fill(
                        achievement.isUnlocked
                        ? achievement.displayColor.opacity(0.18)
                        : Color(.quaternarySystemFill)
                    )
                    .frame(width: 80, height: 80)
                    .overlay {
                        Circle()
                            .stroke(
                                achievement.isUnlocked
                                ? achievement.displayColor.opacity(0.4)
                                : Color(.separator).opacity(0.3),
                                lineWidth: 1
                            )
                    }
                
                Image.safeSystemName(achievement.iconSystemName, fallback: "star.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        achievement.isUnlocked
                        ? achievement.displayColor
                        : Color(.systemGray3)
                    )
            }
            
            Text(achievement.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 4) {
                Text("Current Progress")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(achievement.progressDescription)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }
        }
    }
    
    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: 16) {
            Text("Progress Overview")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    
                    HStack(spacing: 2) {
                        ForEach(achievement.requirements, id: \.tier) { requirement in
                            let isUnlocked = achievement.progress.tierUnlockDates[requirement.tier] != nil
                            let isCurrent = achievement.progress.currentTier == requirement.tier
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    isUnlocked ? requirement.tier.color :
                                    isCurrent ? requirement.tier.color.opacity(0.5) :
                                    Color(.systemGray4)
                                )
                                .frame(width: geometry.size.width / CGFloat(achievement.requirements.count) - 2)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedTier = requirement.tier
                                    }
                                }
                        }
                    }
                    .frame(height: 12)
                }
            }
            .frame(height: 12)
        }
    }
    
    // MARK: - Tier Progression Section
    private var tierProgressionSection: some View {
        VStack(spacing: 12) {
            Text("Tier Requirements")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(achievement.requirements, id: \.tier) { requirement in
                TierRequirementRow(
                    requirement: requirement,
                    progress: achievement.progress,
                    isExpanded: selectedTier == requirement.tier
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTier = selectedTier == requirement.tier ? nil : requirement.tier
                    }
                }
            }
        }
    }
    
    // MARK: - Tips Section
    private var tipsSection: some View {
        VStack(spacing: 12) {
            Text("How to Progress")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tipsForCategory(achievement.category), id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                        
                        Text(tip)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .strokeBorder(Color(.separator), lineWidth: 0.5)
            )
        }
    }
    
    private func tipsForCategory(_ category: AchievementCategory) -> [String] {
        switch category {
        case .streakMaster:
            return [
                "Play the same game every day to build your streak",
                "Set a daily reminder to maintain consistency",
                "Missing one day will reset your streak to zero"
            ]
        case .gameCollector:
            return [
                "Try playing different games each day",
                "Explore all available game categories",
                "Every game counts toward your total"
            ]
        case .perfectionist:
            return [
                "Focus on accuracy over speed",
                "Learn from your mistakes in each game",
                "Successful completions count toward this achievement"
            ]
        case .dailyDevotee:
            return [
                "Play at least one game every day",
                "Any game counts toward your daily streak",
                "Consistency is key for this achievement"
            ]
        case .varietyPlayer:
            return [
                "Play different games over time",
                "Try games from different categories",
                "The more variety, the faster you progress"
            ]
        case .speedDemon:
            return [
                "Complete games with minimal attempts",
                "Focus on first-try successes",
                "Quick wins count more toward higher tiers"
            ]
        case .earlyBird:
            return [
                "Play games in the early morning hours",
                "Before 8 AM counts as early bird time",
                "Earlier times unlock higher tiers faster"
            ]
        case .nightOwl:
            return [
                "Play games late at night",
                "After 10 PM counts as night owl time",
                "Later times unlock higher tiers faster"
            ]
        case .comebackChampion:
            return [
                "Rebuild streaks after they break",
                "The longer the new streak, the higher the tier",
                "Shows resilience and persistence"
            ]
        case .marathonRunner:
            return [
                "Stay active over extended periods",
                "Total days with activity count",
                "Long-term consistency is rewarded"
            ]
        }
    }
}
