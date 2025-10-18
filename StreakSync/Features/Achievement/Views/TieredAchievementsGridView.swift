//
//  TieredAchievementsGridView.swift
//  StreakSync
//
//  MODERNIZED: iOS 26 native grid, materials, and animations
//

/*
 * TIEREDACHIEVEMENTSGRIDVIEW - ACHIEVEMENT PROGRESS AND CELEBRATION DISPLAY
 * 
 * WHAT THIS FILE DOES:
 * This file creates a beautiful grid view that displays all the user's achievements in an
 * organized, visually appealing way. It's like a "trophy case" that shows all the user's
 * accomplishments, their progress toward different achievement tiers, and provides a way
 * to filter and explore achievements by category. Think of it as the "achievement gallery"
 * that celebrates the user's progress and motivates them to keep playing and improving.
 * 
 * WHY IT EXISTS:
 * Users need to see their achievements and progress to stay motivated and engaged. This
 * view provides a comprehensive overview of all achievements, organized by category, with
 * beautiful visual representations of progress and completion. It handles different iOS
 * versions to provide the best possible experience on both older and newer devices.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides the achievement display that drives user engagement
 * - Shows comprehensive achievement progress and completion status
 * - Provides beautiful visual representations of achievements and tiers
 * - Supports filtering by achievement category
 * - Handles different iOS versions with appropriate features
 * - Displays progress statistics and completion percentages
 * - Integrates with the achievement system for real-time updates
 * 
 * WHAT IT REFERENCES:
 * - AppState: Access to all achievement data and progress
 * - NavigationCoordinator: For navigating to achievement details
 * - TieredAchievement: Individual achievement data and progress
 * - AchievementCategory: Categories for filtering achievements
 * - SwiftUI Grid: For displaying achievements in a grid layout
 * - iOS version-specific features: Enhanced UI for newer iOS versions
 * 
 * WHAT REFERENCES IT:
 * - MainTabView: This is the main content of the Awards tab
 * - NavigationCoordinator: Can navigate to this view
 * - Achievement detail views: Can navigate from this view
 * - AppContainer: Provides the data and services this view needs
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. VIEW SIZE REDUCTION:
 *    - This file is very large (500+ lines) - should be split into smaller components
 *    - Consider separating into: AchievementGrid, AchievementHeader, AchievementFilter
 *    - Move iOS version-specific code to separate files
 *    - Create reusable achievement components
 * 
 * 2. PERFORMANCE OPTIMIZATIONS:
 *    - The current grid implementation could be optimized
 *    - Consider implementing lazy loading for large achievement sets
 *    - Add view recycling for better memory management
 *    - Implement efficient filtering and sorting algorithms
 * 
 * 3. USER EXPERIENCE IMPROVEMENTS:
 *    - The current interface could be more intuitive
 *    - Add support for different grid layouts and sizes
 *    - Implement smart sorting and organization options
 *    - Add support for achievement search and discovery
 * 
 * 4. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for grid logic
 *    - Test different achievement scenarios and data
 *    - Add UI tests for grid interactions
 *    - Test accessibility features
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for grid features
 *    - Document the achievement display logic
 *    - Add examples of how to use different features
 *    - Create achievement flow diagrams
 * 
 * 7. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new achievement types
 *    - Add support for custom achievement layouts
 *    - Implement achievement plugins
 *    - Add support for third-party achievement integrations
 * 
 * 8. ANIMATION IMPROVEMENTS:
 *    - The current animations could be more sophisticated
 *    - Add support for achievement unlock celebrations
 *    - Implement smooth transitions between states
 *    - Add support for custom animation preferences
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Grid views: User interfaces that display items in a grid layout
 * - Achievement systems: Reward systems that encourage user engagement
 * - Progress tracking: Monitoring user progress toward goals
 * - iOS version compatibility: Making sure the app works on different iOS versions
 * - Visual design: Creating beautiful and engaging user interfaces
 * - Data filtering: Showing only relevant data based on user selection
 * - State management: Keeping track of what the UI should show
 * - Accessibility: Making sure the app is usable for everyone
 * - Performance: Making sure the app runs smoothly with lots of data
 * - User experience: Making sure the app is easy and pleasant to use
 */

