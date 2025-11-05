//
//  ImprovedDashboardView.swift
//  StreakSync
//
//  UPDATED: Native Large Title Navigation Implementation
//

/*
 * IMPROVEDDASHBOARDVIEW - MAIN HOME SCREEN AND GAME OVERVIEW
 * 
 * WHAT THIS FILE DOES:
 * This file creates the main "home screen" that users see when they open the app. It's like the
 * "command center" that shows all their games, streaks, and recent activity in one place. Think
 * of it as the "dashboard" of a car - it gives users a quick overview of everything important
 * and lets them navigate to specific games or features. It includes search, filtering, sorting,
 * and different display modes to help users find what they're looking for.
 * 
 * WHY IT EXISTS:
 * Users need a central place to see all their game progress and quickly access different games.
 * This view provides that overview while also offering powerful tools to organize and find
 * specific games. It's the first thing users see, so it needs to be both informative and
 * easy to use. It also handles the complex logic of filtering, sorting, and displaying games
 * in different ways.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This is the main screen users interact with most of the time
 * - Provides overview of all games, streaks, and recent activity
 * - Handles search, filtering, and sorting of games
 * - Supports different display modes (cards, list, compact)
 * - Shows contextual guidance for new users
 * - Integrates with navigation system for seamless user experience
 * - Adapts to different iOS versions with enhanced features
 * 
 * WHAT IT REFERENCES:
 * - AppState: Access to all game data, streaks, and results
 * - NavigationCoordinator: For navigating to other screens
 * - GameCatalog: For game information and metadata
 * - ThemeManager: For consistent styling and theming
 * - GameManagementState: For managing game settings
 * - All dashboard components: Header, filters, game cards, etc.
 * 
 * WHAT REFERENCES IT:
 * - MainTabView: This is the main content of the Home tab
 * - NavigationCoordinator: Can navigate to this view
 * - AppContainer: Provides the data and services this view needs
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. VIEW SIZE REDUCTION:
 *    - This file is very large (400+ lines) - should be split into smaller components
 *    - Consider separating into: DashboardHeader, DashboardFilters, DashboardContent
 *    - Move complex logic to separate view models or helper functions
 *    - Create reusable components for common patterns
 * 
 * 2. STATE MANAGEMENT IMPROVEMENTS:
 *    - The current state management is complex - could be simplified
 *    - Consider using a dedicated DashboardViewModel
 *    - Move filtering and sorting logic to separate functions
 *    - Implement proper state validation and error handling
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current filtering happens on every render - could be optimized
 *    - Consider using computed properties with proper caching
 *    - Implement lazy loading for large game lists
 *    - Add view recycling for better memory management
 * 
 * 4. USER EXPERIENCE IMPROVEMENTS:
 *    - The current search and filtering could be more intuitive
 *    - Add search suggestions and autocomplete
 *    - Implement smart filtering based on user behavior
 *    - Add keyboard shortcuts for power users
 * 
 * 5. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for filtering and sorting logic
 *    - Test different display modes and configurations
 *    - Add UI tests for user interactions
 *    - Test accessibility features
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for complex logic
 *    - Document the filtering and sorting algorithms
 *    - Add examples of how to use different features
 *    - Create user flow diagrams
 * 
 * 8. CODE ORGANIZATION:
 *    - The current organization could be improved
 *    - Group related functionality together
 *    - Use consistent naming conventions
 *    - Add proper separation of concerns
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - @Environment: Access to shared data from parent views
 * - @State: Local state that can change and trigger UI updates
 * - @AppStorage: Persistent storage that survives app restarts
 * - Computed properties: Calculated values that update automatically
 * - Filtering and sorting: Common patterns for organizing data
 * - Search functionality: Letting users find specific content
 * - Display modes: Different ways to show the same data
 * - Navigation: Moving between different screens in the app
 * - Accessibility: Making the app usable for everyone
 * - Performance: Making sure the app runs smoothly with lots of data
 */

import SwiftUI

struct ImprovedDashboardView: View {
    // MARK: - Environment & State (unchanged)
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Environment(GameCatalog.self) private var gameCatalog
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var gameManagementState: GameManagementState
    @Environment(\.colorScheme) private var colorScheme
    
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("gameDisplayMode") private var displayMode: GameDisplayMode = .card
    
