//
//  TieredAchievementsGridView.swift
//  StreakSync
//
//  Main achievements grid with progress header, category filter, and achievement cards
//

import SwiftUI

struct TieredAchievementsGridView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @State private var hasAppeared = false
    @State private var selectedCategory: AchievementCategory?
    @State private var scrollPosition = ScrollPosition()
    @State private var visibleAchievements: Set<UUID> = []
    
    // MARK: - Computed Properties
    private var filteredAchievements: [TieredAchievement] {
        if let category = selectedCategory {
            return appState.tieredAchievements.filter { $0.category == category }
        }
        return appState.tieredAchievements
    }
    
    private var unlockedCount: Int {
        appState.tieredAchievements.filter { $0.isUnlocked }.count
    }
    
    private var totalTiers: Int {
        appState.tieredAchievements.reduce(0) { $0 + $1.progress.tierUnlockDates.count }
    }
    
    private var completionPercentage: Int {
        let total = appState.tieredAchievements.reduce(0) { $0 + $1.requirements.count }
        guard total > 0 else { return 0 }
        return Int((Double(totalTiers) / Double(total)) * 100)
    }
    
    private var availableCategories: [AchievementCategory] {
        let categories = Set(appState.tieredAchievements.map { $0.category })
        return AchievementCategory.allCases.filter { categories.contains($0) }
    }
    
    var body: some View {
        if appState.isGuestMode {
            guestModeView
        } else {
            achievementsContent
        }
    }
    
    // MARK: - Guest Mode
    private var guestModeView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text("Achievements Hidden in Guest Mode")
                    .font(.headline)
                Text("Guest Mode lets someone try StreakSync without affecting your data. Achievements are only visible when you're using your own account.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Main Content
    private var achievementsContent: some View {
        ScrollView {
            LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
                progressHeader
                    .scrollTransition { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.8)
                            .scaleEffect(phase.isIdentity ? 1 : 0.95)
                    }
                
                categoryFilter
                    .scrollTransition { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.9)
                            .scaleEffect(phase.isIdentity ? 1 : 0.98)
                    }
                
                achievementsGrid
            }
            .padding()
        }
        .scrollPosition($scrollPosition)
        .scrollBounceBehavior(.automatic)
        .scrollIndicators(.automatic, axes: .vertical)
        .scrollDismissesKeyboard(.interactively)
        .background {
            Rectangle()
                .fill(.background)
                .overlay {
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.03), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
                .ignoresSafeArea()
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.large)
        .contentTransition(.numericText())
        .onAppear {
            withAnimation(.smooth(duration: 0.6)) {
                hasAppeared = true
            }
        }
    }
    
    // MARK: - Progress Header
    private var progressHeader: some View {
        HStack(spacing: 12) {
            AchievementStatCard(icon: "trophy.fill", value: "\(unlockedCount)", label: "Unlocked", accentColor: .yellow)
            AchievementStatCard(icon: "star.fill", value: "\(totalTiers)", label: "Total Tiers", accentColor: .purple)
            AchievementStatCard(icon: "percent", value: "\(completionPercentage)%", label: "Complete", accentColor: .blue)
        }
        .modifier(AchievementHeaderAnimation(hasAppeared: hasAppeared))
    }
    
    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                AchievementCategoryChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    action: { withAnimation(.smooth) { selectedCategory = nil } }
                )
                
                ForEach(availableCategories, id: \.self) { category in
                    AchievementCategoryChip(
                        title: category.displayName,
                        icon: category.baseIconSystemName,
                        isSelected: selectedCategory == category,
                        action: { withAnimation(.smooth) { selectedCategory = category } }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Achievements Grid
    private var achievementsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
            spacing: 16
        ) {
            ForEach(filteredAchievements) { achievement in
                AchievementCard(
                    achievement: achievement,
                    onTap: { coordinator.presentSheet(.tieredAchievementDetail(achievement)) }
                )
                .scrollTransition { content, phase in
                    content
                        .scaleEffect(x: phase.isIdentity ? 1 : 0.96, y: phase.isIdentity ? 1 : 0.96)
                        .opacity(phase.isIdentity ? 1 : 0.8)
                }
                .onScrollVisibilityChange { isVisible in
                    if isVisible { visibleAchievements.insert(achievement.id) }
                }
            }
        }
        .animation(.smooth, value: filteredAchievements)
    }
}

#Preview {
    NavigationStack {
        TieredAchievementsGridView()
            .environment(AppState())
            .environmentObject(NavigationCoordinator())
    }
}
