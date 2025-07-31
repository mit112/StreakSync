//
//  ImprovedDashboardView.swift
//  StreakSync
//
//  Enhanced dashboard with games as centerpiece and optimized layout
//

import SwiftUI

struct ImprovedDashboardView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Binding var showTabBar: Bool
    @Environment(GameCatalog.self) private var gameCatalog
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("gameDisplayMode") private var displayMode: GameDisplayMode = .card
    @EnvironmentObject private var gameManagementState: GameManagementState
    @State private var searchText = ""
    @State private var showOnlyActive = false
    @State private var refreshID = UUID()
    @State private var isRefreshing = false
    @State private var isSearching = false
    @State private var showSearchClear = false
    @State private var hasInitiallyAppeared = false
    @State private var selectedTab = 0
    @State private var selectedGameSection: GameSection = .favorites
    @State private var selectedCategory: GameCategory? = nil
    @State private var selectedSort: GameSortOption = .lastPlayed
    @State private var sortDirection: SortDirection = .descending
    @FocusState private var isSearchFieldFocused: Bool
    
    init(showTabBar: Binding<Bool> = .constant(true)) {
        self._showTabBar = showTabBar
    }
    
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
    
    // Update the filteredStreaks computed property:
    private var filteredStreaks: [GameStreak] {
        // Get the games to show based on section
        let gamesToShow: [Game]
        switch selectedGameSection {
        case .favorites:
            gamesToShow = gameCatalog.favoriteGames
        case .all:
            gamesToShow = gameCatalog.allGames
        }
        
        // Apply custom ordering from GameManagementState
        let orderedGames = gameManagementState.orderedGames(from: gamesToShow)
        
        // Filter out archived games
        let activeGames = orderedGames.filter { game in
            !gameManagementState.isArchived(game.id)
        }
        
        // Filter streaks to only include non-archived games
        var streaks = appState.streaks.filter { streak in
            activeGames.contains { $0.id == streak.gameId }
        }
        
        // Apply category filter
        if let selectedCategory = selectedCategory {
            streaks = streaks.filter { streak in
                if let game = appState.games.first(where: { $0.id == streak.gameId }) {
                    return game.category == selectedCategory
                }
                return false
            }
        }
        
        // Apply existing filters
        if showOnlyActive {
            streaks = streaks.filter(\.isActive)
        }
        
        if !searchText.isEmpty {
            streaks = streaks.filter {
                $0.gameName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sorting - respecting the custom order when sort is not applied
        if selectedSort == .lastPlayed && sortDirection == .descending {
            // This is the default - respect custom game order
            let gameOrderMap = Dictionary(uniqueKeysWithValues: activeGames.enumerated().map { ($1.id, $0) })
            return streaks.sorted { streak1, streak2 in
                let order1 = gameOrderMap[streak1.gameId] ?? Int.max
                let order2 = gameOrderMap[streak2.gameId] ?? Int.max
                return order1 < order2
            }
        } else {
            // Apply the selected sort
            return streaks.sorted(by: selectedSort, direction: sortDirection, games: appState.games)
        }
    }
    
    // Add this property to get available categories:
    private var availableCategories: [GameCategory] {
        let gamesToShow: [Game]
        switch selectedGameSection {
        case .favorites:
            gamesToShow = gameCatalog.favoriteGames
        case .all:
            gamesToShow = gameCatalog.allGames
        }
        
        // Get unique categories from the games being shown
        let categories = Set(gamesToShow.map { $0.category })
        return Array(categories).sorted { $0.displayName < $1.displayName }
    }
    
    private var activeStreakCount: Int {
        appState.streaks.filter(\.isActive).count
    }
    
    private var longestStreakCount: Int {
        appState.streaks.map(\.maxStreak).max() ?? 0
    }
    
    private var todayCompletedCount: Int {
        appState.streaks.filter { streak in
            guard let lastPlayed = streak.lastPlayedDate else { return false }
            return Calendar.current.isDateInToday(lastPlayed) && streak.currentStreak > 0
        }.count
    }
    
    // Replace your current body with this:
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content - keep your existing PullToRefreshContainer
            PullToRefreshContainer(isRefreshing: $isRefreshing) {
                await refreshData()
            } content: {
                VStack(spacing: 16) {
                    // Your existing content...
                    compactHeaderSection
                        .modifier(InitialAnimationModifier(hasAppeared: hasInitiallyAppeared, index: 0, totalCount: 3))
                    
                    enhancedSearchSection
                        .modifier(InitialAnimationModifier(hasAppeared: hasInitiallyAppeared, index: 1, totalCount: 3))
                    
                    gamesCenterpieceSection
                        .modifier(InitialAnimationModifier(hasAppeared: hasInitiallyAppeared, index: 2, totalCount: 3))
                    
                    Spacer(minLength: 120)
                }
                .padding(.vertical)
            }
            .background(themeManager.subtleBackgroundGradient)
            
            // Lowered tab bar
            modernTabBar
                .tabBarTransition(isVisible: showTabBar)
        }
        .navigationBarHidden(true)
        .onAppear {
            if !hasInitiallyAppeared {
                withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                    hasInitiallyAppeared = true
                }
            }
        }
    }
    
    // MARK: - Compact Header Section
    private var compactHeaderSection: some View {
        VStack(spacing: 8) {
            // App name and settings
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
                    
                    Button {
                        coordinator.navigateTo(.settings)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .pressable(hapticType: .buttonTap)
                    .accessibilityLabel("Settings")
                }
            }
            
            // Personality-rich greeting
            HStack {
                Text(greetingText)
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            
        }
        .padding(.horizontal)
    }
    
    // MARK: - Enhanced Search Section
    private var enhancedSearchSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .symbolEffect(.pulse, options: .speed(0.5), value: isSearching)
                    
                    TextField("Search games...", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFieldFocused)
                        .onChange(of: searchText) { _, newValue in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showSearchClear = !newValue.isEmpty
                                isSearching = !newValue.isEmpty
                            }
                        }
                        .onChange(of: isSearchFieldFocused) { _, isFocused in
                            isSearching = isFocused
                        }
                        .accessibilityLabel("Search games")
                    
                    if showSearchClear {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                searchText = ""
                                isSearching = false
                                isSearchFieldFocused = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                
                // Compact active filter chip
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showOnlyActive.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showOnlyActive ? "flame.fill" : "flame")
                            .font(.caption)
                        if showOnlyActive {
                            Text("Active")
                                .font(.caption2.weight(.medium))
                        }
                    }
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
    
    // MARK: - Games Centerpiece Section (Updated)
    private var gamesCenterpieceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Updated header with section selector, sort, and view mode
            HStack {
                Text("Your Games")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                // Sort options menu (now just an icon button)
                CompactSortOptionsMenu(
                    selectedSort: $selectedSort,
                    sortDirection: $sortDirection
                )
                
                // View mode toggle
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
                    Image(systemName: displayMode.iconName)
                        .font(.body)
                        .foregroundStyle(.blue)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.blue.opacity(0.1))
                        )
                }
                
                // Section selector
                Menu {
                    ForEach(GameSection.allCases, id: \.self) { section in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedGameSection = section
                                // Reset category filter when switching sections
                                selectedCategory = nil
                            }
                        } label: {
                            Label(section.rawValue, systemImage: section.icon)
                        }
                    }
                    
                    Divider()
                    
                    // Add Manage Games option
                    Button {
                        coordinator.navigateTo(.gameManagement)
                    } label: {
                        HStack {
                            Label("Manage Games", systemImage: "slider.horizontal.3")
                            if !gameManagementState.archivedGameIds.isEmpty {
                                Text("(\(gameManagementState.archivedGameIds.count) archived)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
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
            
            Group {
                if filteredStreaks.isEmpty {
                    // Add frame to fill available space and center content
                    EmptyStateView(
                        icon: "gamecontroller",
                        title: searchText.isEmpty ?
                        (selectedGameSection == .favorites ? "No Favorite Games" : "No Games Yet") :
                            "No Results",
                        subtitle: searchText.isEmpty ?
                        (selectedGameSection == .favorites ?
                         "Star your favorite games to see them here" :
                            "No games available") :
                            "Try adjusting your search or filters",
                        action: nil
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)  // ← ADD THIS
                    .padding(.horizontal)
                    .padding(.top, 40)  // ← ADD THIS for better vertical centering
                } else {
                    // Switch based on display mode
                    switch displayMode {
                    case .card:
                        // Your existing LazyVStack implementation
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
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                    coordinator.navigateTo(.gameDetail(game))
                                                }
                                    }
                                }
                                .scaleEffect(1.0) // Add this
                                .animation(.spring(response: 0.2), value: streak.id)
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
    }
    
    
    
    // MARK: - Modern Tab Bar (with smooth transitions)
    private var modernTabBar: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "house.fill",
                title: "Home",
                isSelected: selectedTab == 0
            ) {
                HapticManager.shared.trigger(.buttonTap)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    selectedTab = 0
                }
            }
            
            TabBarButton(
                icon: "chart.line.uptrend.xyaxis",
                title: "Stats",
                isSelected: selectedTab == 1
            ) {
                HapticManager.shared.trigger(.buttonTap)
                
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    selectedTab = 1
                }
                
                // Smooth transition before navigation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        coordinator.navigateTo(.allStreaks)
                    }
                    
                    // Reset after navigation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = 0
                        }
                    }
                }
            }
            
            TabBarButton(
                icon: "trophy.fill",
                title: "Awards",
                isSelected: selectedTab == 2
            ) {
                HapticManager.shared.trigger(.buttonTap)
                
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    selectedTab = 2
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        coordinator.navigateTo(.achievements)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = 0
                        }
                    }
                }
            }
            
            TabBarButton(
                icon: "gearshape.fill",
                title: "Settings",
                isSelected: selectedTab == 3
            ) {
                HapticManager.shared.trigger(.buttonTap)
                
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    selectedTab = 3
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        coordinator.navigateTo(.settings)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = 0
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Helper Methods
    private func refreshData() async {
        isRefreshing = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Refresh logic here
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            refreshID = UUID()
            isRefreshing = false
        }
    }
}

