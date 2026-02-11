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
    @Environment(\.colorScheme) private var colorScheme

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
    @State private var refreshToken = UUID()

    // iOS 26: Scroll position tracking
    @State private var scrollPosition = ScrollPosition()
    @State private var visibleItems: Set<String> = []

    // MARK: - Computed Properties

    private var longestCurrentStreak: Int {
        appState.streaks.map(\.currentStreak).max() ?? 0
    }

    private var activeStreakCount: Int {
        appState.streaks.filter { $0.isActive }.count
    }

    private var hasActiveStreaks: Bool {
        longestCurrentStreak > 0 || activeStreakCount > 0
    }

    private var isReturningUser: Bool {
        appState.streaks.contains { streak in
            streak.lastPlayedDate != nil || streak.maxStreak > 0 || streak.totalGamesPlayed > 0
        }
    }

    private var filteredGames: [Game] {
        let baseGames = showOnlyActive ?
            appState.games.filter { game in
                guard let streak = appState.getStreak(for: game) else { return false }
                return streak.isActive
            } :
            appState.games

        let categoryFiltered = selectedCategory == nil ?
            baseGames :
            baseGames.filter { $0.category == selectedCategory }

        let searchFiltered = searchText.isEmpty ?
            categoryFiltered :
            categoryFiltered.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }

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

    // MARK: - Body

    var body: some View {
        let _ = refreshToken

        Group {
            if #available(iOS 26.0, *) {
                dashboardScrollView(spacing: 24)
                    .background(StreakSyncColors.background(for: colorScheme))
                    .scrollBounceBehavior(.automatic)
                    .skeletonLoading(isLoading: appState.isLoading && !hasInitiallyAppeared, style: .card)
            } else {
                dashboardScrollView(spacing: 20)
                    .background(
                        StreakSyncColors.backgroundGradient(for: colorScheme)
                            .ignoresSafeArea()
                    )
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("StreakSync")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { dashboardToolbar }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
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
        .onReceive(NotificationCenter.default.publisher(for: .appGameDataUpdated)) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.25)) { refreshToken = UUID() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appGameResultAdded)) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.25)) { refreshToken = UUID() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appRefreshGameData)) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.25)) { refreshToken = UUID() }
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
                        displayMode: $displayMode,
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
        let content = DashboardGamesContent(
            filteredGames: filteredGames,
            filteredStreaks: filteredStreaks,
            displayMode: displayMode,
            searchText: searchText,
            hasInitiallyAppeared: hasInitiallyAppeared
        )
        .id(refreshToken)

        if #available(iOS 26.0, *) {
            content.modifier(iOS26ContentTransitionModifier())
        } else {
            content
        }
    }

    // MARK: - Recent Activity (with iOS 26 enhancements)

    @ViewBuilder
    private var recentActivitySection: some View {
        if #available(iOS 26.0, *) {
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
        } else {
            RecentActivitySection(filteredStreaks: filteredStreaks)
                .padding(.horizontal)
                .padding(.top, 8)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var dashboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            ToolbarSortMenu(
                selectedSort: $selectedSort,
                sortDirection: $sortDirection,
                showOnlyActive: $showOnlyActive
            )

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

    // MARK: - Helper Methods

    @MainActor
    private func performRefresh() async {
        isRefreshing = true

        if #available(iOS 26.0, *) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            HapticManager.shared.trigger(.pullToRefresh)
        }

        await appState.refreshData()

        if #available(iOS 26.0, *) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            HapticManager.shared.trigger(.achievement)
        }

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
                let rate1 = appState.streaks.first(where: { $0.gameId == game1.id })?.completionRate ?? 0
                let rate2 = appState.streaks.first(where: { $0.gameId == game2.id })?.completionRate ?? 0
                return rate1 > rate2
            }
        }
    }
}

// MARK: - iOS 26 View Modifiers

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
            .environmentObject(GameManagementState())
    }
}