import SwiftUI

// MARK: - Tiered Achievements Grid View
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
    
    private var availableCategories: [AchievementCategory] {
        let categories = Set(appState.tieredAchievements.map { $0.category })
        return AchievementCategory.allCases.filter { categories.contains($0) }
    }
    
    var body: some View {
        if #available(iOS 26.0, *) {
            iOS26AchievementsView
        } else {
            legacyAchievementsView
        }
    }
    
    // MARK: - iOS 26 Implementation
    @available(iOS 26.0, *)
    private var iOS26AchievementsView: some View {
        ScrollView {
            LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
                // Header with progress overview
                iOS26ProgressHeader
                    .scrollTransition { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.8)
                            .scaleEffect(phase.isIdentity ? 1 : 0.95)
                    }
                
                // Category filter
                iOS26CategoryFilter
                // CORRECT - scrollTransition always needs a closure
                .scrollTransition { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0.9)
                        .scaleEffect(phase.isIdentity ? 1 : 0.98)
                }
                
                // Achievements grid
                iOS26AchievementsGrid
            }
            .padding()
        }
        .scrollPosition($scrollPosition)
        .scrollBounceBehavior(.automatic)
        .scrollIndicators(.automatic, axes: .vertical)
        .scrollDismissesKeyboard(.interactively)
        .background {
            // iOS 26 Dynamic background
            Rectangle()
                .fill(.background)
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.03),
                            Color.clear
                        ],
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
    
    // MARK: - iOS 26 Progress Header
    @available(iOS 26.0, *)
    private var iOS26ProgressHeader: some View {
        HStack(spacing: 12) {
            // Total unlocked
            iOS26StatCard(
                icon: "trophy.fill",
                value: "\(unlockedCount)",
                label: "Unlocked",
                accentColor: .yellow
            )
            
            // Total tiers
            iOS26StatCard(
                icon: "star.fill",
                value: "\(totalTiers)",
                label: "Total Tiers",
                accentColor: .purple
            )
            
            // Completion percentage
            iOS26StatCard(
                icon: "percent",
                value: "\(completionPercentage)%",
                label: "Complete",
                accentColor: .blue
            )
        }
        .modifier(iOS26HeaderAnimation(hasAppeared: hasAppeared))
    }
    
    // MARK: - iOS 26 Category Filter
    @available(iOS 26.0, *)
    private var iOS26CategoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All categories chip
                iOS26CategoryChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    action: {
                        withAnimation(.smooth) {
                            selectedCategory = nil
                        }
                    }
                )
                
                // Individual category chips
                ForEach(availableCategories, id: \.self) { category in
                    iOS26CategoryChip(
                        title: category.displayName,
                        icon: category.baseIconSystemName,
                        isSelected: selectedCategory == category,
                        action: {
                            withAnimation(.smooth) {
                                selectedCategory = category
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - iOS 26 Achievements Grid
    @available(iOS 26.0, *)
    private var iOS26AchievementsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 16
        ) {
            ForEach(Array(filteredAchievements.enumerated()), id: \.element.id) { index, achievement in
                iOS26AchievementCard(
                    achievement: achievement,
                    onTap: {
                        coordinator.presentSheet(.tieredAchievementDetail(achievement))
                    }
                )
                .scrollTransition { content, phase in
                    content
                        .scaleEffect(
                            x: phase.isIdentity ? 1 : 0.96,
                            y: phase.isIdentity ? 1 : 0.96
                        )
                        .opacity(phase.isIdentity ? 1 : 0.8)
                }
                .onScrollVisibilityChange { isVisible in
                    if isVisible {
                        visibleAchievements.insert(achievement.id)
                    }
                }
            }
        }
        .animation(.smooth, value: filteredAchievements)
    }
    
    // MARK: - Legacy Implementation
    private var legacyAchievementsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with progress overview
                AchievementProgressHeader(
                    unlockedCount: unlockedCount,
                    totalTiers: totalTiers,
                    completionPercentage: completionPercentage,
                    hasAppeared: hasAppeared
                )
                
                // Category filter
                AchievementCategoryFilter(
                    selectedCategory: $selectedCategory,
                    categories: availableCategories,
                    hasAppeared: hasAppeared
                )
                
                // Achievements grid
                AchievementGridContent(
                    achievements: filteredAchievements,
                    hasAppeared: hasAppeared
                )
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.clear)
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                hasAppeared = true
            }
        }
    }
}

