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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var hasAppeared = false
    @State private var selectedCategory: AchievementCategory?
    @State private var scrollPosition = ScrollPosition()
    @State private var visibleAchievements: Set<UUID> = []
    @State private var selectedAchievement: TieredAchievement?
    
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

    private var totalAchievements: Int {
        appState.tieredAchievements.count
    }

    /// Completion = achievements unlocked / total, matching the Analytics tab
    /// (DESIGN_AUDIT §4.8). The old "tiers dated / total requirements" produced a
    /// different denominator (18% here vs 90% in Analytics for the same account).
    private var completionPercentage: Int {
        guard totalAchievements > 0 else { return 0 }
        // Round (not truncate) so this matches the Analytics tab's "%.0f" rendering
        // of the same ratio exactly — round-half-to-even mirrors printf's default.
        return Int((Double(unlockedCount) / Double(totalAchievements) * 100).rounded(.toNearestOrEven))
    }

    /// Highest tier reached across all achievements, for the summary header.
    private var highestTierName: String {
        appState.tieredAchievements
            .compactMap { $0.progress.currentTier }
            .max { $0.rawValue < $1.rawValue }?
            .displayName ?? "—"
    }
    
    private var availableCategories: [AchievementCategory] {
        let categories = Set(appState.tieredAchievements.map { $0.category })
        return AchievementCategory.activeCategories.filter { categories.contains($0) }
    }
    
    var body: some View {
        Group {
            if appState.isGuestMode {
                guestModeView
            } else {
                achievementsContent
            }
        }
        // Attached above the guest/normal branch so a highlight is consumed either way;
        // Guest Mode otherwise left a stale id that later popped an unrequested sheet.
        .onAppear { openHighlightedAchievementIfNeeded() }
        .onChange(of: coordinator.highlightedAchievementId) { _, _ in
            openHighlightedAchievementIfNeeded()
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
                Text("""
                    Guest Mode lets someone try StreakSync without \
                    affecting your data. Achievements are only visible \
                    when you're using your own account.
                    """)
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
        .sheet(item: $selectedAchievement) { achievement in
            NavigationStack {
                TieredAchievementDetailView(achievement: achievement)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { selectedAchievement = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(CornerRadius.sheet)
            .presentationBackground(.ultraThinMaterial)
        }
    }
    
    /// Consumes a highlight handed over by an Analytics recommendation (or a notification)
    /// so the tap opens the exact achievement instead of just this tab (DESIGN_AUDIT §4.8).
    private func openHighlightedAchievementIfNeeded() {
        guard let id = coordinator.highlightedAchievementId else { return }
        // Consume it unconditionally. Leaving an unresolvable id in place made a later
        // navigation to the same id a silent no-op (`onChange` sees no change).
        coordinator.highlightedAchievementId = nil
        guard let achievement = appState.tieredAchievements.first(where: { $0.id == id }) else { return }
        selectedAchievement = achievement
    }

    // MARK: - Progress Header
    /// Three cards abreast at default sizes; stacked at accessibility sizes so the
    /// labels reflow instead of being scaled down or clipped (DESIGN_AUDIT §4.2).
    private var summaryLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Spacing.md))
            : AnyLayout(HStackLayout(spacing: Spacing.md))
    }

    private var progressHeader: some View {
        summaryLayout {
            AchievementStatCard(
                icon: "trophy.fill", value: "\(unlockedCount)/\(totalAchievements)", label: "Unlocked", accentColor: .accentColor
            )
            AchievementStatCard(
                icon: "star.fill", value: highestTierName, label: "Highest Tier", accentColor: .accentColor
            )
            AchievementStatCard(
                icon: "percent", value: "\(completionPercentage)%", label: "Complete", accentColor: .accentColor
            )
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
            .padding(.horizontal, Spacing.lg)
        }
        // Cancel the enclosing VStack's 16pt inset so the scroller bleeds to the screen
        // edges, then re-apply it to the content above: the chips share the grid's
        // leading edge at rest but can still scroll all the way out.
        .padding(.horizontal, -Spacing.lg)
    }
    
    // MARK: - Achievements Grid
    /// One column at accessibility sizes — two half-width columns cannot hold a
    /// title, description, and progress line without truncating (DESIGN_AUDIT §4.2).
    private var achievementColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            [GridItem(.flexible(), spacing: Spacing.lg)]
        } else {
            [GridItem(.flexible(), spacing: Spacing.lg), GridItem(.flexible(), spacing: Spacing.lg)]
        }
    }

    private var achievementsGrid: some View {
        LazyVGrid(
            columns: achievementColumns,
            spacing: Spacing.lg
        ) {
            ForEach(filteredAchievements) { achievement in
                AchievementCard(
                    achievement: achievement,
                    onTap: { selectedAchievement = achievement }
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
