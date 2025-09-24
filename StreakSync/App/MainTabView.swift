//
//  MainTabView.swift
//  StreakSync
//
//  SIMPLIFIED Native iOS 26 TabView
//  FIXED: Updated to use new StreakSyncColors system
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    
    var body: some View {
        if #available(iOS 26.0, *) {
            iOS26TabView
        } else {
            standardTabView
        }
    }
    
    // MARK: - iOS 26 TabView (SIMPLIFIED)
    @available(iOS 26.0, *)
    private var iOS26TabView: some View {
        TabView(selection: $coordinator.selectedTab) {
            // Home Tab
            NavigationStack(path: $coordinator.homePath) {
                ImprovedDashboardView()
                    .environmentObject(container.gameManagementState)
                    .id(container.notificationCoordinator.refreshID)
                    .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(MainTab.home)
            
            
            // Awards Tab
            NavigationStack(path: $coordinator.awardsPath) {
                TieredAchievementsGridView()
                    .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label("Awards", systemImage: "trophy.fill")
            }
            .tag(MainTab.awards)
            
            // Settings Tab
            NavigationStack(path: $coordinator.settingsPath) {
                SettingsView()
                    .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(MainTab.settings)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(StreakSyncColors.primary(for: colorScheme))
        .onChange(of: coordinator.selectedTab) { _, _ in
            HapticManager.shared.trigger(.buttonTap)
        }
    }
    
    // MARK: - iOS 26 Enhanced Destination Views (SIMPLIFIED)
    @available(iOS 26.0, *)
    @ViewBuilder
    private func ios26DestinationView(
        for destination: NavigationCoordinator.Destination,
        namespace: Namespace.ID
    ) -> some View {
        Group {  // Wrap in Group to ensure single view type
            switch destination {
            case .gameDetail(let game):
                GameDetailView(game: game)
                    .environmentObject(container)
                    .navigationTransition(.zoom(sourceID: "game-\(game.id)", in: namespace))
                
            case .streakHistory(let streak):
                StreakHistoryView(streak: streak)
                    .environmentObject(container)
                    .navigationTransition(.zoom(sourceID: "streak-\(streak.id)", in: namespace))
                
            case .allStreaks:
                AllStreaksView()
                    .environmentObject(container)
                    .navigationTransition(.automatic)
                
            case .achievements:
                TieredAchievementsGridView()
                    .environmentObject(container)
                    .navigationTransition(.automatic)
                
            case .settings:
                SettingsView()
                    .environmentObject(container)
                    .navigationTransition(.automatic)
                    
            case .gameManagement:
                GameManagementView()
                    .environment(container.appState)
                    .environment(container.gameCatalog)
                    .environmentObject(container.gameManagementState)
                    .navigationTransition(.automatic)
                    
            case .tieredAchievementDetail(let achievement):
                TieredAchievementDetailView(achievement: achievement)
                    .environmentObject(container)
                    .navigationTransition(.zoom(
                        sourceID: "achievement-\(achievement.id)",
                        in: namespace
                    ))
            }
        }
    }
    
    // MARK: - Standard TabView (Pre-iOS 26)
    private var standardTabView: some View {
        TabView(selection: $coordinator.selectedTab) {
            // Home Tab
            NavigationStack(path: $coordinator.homePath) {
                ImprovedDashboardView()
                    .environmentObject(container.gameManagementState)
                    .id(container.notificationCoordinator.refreshID)
                    .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(MainTab.home)
            
            
            // Awards Tab
            NavigationStack(path: $coordinator.awardsPath) {
                TieredAchievementsGridView()
                    .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label("Awards", systemImage: "trophy.fill")
            }
            .tag(MainTab.awards)
            
            // Settings Tab
            NavigationStack(path: $coordinator.settingsPath) {
                SettingsView()
                    .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(MainTab.settings)
        }
        .tint(StreakSyncColors.primary(for: colorScheme))
        .onChange(of: coordinator.selectedTab) { _, _ in
            HapticManager.shared.trigger(.buttonTap)
        }
    }
    
    // MARK: - Destination Views
    @ViewBuilder
    private func destinationView(for destination: NavigationCoordinator.Destination) -> some View {
        switch destination {
        case .gameDetail(let game):
            GameDetailView(game: game)
                .environmentObject(container)
            
        case .streakHistory(let streak):
            StreakHistoryView(streak: streak)
                .environmentObject(container)
            
        case .allStreaks:
            AllStreaksView()
                .environmentObject(container)
            
        case .achievements:
            TieredAchievementsGridView()
                .environmentObject(container)
            
        case .settings:
            SettingsView()
                .environmentObject(container)
                
        case .gameManagement:
            GameManagementView()
                .environment(container.appState)
                .environment(container.gameCatalog)
                .environmentObject(container.gameManagementState)
                
        case .tieredAchievementDetail(let achievement):
            TieredAchievementDetailView(achievement: achievement)
                .environmentObject(container)
        }
    }
}

// MARK: - Tab Switch Animation Configuration
@available(iOS 26.0, *)
struct TabSwitchConfiguration {
    static let animationDuration: TimeInterval = 0.3
    static let hapticFeedback: HapticManager.HapticType = .buttonTap
    static let navigationDelay: TimeInterval = 0.15
    
    static func animate<Result>(
        _ body: () throws -> Result
    ) rethrows -> Result {
        try withAnimation(.smooth(duration: animationDuration)) {
            try body()
        }
    }
}
