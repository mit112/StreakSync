//
//  ImprovedDashboardView.swift
//  StreakSync
//
//  Enhanced dashboard with warm personality, theme support, and full animation integration
//

import SwiftUI

struct ImprovedDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationCoordinator.self) private var coordinator
    @EnvironmentObject private var themeManager: ThemeManager
    @AppStorage("userName") private var userName: String = ""
    
    @State private var searchText = ""
    @State private var showOnlyActive = false
    @State private var refreshID = UUID()
    @State private var isRefreshing = false
    @State private var isSearching = false
    @State private var showSearchClear = false
    @State private var hasInitiallyAppeared = false
    
    var body: some View {
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
            }
            .padding(.vertical)
        }
        .background(themeManager.subtleBackgroundGradient)
        .navigationBarHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GameDataUpdated"))) { _ in
            refreshID = UUID()
        }
        .task {
            // Use task to set this after initial animations complete
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            hasInitiallyAppeared = true
        }
    }
    
    // MARK: - Header Section with Warm Personality
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Settings button with animations
            HStack {
                Spacer()
                Button {
                    coordinator.navigateTo(.settings)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .pressable(hapticType: .buttonTap)
                .hoverable()
            }
            .padding(.trailing)
            
            VStack(alignment: .leading, spacing: 12) {
                // Dynamic greeting with personality
                AnimatedGradientText(
                    text: greetingText,
                    font: .system(size: 32, weight: .bold, design: .rounded)
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
                        gradient: themeManager.statOrangeGradient,
                        hasAppeared: hasInitiallyAppeared,
                        animationIndex: 2
                    )
                    
                    EnhancedQuickStatPill(
                        icon: "checkmark.circle.fill",
                        value: "\(todayCompletedCount)",
                        label: "Today",
                        gradient: themeManager.statGreenGradient,
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
                        .onChange(of: searchText) { _, newValue in
                            withAnimation(SpringPreset.snappy) {
                                showSearchClear = !newValue.isEmpty
                                isSearching = !newValue.isEmpty
                            }
                        }
                    
                    if showSearchClear {
                        Button {
                            withAnimation(SpringPreset.snappy) {
                                searchText = ""
                                isSearching = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .pressable(hapticType: .buttonTap, scaleAmount: 0.8)
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
                .pressable(hapticType: .toggleSwitch, scaleAmount: 0.98)
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
                .glassButton()
                .pressable(hapticType: .buttonTap)
                .hoverable()
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
                .foregroundStyle(themeManager.accentGradient)
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
        .glassCard()
        .padding(.horizontal)
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

// MARK: - Initial Animation Modifier
private struct InitialAnimationModifier: ViewModifier {
    let hasAppeared: Bool
    let index: Int
    let totalCount: Int
    
    func body(content: Content) -> some View {
        if !hasAppeared {
            content
                .staggeredAppearance(index: index, totalCount: totalCount)
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
            withAnimation(SpringPreset.bouncy) {
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
        .pressable(hapticType: .buttonTap, scaleAmount: 0.95)
        .hoverable(scaleAmount: 1.05)
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
        InteractiveCard {
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
                            color: themeManager.streakActiveColor
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
        } onTap: {
            onTap()
        }
        .modifier(InitialAnimationModifier(hasAppeared: hasInitiallyAppeared, index: animationIndex, totalCount: filteredGamesCount))
        .onAppear {
            if game.hasPlayedToday && !hasAnimatedCheckmark {
                withAnimation(.easeInOut.delay(Double(animationIndex) * 0.1)) {
                    showCheckmark = true
                }
                hasAnimatedCheckmark = true
            }
        }
    }
    
    private var filteredGamesCount: Int {
        // This is a workaround - ideally this should be passed from parent
        10
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

// MARK: - Fixed Interactive Card
struct InteractiveCard<Content: View>: View {
    @ViewBuilder let content: Content
    let onTap: (() -> Void)?
    
    init(@ViewBuilder content: () -> Content, onTap: (() -> Void)? = nil) {
        self.content = content()
        self.onTap = onTap
    }
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            content
        }
        .buttonStyle(InteractiveCardButtonStyle())
    }
}

// MARK: - Interactive Card Button Style
struct InteractiveCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassCard()
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(SpringPreset.snappy, value: configuration.isPressed)
            .overlay {
                if configuration.isPressed {
                    Color.black.opacity(0.05)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.shared.trigger(.buttonTap)
                }
            }
            .hoverable(scaleAmount: 1.02)
    }
}

// MARK: - Spring Presets
//enum SpringPreset {
//    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.8)
//    static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.85)
//    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
//}

// MARK: - Preview
#Preview {
    NavigationStack {
        ImprovedDashboardView()
            .environment(AppState())
            .environment(NavigationCoordinator())
            .environmentObject(ThemeManager.shared)
    }
}
