//
//  ImprovedDashboardView.swift
//  StreakSync
//
//  Main home screen — single implementation with iOS 26 enhancements applied conditionally
//

import SwiftUI

struct ImprovedDashboardView: View {
    // MARK: - Environment & State
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Environment(GameCatalog.self) private var gameCatalog
    @EnvironmentObject private var gameManagementState: GameManagementState

    @AppStorage("userName") private var userName: String = ""
    @AppStorage("gameDisplayMode") private var displayMode: GameDisplayMode = .card

    @State private var searchText = ""
    @State private var showOnlyActive = false
    @State private var isRefreshing = false
    @State private var hasInitiallyAppeared = false
    @State private var selectedCategory: GameCategory? = nil
    @State private var selectedSort: GameSortOption = .lastPlayed
    @State private var sortDirection: SortDirection = .descending
    @State private var hasSeenGuidance = UserDefaults.standard.bool(forKey: "hasSeenEmptyStateGuidance")

    // MARK: - Computed Properties

    private var longestCurrentStreak: Int {
        appState.longestCurrentStreak
    }

    private var activeStreakCount: Int {
        appState.totalActiveStreaks
    }

    private var hasActiveStreaks: Bool {
        longestCurrentStreak > 0 || activeStreakCount > 0
    }

    private var atRiskCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return appState.streaks.filter { streak in
            streak.isActive &&
            (streak.lastPlayedDate.map { !calendar.isDate($0, inSameDayAs: today) } ?? true)
        }.count
    }

    private var completedTodayCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return appState.streaks.filter { streak in
            streak.lastPlayedDate.map { calendar.isDate($0, inSameDayAs: today) } ?? false
        }.count
    }

    private var isReturningUser: Bool {
        appState.streaks.contains { streak in
            streak.lastPlayedDate != nil || streak.maxStreak > 0 || streak.totalGamesPlayed > 0
        }
    }

    private var filteredGames: [Game] {
        let nonArchived = appState.games.filter { !gameManagementState.isArchived($0.id) }

        let baseGames = showOnlyActive ?
            nonArchived.filter { game in
                guard let streak = appState.getStreak(for: game) else { return false }
                return streak.isActive
            } :
            nonArchived

        let categoryFiltered = selectedCategory == nil ?
            baseGames :
            baseGames.filter { $0.category == selectedCategory }

        let searchFiltered = searchText.isEmpty ?
            categoryFiltered :
            categoryFiltered.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }

        return sortGames(searchFiltered)
    }

    private var filteredStreaks: [GameStreak] {
        let gameIds = Set(filteredGames.map(\.id))
        return appState.streaks.filter { gameIds.contains($0.gameId) }.sorted { streak1, streak2 in
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

    // MARK: - Body

    var body: some View {
        Group {
            dashboardScrollView(spacing: 24)
                .scrollBounceBehavior(.automatic)
                .skeletonLoading(isLoading: appState.isLoading && !hasInitiallyAppeared, style: .card)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("StreakSync")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { dashboardToolbar }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search games..."
        )
        .refreshable { await performRefresh() }
        .onAppear {
            if !hasInitiallyAppeared {
                withAnimation(.easeOut(duration: 0.4)) {
                    hasInitiallyAppeared = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appNavigateToGame)) { notification in
            if let userInfo = notification.object as? [String: Any],
               let gameId = userInfo["gameId"] as? UUID,
               let game = appState.games.first(where: { $0.id == gameId }) {
                coordinator.navigateTo(.gameDetail(game))
            }
        }
        .onChange(of: appState.isGuestMode) { oldValue, newValue in
            if oldValue == true && newValue == false {
                showOnlyActive = false
                selectedCategory = nil
                searchText = ""
            }
        }
    }

    // MARK: - Shared Scroll Content

    private func dashboardScrollView(spacing: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: spacing) {
                // Streak summary hero
                StreakSummaryHero(
                    activeStreakCount: activeStreakCount,
                    longestCurrentStreak: longestCurrentStreak,
                    atRiskCount: atRiskCount,
                    completedTodayCount: completedTodayCount
                )
                .padding(.horizontal)

                // Empty state guidance card
                if !hasActiveStreaks && !hasSeenGuidance && appState.games.count > 0 {
                    EmptyStateGuidanceCard(isReturningUser: isReturningUser) {
                        hasSeenGuidance = true
                        UserDefaults.standard.set(true, forKey: "hasSeenEmptyStateGuidance")
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // Games section
                VStack(alignment: .leading, spacing: 12) {
                    SimplifiedGamesHeader(
                        selectedSort: $selectedSort,
                        sortDirection: $sortDirection,
                        showOnlyActive: $showOnlyActive,
                        selectedCategory: $selectedCategory,
                        navigateToGameManagement: {
                            coordinator.navigateTo(.gameManagement)
                        }
                    )

                    if availableCategories.count > 1 {
                        CategoryFilterView(
                            selectedCategory: $selectedCategory,
                            categories: availableCategories
                        )
                        .padding(.horizontal, -16)
                    }

                    gamesContent
                }
                .padding(.horizontal)

                // Recent activity
                if activeStreakCount > 0 && searchText.isEmpty {
                    recentActivitySection
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Games Content (with iOS 26 transition)

    @ViewBuilder
    private var gamesContent: some View {
        DashboardGamesContent(
            filteredGames: filteredGames,
            displayMode: displayMode,
            searchText: searchText,
            hasInitiallyAppeared: hasInitiallyAppeared
        )
    }

    // MARK: - Recent Activity (with iOS 26 enhancements)

    @ViewBuilder
    private var recentActivitySection: some View {
        RecentActivitySection(filteredStreaks: filteredStreaks)
            .padding(.horizontal)
            .padding(.vertical)
            .cardStyle(cornerRadius: 20)
            .padding(.horizontal)
            .scrollTransition { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0.8)
                    .scaleEffect(phase.isIdentity ? 1 : 0.95)
            }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var dashboardToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            ToolbarSortMenu(
                selectedSort: $selectedSort,
                sortDirection: $sortDirection,
                showOnlyActive: $showOnlyActive,
                displayMode: $displayMode
            )
        }

        ToolbarSpacer(.fixed, placement: .topBarTrailing)

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                coordinator.navigateTo(.analyticsDashboard)
            } label: {
                Image.compatibleSystemName("chart.line.uptrend.xyaxis")
                    .font(.body)
                    .foregroundStyle(hasActiveStreaks ? .blue : .secondary)
            }
            .accessibilityLabel("View Analytics")
        }
    }

    // MARK: - Helper Methods

    @MainActor
    private func performRefresh() async {
        isRefreshing = true

        HapticManager.shared.trigger(.pullToRefresh)

        await appState.refreshData()

        HapticManager.shared.trigger(.streakUpdate)

        AccessibilityAnnouncer.announceDataRefreshed()
        isRefreshing = false
    }

    private func sortGames(_ games: [Game]) -> [Game] {
        let streakByGame = Dictionary(
            uniqueKeysWithValues: appState.streaks.map { ($0.gameId, $0) }
        )
        let ascending = sortDirection == .ascending
        return games.sorted { game1, game2 in
            switch selectedSort {
            case .lastPlayed:
                let date1 = streakByGame[game1.id]?.lastPlayedDate ?? .distantPast
                let date2 = streakByGame[game2.id]?.lastPlayedDate ?? .distantPast
                return ascending ? (date1 < date2) : (date1 > date2)
            case .name:
                return ascending ?
                    game1.displayName > game2.displayName :
                    game1.displayName < game2.displayName
            case .streakLength:
                let s1 = streakByGame[game1.id]?.currentStreak ?? 0
                let s2 = streakByGame[game2.id]?.currentStreak ?? 0
                return ascending ? (s1 < s2) : (s1 > s2)
            case .completionRate:
                let r1 = streakByGame[game1.id]?.completionRate ?? 0
                let r2 = streakByGame[game2.id]?.completionRate ?? 0
                return ascending ? (r1 < r2) : (r1 > r2)
            }
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
            .environmentObject(GameManagementState())
    }
}
