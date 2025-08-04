//
//  ImprovedDashboardView.swift
//  StreakSync
//
//  Enhanced dashboard with games as centerpiece - cleaned up for tab navigation
//

import SwiftUI

struct ImprovedDashboardView: View {
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
    @FocusState private var isSearchFieldFocused: Bool
    
    // MARK: - Computed Properties
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
        
        // Apply section filter
        switch selectedGameSection {
        case .favorites:
            games = games.filter { gameCatalog.isFavorite($0.id) }
        case .all:
            break // Show all games
        }
        
        // Apply category filter
        if let category = selectedCategory {
            games = games.filter { $0.category == category }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            games = games.filter { game in
                game.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sorting
        return sortGames(games)
    }
    
    // Update the filteredStreaks computed property to properly sort:
    private var filteredStreaks: [GameStreak] {
        // Get the filtered games first
        let gameIds = Set(filteredGames.map { $0.id })
        
        // Filter streaks to match filtered games
        var streaks = appState.streaks.filter { streak in
            gameIds.contains(streak.gameId)
        }
        
        // Apply sorting to STREAKS, not games
        streaks = streaks.sorted { (streak1: GameStreak, streak2: GameStreak) in
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
        
        return streaks
    }
    
    private func sortGames(_ games: [Game]) -> [Game] {
        let sorted = games.sorted { (game1: Game, game2: Game) in
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
        
        return sortDirection == .ascending ? sorted.reversed() : sorted
    }
    
    private var availableCategories: [GameCategory] {
        let categories = Set(filteredGames.map { $0.category })
        return GameCategory.allCases.filter { categories.contains($0) }
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Compact header section
                    compactHeaderSection
                        .staggeredAppearance(index: 0, totalCount: 4)
                    
                    // Search and filter section
                    if isSearching || !searchText.isEmpty || showOnlyActive || selectedCategory != nil {
                        searchAndFilterSection
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Games centerpiece section
                    gamesCenterpieceSection
                        .staggeredAppearance(index: 1, totalCount: 4)
                    
                    // Recent streaks section
                    if activeStreakCount > 0 && searchText.isEmpty {
                        recentStreaksSection
                            .staggeredAppearance(index: 2, totalCount: 4)
                    }
                }
                .padding(.bottom, 20)
            }
            .refreshable {
                await refreshData()
            }
        }
        .background(themeManager.primaryBackground)
        .navigationBarHidden(true)
        .onAppear {
            if !hasInitiallyAppeared {
                withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                    hasInitiallyAppeared = true
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var compactHeaderSection: some View {
        VStack(spacing: 8) {
            // App name
            HStack {
                Text("StreakSync")
                    .font(.largeTitle.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                // Compact progress indicators
                HStack(spacing: 8) {
                    CompactProgressBadge(
                        icon: "flame.fill",
                        value: activeStreakCount,
                        color: .orange
                    )
                    
                    CompactProgressBadge(
                        icon: "checkmark.circle.fill",
                        value: todayCompletedCount,
                        color: .green
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Dynamic greeting with search
            HStack {
                Text(greetingText)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut, value: greetingText)
                
                Spacer()
                
                // Search toggle
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isSearching.toggle()
                        if isSearching {
                            isSearchFieldFocused = true
                        } else {
                            searchText = ""
                            isSearchFieldFocused = false
                        }
                    }
                } label: {
                    Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color(.systemGray6))
                        )
                        .contentTransition(.symbolEffect(.replace))
                }
                .pressable(hapticType: .buttonTap, scaleAmount: 0.9)
            }
            .padding(.horizontal)
        }
    }
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search field
            if isSearching {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search games...", text: $searchText)
                        .focused($isSearchFieldFocused)
                        .submitLabel(.search)
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal)
            }
            
            // Filter options
            HStack {
                // Active only toggle
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showOnlyActive.toggle()
                    }
                } label: {
                    Label("Active", systemImage: showOnlyActive ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(showOnlyActive ? .orange : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(showOnlyActive ? .orange.opacity(0.15) : Color(.systemGray6))
                        )
                }
                .pressable(hapticType: .toggleSwitch, scaleAmount: 0.95)
                .accessibilityLabel(showOnlyActive ? "Showing active games only" : "Show all games")
            }
            .padding(.horizontal)
            
            // Category filter chips
            if !availableCategories.isEmpty {
                CategoryFilterView(
                    selectedCategory: $selectedCategory,
                    categories: availableCategories
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    private var gamesCenterpieceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with controls
            HStack {
                Text("Your Games")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                // View mode toggle - make it more prominent
                Menu {
                    ForEach(GameDisplayMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                displayMode = mode
                                HapticManager.shared.trigger(.buttonTap)
                            }
                        } label: {
                            Label(mode.displayName, systemImage: mode.iconName)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: displayMode.iconName)
                            .font(.body)
                        Text(displayMode.displayName)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.blue.opacity(0.1))
                    )
                }
                
                // Sort options
                CompactSortOptionsMenu(
                    selectedSort: $selectedSort,
                    sortDirection: $sortDirection
                )
                
                // Section selector
                Menu {
                    ForEach(GameSection.allCases, id: \.self) { section in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedGameSection = section
                                selectedCategory = nil
                            }
                        } label: {
                            Label(section.rawValue, systemImage: section.icon)
                        }
                    }
                    
                    Divider()
                    
