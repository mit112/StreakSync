//
//  DashboardV5View.swift
//  StreakSync
//
//  Created by MiT on 7/24/25.
//

import SwiftUI

struct DashboardV5View: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedTab = 0
    @State private var showSettings = false
    
    // Animation states with explicit values
    @State private var headerOpacity: Double = 0
    @State private var cardsScale: Double = 0.9
    @State private var cardsOpacity: Double = 0
    @State private var tabBarOffset: Double = 100
    
    var body: some View {
        ZStack {
            // Clean background
            backgroundLayer
            
            // Main content
            VStack(spacing: 0) {
                // Modern header with explicit animation
                modernHeader
                    .opacity(headerOpacity)
                    .animation(.easeOut(duration: 0.3), value: headerOpacity)
                
                // Centered card content
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        
                        // Stats pills with staggered animation
                        if appState.totalActiveStreaks > 0 {
                            compactStats
                                .padding(.horizontal, 24)
                                .padding(.bottom, 24)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                        }
                        
                        // Centered game carousel with explicit animation
                        carouselSection
                            .scaleEffect(cardsScale)
                            .opacity(cardsOpacity)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: cardsScale)
                            .animation(.easeOut(duration: 0.4), value: cardsOpacity)
                        
                        Spacer()
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                // Bottom spacing for tab bar
                Color.clear.frame(height: 100)
            }
            
            // Modern tab bar with slide-up animation
            VStack {
                Spacer()
                modernTabBar
                    .offset(y: tabBarOffset)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: tabBarOffset)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.setup(with: appState)
            performEntranceAnimation()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Entrance Animation (Best Practice)
    private func performEntranceAnimation() {
        // Stagger animations for smooth entrance
        withAnimation(.easeOut(duration: 0.3)) {
            headerOpacity = 1
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            cardsScale = 1
            cardsOpacity = 1
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.2)) {
            tabBarOffset = 0
        }
    }
    
    // MARK: - Clean Background
    private var backgroundLayer: some View {
        ZStack {
            // More sophisticated base color
            Color(colorScheme == .dark ?
                Color(hex: "0A0E14") :    // Rich dark blue-black
                Color(hex: "F8FAFC"))     // Soft cool white
                .ignoresSafeArea()
            
            // Enhanced gradient overlay
            VStack {
                LinearGradient(
                    colors: colorScheme == .dark ? [
                        Color(hex: "1E293B").opacity(0.3),
                        Color.clear
                    ] : [
                        Color(hex: "E0E7FF").opacity(0.2),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .frame(height: 400)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Modern Header
    private var modernHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    // Enhanced title with gradient
                    Text("StreakSync")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: colorScheme == .dark ? [
                                    Color(hex: "E0E7FF"),
                                    Color(hex: "C7D2FE")
                                ] : [
                                    Color(hex: "4338CA"),
                                    Color(hex: "6366F1")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    // Add greeting below title
                    Text(greeting)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
                
                // Enhanced settings button
                Button(action: {
                    HapticManager.shared.trigger(.buttonTap)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showSettings = true
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.primary.opacity(0.05),
                                        Color.primary.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 42, height: 42)
                        
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundColor(.primary.opacity(0.6))
                            .rotationEffect(.degrees(showSettings ? 90 : 0))
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showSettings)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Add subtle separator
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0),
                            Color.primary.opacity(0.05),
                            Color.primary.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal, 24)
        }
    }
    
    // 3. ADD GREETING HELPER (add this computed property):
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
    
    // MARK: - Compact Stats with Staggered Animation
    private var compactStats: some View {
        HStack(spacing: 12) {
            CompactStatPill(
                icon: "flame.fill",
                value: "\(appState.totalActiveStreaks)",
                label: "Active",
                color: .orange,
                animationDelay: 0.3
            )
            
            CompactStatPill(
                icon: "checkmark.circle.fill",
                value: "\(appState.todaysResults.count)",
                label: "Today",
                color: .green,
                animationDelay: 0.4
            )
        }
    }
    
    // MARK: - Carousel Section
    private var carouselSection: some View {
        OptimizedGameCardCarousel(
            games: appState.games,
            streaks: appState.streaks,
            todaysResults: appState.todaysResults,
            onCardTap: { game in
                HapticManager.shared.trigger(.buttonTap)
                coordinator.navigateTo(.gameDetail(game))
            }
        )
        .frame(height: GameCardDimensions.height)
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
                                Color(hex: "0A0E14").opacity(0.85) :
                                Color(hex: "F8FAFC").opacity(0.85))
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
}

// MARK: - Custom Button Style for Better Animations
//struct ScaleButtonStyle: ButtonStyle {
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
//            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
//    }
//}

// MARK: - Tab Bar Button with Proper Animation
private struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
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
//            .foregroundStyle(
//                isSelected ?
//                    LinearGradient(
//                        colors: colorScheme == .dark ?
//                            [Color(hex: "818CF8"), Color(hex: "6366F1")] :
//                            [Color(hex: "4338CA"), Color(hex: "5B21B6")],
//                        startPoint: .top,
//                        endPoint: .bottom
//                    ) :
//                    LinearGradient(
//                        colors: [Color.secondary.opacity(0.7)],
//                        startPoint: .top,
//                        endPoint: .bottom
//                    )
//            )
//            .frame(maxWidth: .infinity)
//            .contentShape(Rectangle())
//            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - Compact Stat Pill with Entrance Animation
//internal struct CompactStatPill: View {
//    let icon: String
//    let value: String
//    let label: String
//    let color: Color
//    let animationDelay: Double
//    
//    @State private var appeared = false
//    
//    var body: some View {
//        HStack(spacing: 10) {
//            Image(systemName: icon)
//                .font(.system(size: 16, weight: .medium))
//                .foregroundStyle(color)
//            
//            HStack(spacing: 4) {
//                Text(value)
//                    .font(.system(size: 18, weight: .bold, design: .rounded))
//                    .foregroundColor(.primary)
//                    .contentTransition(.numericText())
//                
//                Text(label)
//                    .font(.system(size: 14, weight: .medium, design: .rounded))
//                    .foregroundStyle(.secondary)
//            }
//        }
//        .padding(.horizontal, 16)
//        .padding(.vertical, 10)
//        .background(
//            Capsule()
//                .fill(Color.primary.opacity(0.05))
//                .overlay(
//                    Capsule()
//                        .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
//                )
//        )
//        .scaleEffect(appeared ? 1 : 0.8)
//        .opacity(appeared ? 1 : 0)
//        .onAppear {
//            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(animationDelay)) {
//                appeared = true
//            }
//        }
//    }
//}

struct CompactStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let animationDelay: Double
    
    @State private var isVisible = false
    @Environment(\.colorScheme) private var colorScheme
    
    // Define gradient colors based on the stat type
    private var gradientColors: [Color] {
        if label == "Active" {
            return colorScheme == .dark ?
                [Color(hex: "F97316"), Color(hex: "EA580C")] :
                [Color(hex: "FB923C"), Color(hex: "F97316")]
        } else {
            return colorScheme == .dark ?
                [Color(hex: "10B981"), Color(hex: "059669")] :
                [Color(hex: "34D399"), Color(hex: "10B981")]
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: gradientColors,
                                 startPoint: .topLeading,
                                 endPoint: .bottomTrailing)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            LinearGradient(colors: gradientColors.map { $0.opacity(0.2) },
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(animationDelay)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Optimized Game Card Carousel
struct OptimizedGameCardCarousel: View {
    let games: [Game]
    let streaks: [GameStreak]
    let todaysResults: [GameResult]
    let onCardTap: (Game) -> Void
    
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGSize = .zero
    @GestureState private var isDragging: Bool = false
    
    private let cardSpacing: CGFloat = 30
    private let swipeThreshold: CGFloat = 50
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<games.count, id: \.self) { index in
                    OptimizedGameCard(
                        game: games[index],
                        streak: streaks.first { $0.gameId == games[index].id },
                        todayResult: todaysResults.first { $0.gameId == games[index].id },
                        isActive: index == currentIndex,
                        index: index,
                        currentIndex: currentIndex,
                        geometry: geometry,
                        cardSpacing: cardSpacing,
                        dragOffset: dragOffset,
                        onTap: {
                            if index == currentIndex {
                                onCardTap(games[index])
                            }
                        }
                    )
                }
            }
        }
        .gesture(
            DragGesture()
                .updating($isDragging) { _, state, _ in
                    state = true
                }
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if abs(value.translation.width) > swipeThreshold {
                            if value.translation.width < 0 && currentIndex < games.count - 1 {
                                currentIndex += 1
                                HapticManager.shared.trigger(.buttonTap)
                            } else if value.translation.width > 0 && currentIndex > 0 {
                                currentIndex -= 1
                                HapticManager.shared.trigger(.buttonTap)
                            }
                        }
                        dragOffset = .zero
                    }
                }
        )
    }
}

