//
//  ImprovedDashboardView.swift
//  StreakSync
//
//  UPDATED: Native Large Title Navigation Implementation
//

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
    @State private var refreshID = UUID()
    @State private var isRefreshing = false
    @State private var hasInitiallyAppeared = false
//    @State private var selectedGameSection: GameSection = .all
//    @State private var selectedCategory: GameCategory? = nil
    @State private var selectedSort: GameSortOption = .lastPlayed
    @State private var sortDirection: SortDirection = .descending
    
    // iOS 26: New scroll position tracking
    @State private var scrollPosition = ScrollPosition()
    @State private var visibleItems: Set<String> = []
    
    private var longestCurrentStreak: Int {
        appState.streaks.map(\.currentStreak).max() ?? 0
    }
    
    private var activeStreakCount: Int {
        appState.streaks.filter { $0.isActive }.count
    }
    
    private var filteredGames: [Game] {
        let baseGames = showOnlyActive ?
            appState.games.filter { game in
                // Use streak data to determine if game is active
                guard let streak = appState.getStreak(for: game) else { return false }
                guard let lastPlayed = streak.lastPlayedDate else { return false }
                let daysSinceLastPlayed = Calendar.current.dateComponents([.day], from: lastPlayed, to: Date()).day ?? 0
                return daysSinceLastPlayed < 7
            } :
            appState.games
        
        // Apply search
        let searchFiltered = searchText.isEmpty ?
            baseGames :
            baseGames.filter { game in
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
                    // Games section with SIMPLIFIED header
                    VStack(alignment: .leading, spacing: 8) { // Reduced from 16 to 8
                        SimplifiedGamesHeader(
                            displayMode: $displayMode,
                            selectedSort: $selectedSort,
                            sortDirection: $sortDirection,
                            showOnlyActive: $showOnlyActive,
                            navigateToGameManagement: {
                                coordinator.navigateTo(.gameManagement)
                            }
                        )
                        
                        DashboardGamesContent(
                            filteredGames: filteredGames,
                            filteredStreaks: filteredStreaks,
                            displayMode: displayMode,
                            searchText: searchText,
                            refreshID: refreshID,
                            hasInitiallyAppeared: hasInitiallyAppeared
                        )
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
                    Button {
                        coordinator.navigateTo(.allStreaks)
                    } label: {
                        HStack(spacing: 8) {
                            ToolbarStatChip(
                                icon: "flame.fill",
                                value: longestCurrentStreak,
                                color: .orange
                            )
                            .allowsHitTesting(false)
                            
                            ToolbarStatChip(
                                icon: "bolt.fill",
                                value: activeStreakCount,
                                color: .green
                            )
                            .allowsHitTesting(false)
                            
                            // Analytics icon
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View All Streaks")
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
                    withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
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
        }
        
        // MARK: - iOS 26 Body with Native Navigation
        @available(iOS 26.0, *)
        private var iOS26NativeNavigationBody: some View {
            ScrollView {
                VStack(spacing: 24) {
                    // Games section with SIMPLIFIED header
                    VStack(alignment: .leading, spacing: 8) { // Reduced from 16 to 8
                        SimplifiedGamesHeader(
                            displayMode: $displayMode,
                            selectedSort: $selectedSort,
                            sortDirection: $sortDirection,
                            showOnlyActive: $showOnlyActive,
                            navigateToGameManagement: {
                                coordinator.navigateTo(.gameManagement)
                            }
                        )
                        
                        DashboardGamesContent(
                            filteredGames: filteredGames,
                            filteredStreaks: filteredStreaks,
                            displayMode: displayMode,
                            searchText: searchText,
                            refreshID: refreshID,
                            hasInitiallyAppeared: hasInitiallyAppeared
                        )
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
                    Button {
                        coordinator.navigateTo(.allStreaks)
                    } label: {
                        HStack(spacing: 8) {
                            ToolbarStatChip(
                                icon: "flame.fill",
                                value: longestCurrentStreak,
                                color: .orange
                            )
                            .allowsHitTesting(false)
                            
                            ToolbarStatChip(
                                icon: "bolt.fill",
                                value: activeStreakCount,
                                color: .green
                            )
                            .allowsHitTesting(false)
                            
                            // Analytics icon
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View All Streaks")
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
                    withAnimation(.smooth(duration: 0.6).delay(0.1)) {
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
        }
    
    // MARK: - Helper Methods (keep unchanged)
    @MainActor
    private func performRefresh() async {
        isRefreshing = true
        
        if #available(iOS 26.0, *) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } else {
            HapticManager.shared.trigger(.pullToRefresh)
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await appState.refreshData()
        
        refreshID = UUID()
        isRefreshing = false
    }
    
    private func sortGames(_ games: [Game]) -> [Game] {
        games.sorted { game1, game2 in
            switch selectedSort {
            case .lastPlayed:
                let date1 = appState.streaks.first(where: { $0.gameId == game1.id })?.lastPlayedDate ?? .distantPast
                let date2 = appState.streaks.first(where: { $0.gameId == game2.id })?.lastPlayedDate ?? .distantPast
                return date1 > date2
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