                    Button {
                        coordinator.navigateTo(.gameManagement)
                    } label: {
                        Label("Manage Games", systemImage: "slider.horizontal.3")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectedGameSection.icon)
                        Text(selectedGameSection.rawValue)
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            // Games content
            if filteredGames.isEmpty {
                GameEmptyState(
                    title: searchText.isEmpty ? "No games yet" : "No results",
                    subtitle: searchText.isEmpty ? "Add games to start tracking" : "Try a different search",
                    action: searchText.isEmpty ? {
                        coordinator.navigateTo(.gameManagement)
                    } : nil
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // Switch based on display mode
                switch displayMode {
                case .card:
                    LazyVStack(spacing: 12) {
                        ForEach(Array(filteredStreaks.enumerated()), id: \.element.id) { index, streak in
                            EnhancedStreakCard(
                                streak: streak,
                                hasAppeared: hasInitiallyAppeared,
                                animationIndex: index,
                                isFavorite: gameCatalog.isFavorite(streak.gameId),
                                onFavoriteToggle: {
                                    gameCatalog.toggleFavorite(streak.gameId)
                                    HapticManager.shared.trigger(.toggleSwitch)
                                }
                            ) {
                                if let game = appState.games.first(where: { $0.id == streak.gameId }) {
                                    coordinator.navigateTo(.gameDetail(game))
                                }
                            }
                            .id("\(refreshID)-\(streak.id)")
                        }
                    }
                    .padding(.horizontal)
                    
                case .list:
                    LazyVStack(spacing: 8) {
                        ForEach(filteredStreaks) { streak in
                            GameListItemView(
                                streak: streak,
                                isFavorite: gameCatalog.isFavorite(streak.gameId),
                                onFavoriteToggle: {
                                    gameCatalog.toggleFavorite(streak.gameId)
                                    HapticManager.shared.trigger(.toggleSwitch)
                                }
                            ) {
                                if let game = appState.games.first(where: { $0.id == streak.gameId }) {
                                    coordinator.navigateTo(.gameDetail(game))
                                }
                            }
                            .id("\(refreshID)-\(streak.id)")
                        }
                    }
                    .padding(.horizontal)
                    
                case .compact:
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(filteredStreaks) { streak in
                            GameCompactCardView(
                                streak: streak,
                                isFavorite: gameCatalog.isFavorite(streak.gameId),
                                onFavoriteToggle: {
                                    gameCatalog.toggleFavorite(streak.gameId)
                                    HapticManager.shared.trigger(.toggleSwitch)
                                }
                            ) {
                                if let game = appState.games.first(where: { $0.id == streak.gameId }) {
                                    coordinator.navigateTo(.gameDetail(game))
                                }
                            }
                            .id("\(refreshID)-\(streak.id)")
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var recentStreaksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(filteredStreaks.filter { $0.isActive }.prefix(5)) { streak in
                        if let game = appState.games.first(where: { $0.id == streak.gameId }) {
                            MiniStreakCard(streak: streak, game: game) {
                                coordinator.navigateTo(.gameDetail(game))
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func refreshData() async {
        isRefreshing = true
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await appState.refreshData()
        
        refreshID = UUID()
        isRefreshing = false
        
        HapticManager.shared.trigger(.pullToRefresh)
    }
}

// MARK: - Supporting Views (keep existing ones from the file)

struct CompactProgressBadge: View {
    let icon: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text("\(value)")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
}

struct GameEmptyState: View {
    let title: String
    let subtitle: String
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let action = action {
                Button("Add Games", action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct MiniStreakCard: View {
    let streak: GameStreak
    let game: Game
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: game.iconSystemName)
                    .font(.title2)
                    .foregroundStyle(game.backgroundColor.color)
                
                VStack(spacing: 2) {
                    Text("\(streak.currentStreak)")
                        .font(.headline)
                    Text("days")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Text(game.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 80)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}

struct EnhancedStreakCard: View {
    let streak: GameStreak
    let hasAppeared: Bool
    let animationIndex: Int
    let isFavorite: Bool
    let onFavoriteToggle: (() -> Void)?
    let onTap: () -> Void
    @Environment(AppState.self) private var appState
    
    private var game: Game? {
        appState.games.first { $0.id == streak.gameId }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Larger game icon with circle background
                ZStack {
                    Circle()
                        .fill(game?.backgroundColor.color.opacity(0.15) ?? Color.gray.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: game?.iconSystemName ?? "gamecontroller")
                        .font(.title2)
                        .foregroundStyle(game?.backgroundColor.color ?? .gray)
                }
                
                // Game info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(streak.gameName)
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                        
                        // Favorite star button
                        if let onFavoriteToggle = onFavoriteToggle {
                            Button {
                                onFavoriteToggle()
                            } label: {
                                Image(systemName: isFavorite ? "star.fill" : "star")
                                    .font(.subheadline)
                                    .foregroundStyle(isFavorite ? .yellow : .secondary)
                                    .symbolEffect(.bounce, value: isFavorite)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
                        }
                    }
                    
                    // Streak info
                    HStack(spacing: 16) {
                        // Current streak
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("\(streak.currentStreak) days")
                                .font(.subheadline)
                                .foregroundStyle(streak.isActive ? .primary : .secondary)
                        }
                        
                        // Completion rate
                        Text("\(Int(streak.completionRate * 100))% success")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(.systemGray5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .modifier(InitialAnimationModifier(hasAppeared: hasAppeared, index: animationIndex, totalCount: 10))
    }
}