    @State private var searchText = ""
    @State private var showOnlyActive = false
    @State private var isRefreshing = false
    @State private var hasInitiallyAppeared = false
//    @State private var selectedGameSection: GameSection = .all
    @State private var selectedCategory: GameCategory? = nil
    @State private var selectedSort: GameSortOption = .lastPlayed
    @State private var sortDirection: SortDirection = .descending
    @State private var hasSeenGuidance = UserDefaults.standard.bool(forKey: "hasSeenEmptyStateGuidance")
    // Force-recompute token to break potential SwiftUI memoization on data updates
    @State private var refreshToken = UUID()
    
    // iOS 26: New scroll position tracking
    @State private var scrollPosition = ScrollPosition()
    @State private var visibleItems: Set<String> = []
    
    private var longestCurrentStreak: Int {
        appState.streaks.map(\.currentStreak).max() ?? 0
    }
    
    private var activeStreakCount: Int {
        appState.streaks.filter { $0.isActive }.count
    }
    
    // Helper to determine if we should show stats
    private var hasActiveStreaks: Bool {
        longestCurrentStreak > 0 || activeStreakCount > 0
    }
    
    // Check if user has ever played games before (for contextual messaging)
    private var isReturningUser: Bool {
        appState.streaks.contains { streak in
            streak.lastPlayedDate != nil || streak.maxStreak > 0 || streak.totalGamesPlayed > 0
        }
    }
    
    private var filteredGames: [Game] {
        let baseGames = showOnlyActive ?
            appState.games.filter { game in
                // Use streak data to determine if game is active
                guard let streak = appState.getStreak(for: game) else { return false }
                // A game is active if it has an active streak (played within 1 day AND has streak > 0)
                return streak.isActive
            } :
            appState.games
        
        // Apply category filter
        let categoryFiltered = selectedCategory == nil ?
            baseGames :
            baseGames.filter { game in
                game.category == selectedCategory
            }
        
        // Apply search
        let searchFiltered = searchText.isEmpty ?
            categoryFiltered :
            categoryFiltered.filter { game in
                game.displayName.localizedCaseInsensitiveContains(searchText)
            }
        
        // Sort
        return sortGames(searchFiltered)
    }
    
    private var filteredStreaks: [GameStreak] {
        appState.streaks.filter { streak in
            filteredGames.contains { $0.id == streak.gameId }
        }.sorted { streak1, streak2 in
            switch selectedSort {
            case .lastPlayed:
                return sortDirection == .descending ?
                    (streak1.lastPlayedDate ?? .distantPast) > (streak2.lastPlayedDate ?? .distantPast) :
                    (streak1.lastPlayedDate ?? .distantPast) < (streak2.lastPlayedDate ?? .distantPast)
            case .name:
                return sortDirection == .descending ?
                    streak1.gameName < streak2.gameName :
                    streak1.gameName > streak2.gameName
            case .streakLength:
                return sortDirection == .descending ?
                    streak1.currentStreak > streak2.currentStreak :
                    streak1.currentStreak < streak2.currentStreak
            case .completionRate:
                return sortDirection == .descending ?
                    streak1.completionRate > streak2.completionRate :
                    streak1.completionRate < streak2.completionRate
            }
        }
    }
    
    private var availableCategories: [GameCategory] {
        let categories = Set(appState.games.map { $0.category })
        return GameCategory.allCases.filter { categories.contains($0) && $0 != .custom }
    }
    
    // (Removed inline greeting override)
    