// MARK: - New Components



// Compact Progress Badge
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

// Enhanced Streak Card - more prominent for centerpiece
struct EnhancedStreakCard: View {
    let streak: GameStreak
    let hasAppeared: Bool
    let animationIndex: Int
    let isFavorite: Bool  // NEW: Add favorite status
    let onFavoriteToggle: (() -> Void)?  // NEW: Add favorite toggle callback
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
                    HStack(spacing: 8) {  // NEW: Add HStack for name and star
                        Text(streak.gameName)
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                        
                        // NEW: Favorite star button
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
                    
                    HStack(spacing: 8) {
                        Text(streak.lastPlayedText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        if streak.isActive {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                
                Spacer()
                
                // Prominent streak display
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(streak.currentStreak)")
                        .font(.title.bold())
                        .foregroundStyle(streak.isActive ? .orange : .secondary)
                        .contentTransition(.numericText())
                    
                    Text("streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                streak.isActive ?
                                    .orange.opacity(0.3) :
                                        .clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .pressable(hapticType: .buttonTap, scaleAmount: 0.98)
        .modifier(InitialAnimationModifier(hasAppeared: hasAppeared, index: animationIndex, totalCount: 10))
    }
}

// MARK: - Existing Components (Keep these)

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: (() -> Void)?
    
    @State private var isAnimating = false
    @State private var particleOffset: CGFloat = 0
    @EnvironmentObject private var themeManager: ThemeManager
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated illustration
            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                themeManager.primaryAccent.opacity(0.3),
                                themeManager.primaryAccent.opacity(0.05)
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                // Floating particles
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(themeManager.primaryAccent.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .offset(
                            x: cos(CGFloat(index) * .pi / 3) * 60,
                            y: sin(CGFloat(index) * .pi / 3) * 60
                        )
                        .offset(y: particleOffset)
                        .animation(
                            Animation.easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: particleOffset
                        )
                }
                
                // Main icon
                Image(systemName: icon)
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeManager.primaryAccent,
                                themeManager.primaryAccent.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(isAnimating ? 5 : -5))
                    .animation(
                        Animation.easeInOut(duration: 4.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            .frame(height: 160)
            
            // Text content
            VStack(spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Action button if provided
            if let action = action {
                Button(action: action) {
                    Text("Get Started")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(themeManager.primaryAccent)
                        )
                }
                .pressable(hapticType: .buttonTap)
                .padding(.top, 8)
            }
        }
        .padding()
        .onAppear {
            isAnimating = true
            withAnimation {
                particleOffset = -10
            }
        }
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .symbolEffect(.bounce.down, options: .speed(1.2), value: isSelected)
                
                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(
                isSelected ?
                AnyShapeStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                ) :
                    AnyShapeStyle(Color.secondary.opacity(0.7))
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

#if DEBUG
struct ImprovedDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        ImprovedDashboardView()
            .environment(AppState())
            .environmentObject(NavigationCoordinator())
            .environmentObject(ThemeManager.shared)
    }
}
#endif

// Add this extension to EnhancedStreakCard for backward compatibility
extension EnhancedStreakCard {
    // Convenience initializer for existing code that doesn't use favorites
    init(
        streak: GameStreak,
        hasAppeared: Bool,
        animationIndex: Int,
        onTap: @escaping () -> Void
    ) {
        self.init(
            streak: streak,
            hasAppeared: hasAppeared,
            animationIndex: animationIndex,
            isFavorite: false,
            onFavoriteToggle: nil,
            onTap: onTap
        )
    }
}


// MARK: - Preset Empty States
extension EmptyStateView {
    static func noGames(action: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon: "gamecontroller",
            title: NSLocalizedString("empty.no_games", comment: ""),
            subtitle: NSLocalizedString("empty.no_games_message", comment: ""),
            action: action
        )
    }
    
    static func noFavorites(action: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon: "star",
            title: "No Favorite Games",
            subtitle: "Star your favorite games to see them here",
            action: action
        )
    }
    
    static func noResults(searchTerm: String) -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results",
            subtitle: "No games found matching '\(searchTerm)'",
            action: nil
        )
    }
    
    static func noStreaks(action: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon: "flame",
            title: NSLocalizedString("empty.no_streaks", comment: ""),
            subtitle: NSLocalizedString("empty.no_streaks_message", comment: ""),
            action: action
        )
    }
}