// MARK: - Optimized Game Card
private struct OptimizedGameCard: View {
    let game: Game
    let streak: GameStreak?
    let todayResult: GameResult?
    let isActive: Bool
    let index: Int
    let currentIndex: Int
    let geometry: GeometryProxy
    let cardSpacing: CGFloat
    let dragOffset: CGSize
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var offset: CGFloat {
        let centerX = geometry.size.width / 2
        let cardCenterX = GameCardDimensions.width / 2
        let baseOffset = centerX - cardCenterX
        
        let indexDifference = CGFloat(index - currentIndex)
        let cardOffset = indexDifference * (GameCardDimensions.width + cardSpacing)
        
        return baseOffset + cardOffset + dragOffset.width
    }
    
    private var scale: CGFloat {
        index == currentIndex ? 1 : 0.9
    }
    
    private var opacity: Double {
        index == currentIndex ? 1 : 0.6
    }
    
    private var cardColors: [Color] {
        switch game.name.lowercased() {
        case "wordle": return [Color(hex: "22C55E"), Color(hex: "16A34A")]
        case "quordle": return [Color(hex: "3B82F6"), Color(hex: "2563EB")]
        case "nerdle": return [Color(hex: "A855F7"), Color(hex: "9333EA")]
        case "heardle": return [Color(hex: "EC4899"), Color(hex: "DB2777")]
        default: return [Color.gray, Color.gray.opacity(0.7)]
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(colorScheme == .dark ? Color(hex: "1A1A1B") : .white))
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(colorScheme == .dark ? Color(hex: "1A1A1B") : .white))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    cardColors[0].opacity(0.3),
                                    cardColors[0].opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                    radius: 12,
                    x: 0,
                    y: 8
                )
            
            CardContent(
                game: game,
                streak: streak,
                todayResult: todayResult,
                cardColors: cardColors,
                isActive: isActive
            )
        }
        .frame(width: GameCardDimensions.width, height: GameCardDimensions.height)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .scaleEffect(scale)
        .opacity(opacity)
        .offset(x: offset)
        .zIndex(index == currentIndex ? 3 : 1)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentIndex)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
        .allowsHitTesting(index == currentIndex)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Card Content (Separated for Performance)
