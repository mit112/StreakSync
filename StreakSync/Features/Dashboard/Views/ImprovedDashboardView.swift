//
//  ImprovedDashboardView.swift
//  StreakSync
//
//  FIXED: Corrected iOS 26 API usage for scrollTransition and ScrollPosition binding
//

import SwiftUI

struct ImprovedDashboardView: View {
    // MARK: - Environment & State
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
    @State private var isSearching = false
    @State private var hasInitiallyAppeared = false
    @State private var selectedGameSection: GameSection = .all
    @State private var selectedCategory: GameCategory? = nil
    @State private var selectedSort: GameSortOption = .lastPlayed
    @State private var sortDirection: SortDirection = .descending
    
    // iOS 26: New scroll position tracking
    @State private var scrollPosition = ScrollPosition()
    @State private var visibleItems: Set<String> = []
    
    @FocusState private var isSearchFieldFocused: Bool
    
    // MARK: - Computed Properties (unchanged)
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = userName.isEmpty ? "" : ", \(userName)"
        
        switch hour {
        case 5..<9:
            return "Rise and shine\(name)! ☀️"
        case 9..<12:
            return "Good morning\(name)! 🌤"
        case 12..<14:
            return "Lunch break\(name)? 🥗"
        case 14..<17:
            return "Afternoon hustle\(name)! 💪"
        case 17..<20:
            return "Evening vibes\(name)! 🌅"
        case 20..<23:
            return "Winding down\(name)? 🌙"
        default:
            return "Night owl mode\(name)! 🦉"
        }
    }
    
    private var activeStreakCount: Int {
        appState.streaks.filter { streak in
            guard let game = appState.games.first(where: { $0.id == streak.gameId }) else { return false }
            return game.isActiveToday
        }.count
    }
    
    private var todayCompletedCount: Int {
        appState.games.filter { $0.hasPlayedToday }.count
    }
    
    private var filteredGames: [Game] {
        let baseGames = showOnlyActive ?
            appState.games.filter { $0.isActiveToday } :
            appState.games
        
        var games = baseGames
        
        switch selectedGameSection {
        case .favorites:
            games = games.filter { gameCatalog.isFavorite($0.id) }
        case .all:
            break
        }
        
        if let category = selectedCategory {
            games = games.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            games = games.filter { game in
                game.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return sortGames(games)
    }
    
    private var filteredStreaks: [GameStreak] {
        let gameIds = Set(filteredGames.map { $0.id })
        return appState.streaks
            .filter { gameIds.contains($0.gameId) }
            .sorted { streak1, streak2 in
                switch selectedSort {
                case .lastPlayed:
                    let date1 = streak1.lastPlayedDate ?? .distantPast
                    let date2 = streak2.lastPlayedDate ?? .distantPast
                    return sortDirection == .descending ? date1 > date2 : date1 < date2
                case .name:
                    return sortDirection == .descending ?
                        streak1.gameName > streak2.gameName :
                        streak1.gameName < streak2.gameName
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
    
    private var availableCategories: [GameCategory] {
        let categories = Set(filteredGames.map { $0.category })
        return GameCategory.allCases.filter { categories.contains($0) }
    }
    
    // MARK: - Main Body
    var body: some View {
        if #available(iOS 26.0, *) {
            iOS26DashboardView
        } else {
            legacyDashboardView
        }
    }
    
    // MARK: - iOS 26 Native Implementation (FIXED)
    @available(iOS 26.0, *)
    private var iOS26DashboardView: some View {
        ScrollView {
            iOS26ContentStack
        }
        .modifier(iOS26ScrollViewModifiers(scrollPosition: $scrollPosition)) // Fixed: Pass as binding
        .modifier(iOS26BackgroundModifier(themeManager: themeManager))
        .refreshable {
            await performRefresh()
        }
        .modifier(iOS26NavigationModifiers())
        .animation(.smooth, value: filteredGames)
        .onAppear {
            if !hasInitiallyAppeared {
                withAnimation(.smooth(duration: 0.6).delay(0.1)) {
                    hasInitiallyAppeared = true
                }
            }
        }
    }
    
    // MARK: - iOS 26 Content Stack (FIXED)
    @available(iOS 26.0, *)
    private var iOS26ContentStack: some View {
        LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
            // Header
            iOS26HeaderSection
            
            // Search bar
            if isSearching {
                iOS26SearchBar
                    .transition(.push(from: .top).combined(with: .opacity))
            }
            
            // Filters - FIXED scrollTransition
            if showOnlyActive || selectedCategory != nil || !searchText.isEmpty {
                iOS26FiltersView
                    // Fixed: Proper scrollTransition usage
                    .scrollTransition { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.9)
                            .scaleEffect(phase.isIdentity ? 1 : 0.98)
                    }
            }
            
            // Games section
            iOS26GamesSection
            
            // Recent activity
            if activeStreakCount > 0 && searchText.isEmpty {
                iOS26RecentActivity
                    .onScrollVisibilityChange { isVisible in
                        if isVisible {
                            visibleItems.insert("recent_activity")
                        }
                    }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - iOS 26 Header Section
    @available(iOS 26.0, *)
    private var iOS26HeaderSection: some View {
        DashboardHeaderView(
            activeStreakCount: activeStreakCount,
            todayCompletedCount: todayCompletedCount,
            greetingText: greetingText,
            isSearching: $isSearching,
            searchText: $searchText,
            isSearchFieldFocused: $isSearchFieldFocused
        )
        .scrollTargetLayout()
        .modifier(iOS26ScrollTransitionModifier())
    }
    
    // MARK: - iOS 26 Games Section
    @available(iOS 26.0, *)
    private var iOS26GamesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            DashboardGamesHeader(
                displayMode: $displayMode,
                selectedSort: $selectedSort,
                sortDirection: $sortDirection,
                selectedGameSection: $selectedGameSection,
                selectedCategory: $selectedCategory,
                navigateToGameManagement: {
                    coordinator.navigateTo(.gameManagement)
                }
            )
            .hoverEffect(.lift)
            
            DashboardGamesContent(
                filteredGames: filteredGames,
                filteredStreaks: filteredStreaks,
                displayMode: displayMode,
                searchText: searchText,
                refreshID: refreshID,
                hasInitiallyAppeared: hasInitiallyAppeared
            )
            .scrollTargetLayout()
            .modifier(iOS26ContentTransitionModifier())
        }
        .contentTransition(.numericText())
    }
    
    // MARK: - iOS 26 Search Bar
    @available(iOS 26.0, *)
    private var iOS26SearchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating, value: searchText)
            
            TextField("Search games...", text: $searchText)
                .focused($isSearchFieldFocused)
                .textFieldStyle(.plain)
                .submitLabel(.search)
            
            if !searchText.isEmpty {
                Button {
                    withAnimation(.bouncy) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .symbolEffect(.bounce, value: searchText)
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
                .stroke(.quaternary, lineWidth: 0.5)
        }
        .padding(.horizontal)
    }
    
    // MARK: - iOS 26 Filters View
    @available(iOS 26.0, *)
    private var iOS26FiltersView: some View {
        DashboardFiltersView(
            showOnlyActive: $showOnlyActive,
            selectedCategory: $selectedCategory,
            availableCategories: availableCategories
        )
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - iOS 26 Recent Activity
    @available(iOS 26.0, *)
    private var iOS26RecentActivity: some View {
        RecentActivitySection(filteredStreaks: filteredStreaks)
            .padding(.vertical)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            }
    }
    
    // MARK: - Legacy Dashboard View (unchanged)
    private var legacyDashboardView: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: []) {
                // Header section
                DashboardHeaderView(
                    activeStreakCount: activeStreakCount,
                    todayCompletedCount: todayCompletedCount,
                    greetingText: greetingText,
                    isSearching: $isSearching,
                    searchText: $searchText,
                    isSearchFieldFocused: $isSearchFieldFocused
                )
                .staggeredAppearance(index: 0, totalCount: 4)
                
                // Search bar
                if isSearching {
                    DashboardSearchBar(
                        searchText: $searchText,
                        isSearchFieldFocused: $isSearchFieldFocused
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Filters
                if showOnlyActive || selectedCategory != nil || !searchText.isEmpty {
                    DashboardFiltersView(
                        showOnlyActive: $showOnlyActive,
                        selectedCategory: $selectedCategory,
                        availableCategories: availableCategories
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Games section
                VStack(alignment: .leading, spacing: 16) {
                    DashboardGamesHeader(
                        displayMode: $displayMode,
                        selectedSort: $selectedSort,
                        sortDirection: $sortDirection,
                        selectedGameSection: $selectedGameSection,
                        selectedCategory: $selectedCategory,
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
                .staggeredAppearance(index: 1, totalCount: 4)
                
                // Recent activity
                if activeStreakCount > 0 && searchText.isEmpty {
                    RecentActivitySection(filteredStreaks: filteredStreaks)
                        .staggeredAppearance(index: 2, totalCount: 4)
                }
            }
            .padding(.horizontal)
        }
        .contentMargins(.top, 60, for: .scrollContent)
        .contentMargins(.bottom, 20, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(themeManager.primaryBackground)
        .refreshable {
            await performRefresh()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .statusBarHidden(false)
        .onAppear {
            if !hasInitiallyAppeared {
                withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                    hasInitiallyAppeared = true
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    @MainActor
    private func performRefresh() async {
        isRefreshing = true
        
        if #available(iOS 26.0, *) {
            await UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } else {
            HapticManager.shared.trigger(.pullToRefresh)
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await appState.refreshData()
        
        refreshID = UUID()
        isRefreshing = false
    }
}

// MARK: - iOS 26 View Modifiers (FIXED)

@available(iOS 26.0, *)
struct iOS26ScrollViewModifiers: ViewModifier {
    @Binding var scrollPosition: ScrollPosition  // Fixed: Changed to Binding
    
    func body(content: Content) -> some View {
        content
            .scrollPosition($scrollPosition)  // Fixed: Now passes binding correctly
            .scrollBounceBehavior(.automatic)
            .scrollClipDisabled()
            .contentMargins(.vertical, 20, for: .scrollContent)
            .contentMargins(.horizontal, 0, for: .scrollIndicators)
            .scrollIndicators(.automatic, axes: .vertical)
            .scrollDismissesKeyboard(.interactively)
            .scrollTargetLayout()
    }
}

@available(iOS 26.0, *)
struct iOS26BackgroundModifier: ViewModifier {
    let themeManager: ThemeManager
    
    func body(content: Content) -> some View {
        content
            .background {
                Rectangle()
                    .fill(.regularMaterial)
                    .ignoresSafeArea()
                    .overlay {
                        LinearGradient(
                            colors: [
                                themeManager.primaryAccent.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
    }
}

@available(iOS 26.0, *)
struct iOS26NavigationModifiers: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .statusBarHidden(false)
            .contentTransition(.numericText())
    }
}

@available(iOS 26.0, *)
struct iOS26ScrollTransitionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollTransition { innerContent, phase in
                innerContent
                    .opacity(phase.isIdentity ? 1 : 0.8)
                    .scaleEffect(phase.isIdentity ? 1 : 0.95)
                    .blur(radius: phase.isIdentity ? 0 : 2)
            }
    }
}

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