// MARK: - iOS 26 Stat Card
@available(iOS 26.0, *)
struct iOS26StatCard: View {
    let icon: String
    let value: String
    let label: String
    let accentColor: Color
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image.safeSystemName(icon, fallback: "star.fill")
                .font(.title2)
                .foregroundStyle(accentColor)
                .symbolEffect(.pulse, options: .repeating.speed(0.5), value: isHovered)
            
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(accentColor.opacity(0.2), lineWidth: 1)
                }
                .shadow(color: accentColor.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .hoverEffect(.lift)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - iOS 26 Category Chip
@available(iOS 26.0, *)
struct iOS26CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image.safeSystemName(icon, fallback: "star.fill")
                    .font(.caption)
                    .symbolEffect(.bounce, value: isSelected)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor)
                        .shadow(color: .accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .stroke(.quaternary, lineWidth: 0.5)
                        }
                }
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.smooth(duration: 0.2), value: isSelected)
        .hoverEffect(.highlight)
    }
}

// MARK: - iOS 26 Achievement Card
@available(iOS 26.0, *)
struct iOS26AchievementCard: View {
    let achievement: TieredAchievement
    let onTap: () -> Void
    
    @State private var isHovered = false
    @State private var showUnlockAnimation = false
    
    private var progressPercentage: Double {
        guard let nextRequirement = achievement.nextTierRequirement else { return 1.0 }
        return min(Double(achievement.progress.currentValue) / Double(nextRequirement.threshold), 1.0)
    }
    
    private var safeIconName: String {
        let iconName = achievement.iconSystemName
        return iconName.isEmpty ? "star.fill" : iconName
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon with tier indicator
                ZStack {
                    // Glow effect for unlocked
                    if achievement.isUnlocked {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        achievement.displayColor.opacity(0.3),
                                        achievement.displayColor.opacity(0)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 30
                                )
                            )
                            .frame(width: 60, height: 60)
                            .blur(radius: isHovered ? 8 : 4)
                    }
                    
                    // Background circle
                    Circle()
                        .fill(achievement.displayColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                        .overlay {
                            Circle()
                                .stroke(achievement.displayColor.opacity(0.3), lineWidth: 1)
                        }
                    
                    // Icon
                    Image.safeSystemName(safeIconName, fallback: "star.fill")
                        .font(.title)
                        .foregroundStyle(
                            achievement.isUnlocked ?
                            achievement.displayColor :
                            Color(.systemGray3)
                        )
                        .symbolEffect(.bounce, value: showUnlockAnimation)
                }
                
                // Title and Description
                VStack(spacing: 6) {
                    Text(achievement.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(achievement.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.horizontal, 8)
                
                Spacer()
                
                // Progress Section
                VStack(spacing: 8) {
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(.quaternary)
                            
                            // Progress Fill
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            achievement.displayColor,
                                            achievement.displayColor.opacity(0.7)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progressPercentage)
                                .animation(.smooth, value: progressPercentage)
                        }
                    }
                    .frame(height: 6)
                    
                    // Progress Text
                    Text(achievement.progressDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            .padding()
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        if achievement.isUnlocked {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    achievement.displayColor.opacity(0.2),
                                    lineWidth: 1
                                )
                        }
                    }
                    .shadow(
                        color: achievement.isUnlocked ?
                            achievement.displayColor.opacity(0.15) :
                            .black.opacity(0.05),
                        radius: isHovered ? 12 : 8,
                        x: 0,
                        y: isHovered ? 6 : 4
                    )
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.smooth(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if hovering && achievement.isUnlocked {
                showUnlockAnimation = true
            }
        }
        .hoverEffect(.lift)
    }
}

// MARK: - iOS 26 Header Animation Modifier
@available(iOS 26.0, *)
struct iOS26HeaderAnimation: ViewModifier {
    let hasAppeared: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : -20)
            .animation(
                .smooth(duration: 0.6)
                .delay(0.1),
                value: hasAppeared
            )
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
