//
//  ImprovedDashboardView.swift
//  StreakSync
//
//  Created by MiT on 7/24/25.
//

import SwiftUI

struct ImprovedDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedTab = 0
    @State private var showSettings = false
    
    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var cardsScale: Double = 0.9
    @State private var cardsOpacity: Double = 0
    @State private var tabBarOffset: Double = 100
    
    var body: some View {
        ZStack {
            // Refined background with subtle gradient
            improvedBackground
            
            // Main content
            VStack(spacing: 0) {
                // Improved header
                improvedHeader
                    .opacity(headerOpacity)
                    .animation(.easeOut(duration: 0.3), value: headerOpacity)
                
                // Content area
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        
                        // Refined stats pills
                        if appState.totalActiveStreaks > 0 {
                            refinedStats
                                .padding(.horizontal, 24)
                                .padding(.bottom, 20)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                        }
                        
                        // Game carousel
                        carouselSection
                            .scaleEffect(cardsScale)
                            .opacity(cardsOpacity)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: cardsScale)
                            .animation(.easeOut(duration: 0.4), value: cardsOpacity)
                        
                        Spacer()
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                // Reduced bottom spacing for tab bar
                Color.clear.frame(height: 85) // Reduced from 100
            }
            
            // Improved tab bar with better positioning
            VStack {
                Spacer()
                improvedTabBar
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
    
    // MARK: - Improved Background
    private var improvedBackground: some View {
        ZStack {
            // Base color - more sophisticated palette
            Color(colorScheme == .dark ?
                Color(hex: "0A0E14") :    // Rich dark blue-black
                Color(hex: "F8FAFC"))     // Soft cool white
                .ignoresSafeArea()
            
            // Subtle gradient overlay
            VStack {
                LinearGradient(
                    colors: colorScheme == .dark ? [
                        Color(hex: "1E293B").opacity(0.3),  // Slate gradient
                        Color.clear
                    ] : [
                        Color(hex: "E0E7FF").opacity(0.2),  // Soft indigo
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
    
    // MARK: - Improved Header
    private var improvedHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    // App title with refined typography
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
                    
                    // Subtitle with greeting
                    Text(greeting)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
                
                // Settings button with refined style
                Button(action: {
                    HapticManager.shared.trigger(.buttonTap)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showSettings = true
                    }
                }) {
                    ZStack {
                        // Subtle background
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
            
            // Subtle separator
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
    
    // MARK: - Refined Stats
    private var refinedStats: some View {
        HStack(spacing: 12) {
            RefinedStatPill(
                icon: "flame.fill",
                value: "\(appState.totalActiveStreaks)",
                label: "Active",
                colors: colorScheme == .dark ?
                    [Color(hex: "F97316"), Color(hex: "EA580C")] :  // Orange gradient
                    [Color(hex: "FB923C"), Color(hex: "F97316")],
                animationDelay: 0.3
            )
            
            RefinedStatPill(
                icon: "checkmark.circle.fill",
                value: "\(appState.todaysResults.count)",
                label: "Today",
                colors: colorScheme == .dark ?
                    [Color(hex: "10B981"), Color(hex: "059669")] :  // Green gradient
                    [Color(hex: "34D399"), Color(hex: "10B981")],
                animationDelay: 0.4
            )
        }
    }
    
    // MARK: - Improved Tab Bar
    private var improvedTabBar: some View {
        VStack(spacing: 0) {
            // Top border with gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0),
                            Color.primary.opacity(0.08),
                            Color.primary.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
            
            HStack(spacing: 0) {
                ForEach(tabItems.indices, id: \.self) { index in
                    ImprovedTabButton(
                        item: tabItems[index],
                        isSelected: selectedTab == index,
                        action: {
                            updateTab(index)
                            tabItems[index].action()
                        }
                    )
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 28) // Reduced from 34 to use more screen space
            .background(
                ZStack {
                    // Glass effect background
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
    
    // MARK: - Tab Items
    private var tabItems: [(icon: String, title: String, action: () -> Void)] {
        [
            ("house.fill", "Home", {}),
            ("chart.line.uptrend.xyaxis", "Stats", { coordinator.navigateTo(.allStreaks) }),
            ("trophy.fill", "Awards", { coordinator.navigateTo(.achievements) }),
            ("gearshape.fill", "Settings", {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showSettings = true
                }
            })
        ]
    }
    
    // MARK: - Helpers
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
    
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
    
    private func performEntranceAnimation() {
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
    
    private func updateTab(_ index: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedTab = index
        }
        
        if index != 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTab = 0
                }
            }
        }
    }
}

// MARK: - Refined Stat Pill
struct RefinedStatPill: View {
    let icon: String
    let value: String
    let label: String
    let colors: [Color]
    let animationDelay: Double
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
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
                            LinearGradient(colors: colors.map { $0.opacity(0.2) },
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

// MARK: - Improved Tab Button
struct ImprovedTabButton: View {
    let item: (icon: String, title: String, action: () -> Void)
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: {
            HapticManager.shared.trigger(.buttonTap)
            action()
        }) {
            VStack(spacing: 5) {
                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: .medium))
                    .symbolEffect(.bounce.down, options: .speed(1.5), value: isSelected)
                
                Text(item.title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(
                isSelected ?
                    LinearGradient(
                        colors: colorScheme == .dark ?
                            [Color(hex: "818CF8"), Color(hex: "6366F1")] :
                            [Color(hex: "4338CA"), Color(hex: "5B21B6")],
                        startPoint: .top,
                        endPoint: .bottom
                    ) :
                    LinearGradient(
                        colors: [Color.secondary.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    ImprovedDashboardView()
        .environment(AppState())
        .environment(NavigationCoordinator())
}
