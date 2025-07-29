//
//  ImprovedDashboardView.swift
//  StreakSync
//
//  Enhanced dashboard with warm personality, theme support, full animation integration, and tab bar
//

import SwiftUI

struct ImprovedDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationCoordinator.self) private var coordinator
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("userName") private var userName: String = ""
    
    @State private var searchText = ""
    @State private var showOnlyActive = false
    @State private var refreshID = UUID()
    @State private var isRefreshing = false
    @State private var isSearching = false
    @State private var showSearchClear = false
    @State private var hasInitiallyAppeared = false
    @State private var selectedTab = 0
    @State private var showSettings = false
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            PullToRefreshContainer(isRefreshing: $isRefreshing) {
                await refreshData()
            } content: {
                VStack(spacing: 24) {
                    // Warm header with personality
                    headerSection
                    
                    // Search and filter with animations
                    searchAndFilterSection
                        .modifier(InitialAnimationModifier(hasAppeared: hasInitiallyAppeared, index: 0, totalCount: 3))
                    
                    // Game cards with animations
                    gameCardsSection
                        .modifier(InitialAnimationModifier(hasAppeared: hasInitiallyAppeared, index: 1, totalCount: 3))
                    
                    // Spacer for tab bar
                    Spacer(minLength: 100)
                }
                .padding(.vertical)
            }
            .background(themeManager.subtleBackgroundGradient)
            
            // Modern tab bar
            modernTabBar
        }
        .navigationBarHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GameDataUpdated"))) { _ in
            refreshID = UUID()
        }
        .task {
            // Use task to set this after initial animations complete
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            hasInitiallyAppeared = true
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Header Section with Warm Personality
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                // Dynamic greeting with personality
                Text(greetingText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.primary, Color.primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .modifier(InitialAnimationModifier(hasAppeared: hasInitiallyAppeared, index: 0, totalCount: 4))
                
                // Motivational message
                Text(motivationalMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut, value: motivationalMessage)
                    .modifier(InitialAnimationModifier(hasAppeared: hasInitiallyAppeared, index: 1, totalCount: 4))
                
                // Quick stats with enhanced animations
                HStack(spacing: 16) {
                    EnhancedQuickStatPill(
                        icon: "flame.fill",
                        value: "\(activeStreaksCount)",
                        label: "Active",
                        gradient: LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        hasAppeared: hasInitiallyAppeared,
                        animationIndex: 2
                    )
                    
                    EnhancedQuickStatPill(
                        icon: "checkmark.circle.fill",
                        value: "\(todayCompletedCount)",
                        label: "Today",
                        gradient: LinearGradient(
                            colors: [Color.green, Color.mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        hasAppeared: hasInitiallyAppeared,
                        animationIndex: 3
                    )
                }
                .padding(.top, 8)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Search and Filter Section
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search bar with animated clear button
            HStack {
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
                    
                    if showSearchClear {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                searchText = ""
                                isSearching = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }
            .padding(.horizontal)
            
            // Filter toggle with AnimatedToggle
            HStack {
                Spacer()
                HStack {
                    Label("Show active only", systemImage: "flame.fill")
                        .font(.subheadline)
                    AnimatedToggle(isOn: $showOnlyActive, label: "")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                Spacer()
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Game Cards Section
    private var gameCardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Games")
                    .font(.title3.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.primary, Color.primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
                
                // Add game button with animations
                Button {
                    coordinator.presentSheet(.addCustomGame)
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundStyle(.blue)
            }
            .padding(.horizontal)
            
            if isLoadingGames {
                // Skeleton loading state
                VStack(spacing: 12) {
                    ForEach(0..<3) { _ in
                        SkeletonLoadingView(height: 120, cornerRadius: 16)
                            .padding(.horizontal)
                    }
                }
            } else if filteredGames.isEmpty {
                emptyStateView
                    .modifier(InitialAnimationModifier(hasAppeared: hasInitiallyAppeared, index: 0, totalCount: 1))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(filteredGames.enumerated()), id: \.element.id) { index, game in
                        AnimatedGameCard(
                            game: game,
                            animationIndex: index,
                            hasInitiallyAppeared: hasInitiallyAppeared,
                            onTap: {
                                coordinator.navigateTo(.gameDetail(game))
                            }
                        )
                        .id("\(game.id)-\(refreshID)")
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Empty State with Personality
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.bounce, options: .speed(0.5))
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No games yet!" : "No games found")
                    .font(.title3.bold())
                
                Text(searchText.isEmpty ?
                     "Add your first puzzle game to start tracking" :
                     "Try adjusting your search")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if searchText.isEmpty {
                LoadingButton(
                    "Add Your First Game",
                    icon: "plus.circle.fill"
                ) {
                    coordinator.presentSheet(.addCustomGame)
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Modern Tab Bar
    private var modernTabBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.primary.opacity(0.05))
                .frame(height: 0.5)
            
            HStack(spacing: 0) {
                TabBarButton(
                    icon: "house.fill",
                    title: "Home",
                    isSelected: selectedTab == 0,
                    action: { updateTab(0) }
                )
                
                TabBarButton(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Stats",
                    isSelected: selectedTab == 1,
                    action: {
                        updateTab(1)
                        coordinator.navigateTo(.allStreaks)
                    }
                )
                
                TabBarButton(
                    icon: "trophy.fill",
                    title: "Awards",
                    isSelected: selectedTab == 2,
                    action: {
                        updateTab(2)
                        coordinator.navigateTo(.achievements)
                    }
                )
                
                TabBarButton(
                    icon: "gearshape.fill",
                    title: "Settings",
                    isSelected: selectedTab == 3,
                    action: {
                        updateTab(3)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showSettings = true
                        }
                    }
                )
            }
            .padding(.top, 8)
            .padding(.bottom, 34)
            .background(
                ZStack {
                    // Glass effect
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .background(
                            Color(colorScheme == .dark ?
                                UIColor.systemBackground :
                                UIColor.secondarySystemBackground).opacity(0.85)
                        )
                    
                    // Subtle gradient overlay
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.02),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
            )
        }
    }
    
    // MARK: - Tab Update with Animation
    private func updateTab(_ index: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedTab = index
        }
        
        // Reset selection after navigation
        if index != 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTab = 0
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var activeStreaksCount: Int {
        appState.streaks.filter { streak in
            guard let game = appState.games.first(where: { $0.id == streak.gameId }) else { return false }
            return game.isActiveToday
        }.count
    }
    
    private var todayCompletedCount: Int {
        appState.games.filter { $0.hasPlayedToday }.count
    }
    
    private var filteredGames: [Game] {
        let games = showOnlyActive ?
            appState.games.filter { $0.isActiveToday } :
            appState.games
        
        if searchText.isEmpty {
            return games.sorted { game1, game2 in
                // Sort by: today's completion, then active status, then name
                if game1.hasPlayedToday != game2.hasPlayedToday {
                    return game1.hasPlayedToday
                }
                if game1.isActiveToday != game2.isActiveToday {
                    return game1.isActiveToday
                }
                return game1.displayName < game2.displayName
            }
        } else {
            return games.filter { game in
                game.displayName.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.displayName < $1.displayName }
        }
    }
    
    private var isLoadingGames: Bool {
        appState.games.isEmpty && !appState.isDataLoaded
    }
    
    // MARK: - Warm Personality Helpers
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
    
    private var motivationalMessage: String {
        if activeStreaksCount == 0 {
            return "Ready to start your first streak? Let's go!"
        } else if todayCompletedCount == activeStreaksCount && activeStreaksCount > 0 {
            return "Perfect day! All \(activeStreaksCount) streaks completed! 🎉"
        } else if todayCompletedCount > 0 {
            return "Great progress! \(activeStreaksCount - todayCompletedCount) more to go!"
        } else {
            let messages = [
                "Your streaks are waiting for you!",
                "Let's keep the momentum going!",
                "Every puzzle counts. You've got this!",
                "Small steps lead to big streaks!",
                "Consistency is your superpower!",
                "Time to add to your collection!",
                "Your future self will thank you!"
            ]
            return messages.randomElement() ?? ""
        }
    }
    
    // MARK: - Refresh Data
    private func refreshData() async {
        isRefreshing = true
        
        await appState.refreshData()
        
        withAnimation {
            refreshID = UUID()
            isRefreshing = false
        }
    }
}

// MARK: - Tab Bar Button Component
private struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: {
            HapticManager.shared.trigger(.buttonTap)
            action()
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .symbolEffect(.bounce.down, options: .speed(1.5), value: isSelected)
                
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(
                isSelected ?
                    AnyShapeStyle(
                        LinearGradient(
                            colors: colorScheme == .dark ?
                                [Color.blue.opacity(0.8), Color.purple.opacity(0.8)] :
                                [Color.blue, Color.purple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    ) :
                    AnyShapeStyle(Color.secondary.opacity(0.7))
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Initial Animation Modifier
private struct InitialAnimationModifier: ViewModifier {
    let hasAppeared: Bool
    let index: Int
    let totalCount: Int
    
    func body(content: Content) -> some View {
        if !hasAppeared {
            content
                .opacity(0)
                .offset(y: 20)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.8)
                    .delay(Double(index) * 0.05),
                    value: hasAppeared
                )
        } else {
            content
        }
    }
}

// MARK: - Enhanced Quick Stat Pill with animations
private struct EnhancedQuickStatPill: View {
    let icon: String
    let value: String
    let label: String
    let gradient: LinearGradient
    let hasAppeared: Bool
    let animationIndex: Int
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isPressed.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(gradient)
                    .symbolEffect(.bounce, value: isPressed)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                gradient.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        .modifier(InitialAnimationModifier(hasAppeared: hasAppeared, index: animationIndex, totalCount: 4))
    }
}

// MARK: - Animated Game Card
struct AnimatedGameCard: View {
    let game: Game
    let animationIndex: Int
    let hasInitiallyAppeared: Bool
    let onTap: () -> Void
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var showCheckmark = false
    @State private var hasAnimatedCheckmark = false
    
    private var streak: GameStreak? {
        appState.getStreak(for: game)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: game.iconSystemName)
                        .font(.title2)
                        .foregroundStyle(game.backgroundColor.color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game.displayName)
                            .font(.headline)
                        
                        if let lastPlayed = game.lastPlayedDate {
                            Text(lastPlayed.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if game.hasPlayedToday {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                            .opacity(showCheckmark ? 1 : 0)
                            .scaleEffect(showCheckmark ? 1 : 0.5)
                    }
                }
                
                // Streak info with animations
                if let streak = streak, streak.currentStreak > 0 {
                    HStack(spacing: 16) {
                        AnimatedStreakStat(
                            value: "\(streak.currentStreak)",
                            label: "Current",
                            color: Color.orange
                        )
                        
                        AnimatedStreakStat(
                            value: "\(streak.maxStreak)",
                            label: "Best",
                            color: .secondary
                        )
                        
                        Spacer()
                        
                        Text("\(streak.totalGamesPlayed) played")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .modifier(InitialAnimationModifier(hasAppeared: hasInitiallyAppeared, index: animationIndex, totalCount: 10))
        .onAppear {
            if game.hasPlayedToday && !hasAnimatedCheckmark {
                withAnimation(.easeInOut.delay(Double(animationIndex) * 0.1)) {
                    showCheckmark = true
                }
                hasAnimatedCheckmark = true
            }
        }
    }
}

// MARK: - Animated Streak Stat Component
private struct AnimatedStreakStat: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(color)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.shared.trigger(.buttonTap)
                }
            }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ImprovedDashboardView()
            .environment(AppState())
            .environment(NavigationCoordinator())
            .environmentObject(ThemeManager.shared)
    }
}