private struct CardContent: View {
    let game: Game
    let streak: GameStreak?
    let todayResult: GameResult?
    let cardColors: [Color]
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: cardColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: game.iconSystemName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.displayName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(todayResult != nil ? "Completed today" : game.category.displayName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(todayResult != nil ? .green : .secondary)
                }
                
                Spacer()
                
                if todayResult != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.bottom, 32)
            
            Spacer()
            
            // Streak info
            if let streak = streak {
                StreakInfoView(streak: streak, cardColors: cardColors)
            } else {
                PlayNowView(cardColors: cardColors)
            }
            
            Spacer()
            
            // Footer
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary.opacity(0.7))
                
                Text("View Details")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .opacity(isActive ? 0.8 : 0)
            .animation(.easeInOut(duration: 0.3), value: isActive)
        }
        .padding(24)
    }
}

// MARK: - Streak Info View
private struct StreakInfoView: View {
    let streak: GameStreak
    let cardColors: [Color]
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse, options: .repeating.speed(0.3))
                
                Text("\(streak.currentStreak)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }
            
            Text("Day Streak")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            
            HStack(spacing: 32) {
                StatView(value: "\(streak.totalGamesPlayed)", label: "Played")
                StatView(value: "\(Int(streak.completionRate * 100))%", label: "Success", color: .green)
                StatView(value: "\(streak.maxStreak)", label: "Best", color: cardColors[0])
            }
        }
    }
}

// MARK: - Play Now View
private struct PlayNowView: View {
    let cardColors: [Color]
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: cardColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "play.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
            
            Text("Play Now")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            
            Text("Start your streak today!")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Stat View
private struct StatView: View {
    let value: String
    let label: String
    var color: Color = .primary
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText(countsDown: false))
            
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview
#Preview("Dashboard V5 Optimized") {
    NavigationStack {
        DashboardV5View()
            .environment(AppState())
            .environment(NavigationCoordinator())
    }
}