    // MARK: - Body
    var body: some View {
        if #available(iOS 26.0, *) {
            iOS26NativeNavigationBody
        } else {
            legacyNativeNavigationBody
        }
    }
        
    // MARK: - Legacy Body with Native Navigation
        private var legacyNativeNavigationBody: some View {
            ScrollView {
                VStack(spacing: 20) {
                    // Empty state guidance card
                    if !hasActiveStreaks && !hasSeenGuidance && appState.games.count > 0 {
                        EmptyStateGuidanceCard(isReturningUser: isReturningUser) {
                            hasSeenGuidance = true
                            UserDefaults.standard.set(true, forKey: "hasSeenEmptyStateGuidance")
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    // Games section with SIMPLIFIED header
                    VStack(alignment: .leading, spacing: 12) { // Optimized spacing
                        SimplifiedGamesHeader(
                            displayMode: $displayMode,
                            selectedSort: $selectedSort,
                            sortDirection: $sortDirection,
                            showOnlyActive: $showOnlyActive,
                            selectedCategory: $selectedCategory,
                            navigateToGameManagement: {
                                coordinator.navigateTo(.gameManagement)
                            }
                        )
                        
                        // Category filter (only show when multiple categories available)
                        if availableCategories.count > 1 {
                            CategoryFilterView(
                                selectedCategory: $selectedCategory,
                                categories: availableCategories
                            )
                            .padding(.horizontal, -16) // Extend to edges
                        }
                        
                        DashboardGamesContent(
                            filteredGames: filteredGames,
                            filteredStreaks: filteredStreaks,
                            displayMode: displayMode,
                            searchText: searchText,
                            hasInitiallyAppeared: hasInitiallyAppeared
                        )
                        .id(refreshToken)
                    }
                    .padding(.horizontal)
                    
                    // Recent activity
                    if activeStreakCount > 0 && searchText.isEmpty {
                        RecentActivitySection(filteredStreaks: filteredStreaks)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                }
                .padding(.bottom, 20)
            }
            .background(
                StreakSyncColors.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()
            )
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("StreakSync")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Sort menu in toolbar (system-owned presentation = smooth animation)
                    ToolbarSortMenu(
                        selectedSort: $selectedSort,
                        sortDirection: $sortDirection,
                        showOnlyActive: $showOnlyActive
                    )
                    
                    
                    // Analytics button - always visible but styled based on data availability
                    Button {
                        coordinator.navigateTo(.analyticsDashboard)
                    } label: {
                        Image.compatibleSystemName("chart.line.uptrend.xyaxis")
                            .font(.body)
                            .foregroundStyle(hasActiveStreaks ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View Analytics")
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search games..."
            )
            .refreshable {
                await performRefresh()
            }
            .onAppear {
                if !hasInitiallyAppeared {
                    withAnimation(.easeOut(duration: 0.4)) {
                        hasInitiallyAppeared = true
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToGame"))) { notification in
                if let userInfo = notification.object as? [String: Any],
                   let gameId = userInfo["gameId"] as? UUID,
                   let game = appState.games.first(where: { $0.id == gameId }) {
                    coordinator.navigateTo(.gameDetail(game))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GameDataUpdated"))) { _ in
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        refreshToken = UUID()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GameResultAdded"))) { _ in
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        refreshToken = UUID()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshGameData"))) { _ in
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        refreshToken = UUID()
                    }
                }
            }
        }
        
        // MARK: - iOS 26 Body with Native Navigation
        @available(iOS 26.0, *)
        private var iOS26NativeNavigationBody: some View {
            ScrollView {
                VStack(spacing: 24) {
                    // Empty state guidance card
                    if !hasActiveStreaks && !hasSeenGuidance && appState.games.count > 0 {
                        EmptyStateGuidanceCard(isReturningUser: isReturningUser) {
                            hasSeenGuidance = true
                            UserDefaults.standard.set(true, forKey: "hasSeenEmptyStateGuidance")
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    // Games section with SIMPLIFIED header
                    VStack(alignment: .leading, spacing: 12) { // Optimized spacing
                        SimplifiedGamesHeader(
                            displayMode: $displayMode,
                            selectedSort: $selectedSort,
                            sortDirection: $sortDirection,
                            showOnlyActive: $showOnlyActive,
                            selectedCategory: $selectedCategory,
                            navigateToGameManagement: {
                                coordinator.navigateTo(.gameManagement)
                            }
                        )
                        
                        // Category filter (only show when multiple categories available)
                        if availableCategories.count > 1 {
                            CategoryFilterView(
                                selectedCategory: $selectedCategory,
                                categories: availableCategories
                            )
                            .padding(.horizontal, -16) // Extend to edges
                        }
                        
                        DashboardGamesContent(
                            filteredGames: filteredGames,
                            filteredStreaks: filteredStreaks,
                            displayMode: displayMode,
                            searchText: searchText,
                            hasInitiallyAppeared: hasInitiallyAppeared
                        )
                        .id(refreshToken)
                        .modifier(iOS26ContentTransitionModifier())
                    }
                    .padding(.horizontal)
                    
                    // Recent activity
                    if activeStreakCount > 0 && searchText.isEmpty {
                        RecentActivitySection(filteredStreaks: filteredStreaks)
                            .padding(.horizontal)
                            .padding(.vertical)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(.regularMaterial)
                                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                            }
                            .padding(.horizontal)
                            .scrollTransition { content, phase in
                                content
                                    .opacity(phase.isIdentity ? 1 : 0.8)
                                    .scaleEffect(phase.isIdentity ? 1 : 0.95)
                            }
                    }
                }
                .padding(.bottom, 20)
            }
            .background(StreakSyncColors.background(for: colorScheme))
            .scrollBounceBehavior(.automatic)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("StreakSync")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Sort menu in toolbar (system-owned presentation = smooth animation)
                    ToolbarSortMenu(
                        selectedSort: $selectedSort,
                        sortDirection: $sortDirection,
                        showOnlyActive: $showOnlyActive
                    )
                    
                    
                    // Analytics button - always visible but styled based on data availability
                    Button {
                        coordinator.navigateTo(.analyticsDashboard)
                    } label: {
                        Image.compatibleSystemName("chart.line.uptrend.xyaxis")
                            .font(.body)
                            .foregroundStyle(hasActiveStreaks ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View Analytics")
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search games..."
            )
            .refreshable {
                await performRefresh()
            }
            .onAppear {
                if !hasInitiallyAppeared {
                    withAnimation(.easeOut(duration: 0.4)) {
                        hasInitiallyAppeared = true
                    }
                }
            }
            .skeletonLoading(isLoading: appState.isLoading && !hasInitiallyAppeared, style: .card)
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToGame"))) { notification in
                if let userInfo = notification.object as? [String: Any],
                   let gameId = userInfo["gameId"] as? UUID,
                   let game = appState.games.first(where: { $0.id == gameId }) {
                    coordinator.navigateTo(.gameDetail(game))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GameDataUpdated"))) { _ in
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        refreshToken = UUID()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GameResultAdded"))) { _ in
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        refreshToken = UUID()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshGameData"))) { _ in
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        refreshToken = UUID()
                    }
                }
            }
        }
    
    // MARK: - Helper Methods (keep unchanged)
    @MainActor
    private func performRefresh() async {
        isRefreshing = true
        
        // Enhanced haptic feedback
        if #available(iOS 26.0, *) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            HapticManager.shared.trigger(.pullToRefresh)
        }
        
        // Refresh data without artificial delay
        await appState.refreshData()
        
        // Success haptic feedback
        if #available(iOS 26.0, *) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            HapticManager.shared.trigger(.achievement)
        }
        
        // Accessibility announcement
        AccessibilityAnnouncer.announceDataRefreshed()
        
        
        isRefreshing = false
    }
    
    private func sortGames(_ games: [Game]) -> [Game] {
        games.sorted { game1, game2 in
            switch selectedSort {
            case .lastPlayed:
                let date1 = appState.streaks.first(where: { $0.gameId == game1.id })?.lastPlayedDate ?? .distantPast
                let date2 = appState.streaks.first(where: { $0.gameId == game2.id })?.lastPlayedDate ?? .distantPast
                return sortDirection == .descending ? (date1 > date2) : (date1 < date2)
            case .name:
                return game1.displayName < game2.displayName
            case .streakLength:
                let streak1 = appState.streaks.first(where: { $0.gameId == game1.id })?.currentStreak ?? 0
                let streak2 = appState.streaks.first(where: { $0.gameId == game2.id })?.currentStreak ?? 0
                return streak1 > streak2
            case .completionRate:
                let streak1 = appState.streaks.first(where: { $0.gameId == game1.id })
                let streak2 = appState.streaks.first(where: { $0.gameId == game2.id })
                let rate1 = streak1?.completionRate ?? 0
                let rate2 = streak2?.completionRate ?? 0
                return rate1 > rate2
            }
        }
    }
}

// MARK: - Keep iOS 26 View Modifiers (but don't use iOS26NavigationModifiers anymore)
@available(iOS 26.0, *)
struct iOS26ContentTransitionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollTransition { innerContent, phase in
                innerContent
                    .scaleEffect(
                        x: phase.isIdentity ? 1 : 0.98,
                        y: phase.isIdentity ? 1 : 0.98
                    )
            }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ImprovedDashboardView()
            .environment(AppState())
            .environment(GameCatalog())
            .environmentObject(NavigationCoordinator())
            .environmentObject(ThemeManager.shared)
            .environmentObject(GameManagementState())
    }
}
