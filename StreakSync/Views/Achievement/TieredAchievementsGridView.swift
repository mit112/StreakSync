//
//  TieredAchievementsGridView.swift
//  StreakSync
//
//  Grid view for displaying tiered achievements
//

import SwiftUI

// MARK: - Tiered Achievements Grid View
struct TieredAchievementsGridView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @State private var hasAppeared = false
    @State private var selectedCategory: AchievementCategory?
    
    private var groupedAchievements: [(category: AchievementCategory, achievements: [TieredAchievement])] {
        Dictionary(grouping: appState.tieredAchievements) { $0.category }
            .map { (category: $0.key, achievements: $0.value) }
            .sorted { $0.category.displayName < $1.category.displayName }
    }
    
    private var filteredAchievements: [TieredAchievement] {
        if let category = selectedCategory {
            return appState.tieredAchievements.filter { $0.category == category }
        }
        return appState.tieredAchievements
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with progress overview
                progressHeader
                
                // Category filter
                categoryFilter
                
                // Achievements grid
                achievementsGrid
            }
            .padding()
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                hasAppeared = true
            }
        }
    }
    
    // MARK: - Progress Header
    private var progressHeader: some View {
        VStack(spacing: 16) {
            // Overall progress - Fixed spacing
            HStack(spacing: 12) { // Reduced from 20
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
            .modifier(InitialAnimationModifier(hasAppeared: hasAppeared, index: 0, totalCount: 10))
        }
    }
    
    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All categories
                CategoryChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )
                
                // Individual categories
                ForEach(AchievementCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.displayName,
                        icon: category.baseIconSystemName,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .modifier(InitialAnimationModifier(hasAppeared: hasAppeared, index: 1, totalCount: 10))
    }
    
    // MARK: - Achievements Grid
    private var achievementsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 16
        ) {
            ForEach(Array(filteredAchievements.enumerated()), id: \.element.id) { index, achievement in
                TieredAchievementCard(
                    achievement: achievement,
                    onTap: {
                        // TODO: Uncomment when NavigationCoordinator is updated with tieredAchievementDetail case
                        coordinator.presentSheet(.tieredAchievementDetail(achievement))
                    }
                )
                .modifier(InitialAnimationModifier(
                    hasAppeared: hasAppeared,
                    index: index + 2,
                    totalCount: filteredAchievements.count + 2
                ))
            }
        }
    }
    
    // MARK: - Computed Properties
    private var unlockedCount: Int {
        appState.tieredAchievements.filter { $0.isUnlocked }.count
    }
    
    private var totalTiers: Int {
        appState.tieredAchievements.reduce(0) { total, achievement in
            total + (achievement.progress.tierUnlockDates.count)
        }
    }
    
    private var completionPercentage: Int {
        let totalPossibleTiers = appState.tieredAchievements.reduce(0) { total, achievement in
            total + achievement.requirements.count
        }
        guard totalPossibleTiers > 0 else { return 0 }
        return Int((Double(totalTiers) / Double(totalPossibleTiers)) * 100)
    }
}

// MARK: - Category Chip
private struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(.systemGray5))
            )
        }
        .pressable(scaleAmount: 0.9)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        TieredAchievementsGridView()
            .environment(AppState())
            .environmentObject(NavigationCoordinator())
    }
}
