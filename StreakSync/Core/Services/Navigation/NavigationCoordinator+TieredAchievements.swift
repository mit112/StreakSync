//
//  NavigationCoordinator+TieredAchievements.swift
//  StreakSync
//
//  Extension to add tiered achievement navigation support
//
import SwiftUI

// MARK: - Navigation Extension for Tiered Achievements
extension NavigationCoordinator {
    
    // This method should be added to your NavigationCoordinator
    @ViewBuilder
    func tieredAchievementDetailSheet(for achievement: TieredAchievement) -> some View {
        NavigationStack {
            TieredAchievementDetailView(achievement: achievement)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            self.dismissSheet()  // ADD 'self.' here
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
// MARK: - Tiered Achievement Detail View
struct TieredAchievementDetailView: View {
    let achievement: TieredAchievement
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTier: AchievementTier?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Achievement header
                achievementHeader
                
                // Progress visualization
                progressSection
                
                // Tier progression
                tierProgressionSection
                
                // Tips section
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
            // Icon with tier color
            ZStack {
                Circle()
                    .fill(achievement.displayColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: achievement.iconSystemName)
                    .font(.system(size: 36))
                    .foregroundStyle(achievement.displayColor)
            }
            
//            // Current tier badge
//            if let currentTier = achievement.progress.currentTier {
//                TierBadge(tier: currentTier)
//                    .scaleEffect(1.2)
//            }
            
            // Description
            Text(achievement.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            // Current progress
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
            
            // Visual progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    
                    // Progress segments for each tier
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
                    .fill(Color(.systemGray6))
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
                "Play multiple different games in a single day",
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

// MARK: - Tier Requirement Row
private struct TierRequirementRow: View {
    let requirement: TierRequirement
    let progress: AchievementProgress
    let isExpanded: Bool
    
    private var isUnlocked: Bool {
        progress.tierUnlockDates[requirement.tier] != nil
    }
    
    private var progressToThisTier: Double {
        let currentValue = Double(progress.currentValue)
        let threshold = Double(requirement.threshold)
        return min(currentValue / threshold, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Tier icon
                Image(systemName: requirement.tier.iconSystemName)
                    .font(.title3)
                    .foregroundStyle(isUnlocked ? requirement.tier.color : .gray)
                    .frame(width: 24)
                
                // Tier info
                VStack(alignment: .leading, spacing: 2) {
                    Text(requirement.tier.displayName)
                        .font(.subheadline.weight(.medium))
                    
                    if isUnlocked, let unlockDate = progress.tierUnlockDates[requirement.tier] {
                        Text("Unlocked \(unlockDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Requires \(requirement.threshold)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Progress indicator
                if isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                } else {
                    CircularProgressView(
                        progress: progressToThisTier,
                        centerText: "\(progress.currentValue)/\(requirement.threshold)"
                    )
                    .frame(width: 36, height: 36)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isUnlocked ? requirement.tier.color.opacity(0.1) : Color(.systemGray6))
            )
            
            // Expanded details
            if isExpanded && !isUnlocked {
                HStack {
                    Text("Progress: \(progress.currentValue) / \(requirement.threshold)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(progressToThisTier * 100))%")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(requirement.tier.color)
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Circular Progress View
private struct CircularProgressView: View {
    let progress: Double
    let centerText: String?
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            
            Text(centerText ?? "\(Int(progress * 100))%")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
