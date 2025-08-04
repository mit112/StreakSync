//
//  MainTabView.swift
//  StreakSync
//
//  Main tab container following iOS navigation patterns
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(AppState.self) private var appState
    
    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            // MARK: - Home Tab
            NavigationStack(path: $coordinator.homePath) {
                ImprovedDashboardView()
                    .environmentObject(container.gameManagementState)
                    .id(container.notificationCoordinator.refreshID)
                    .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                        destinationView(for: destination)
                            .toolbar(.hidden, for: .tabBar)
                    }
            }
            .tabItem {
                Label(MainTab.home.title, systemImage: MainTab.home.icon)
            }
            .tag(MainTab.home)
            
            // MARK: - Stats Tab
            NavigationStack(path: $coordinator.statsPath) {
                AllStreaksView()
                    .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                        destinationView(for: destination)
                            .toolbar(.hidden, for: .tabBar)
                    }
            }
            .tabItem {
                Label(MainTab.stats.title, systemImage: MainTab.stats.icon)
            }
            .tag(MainTab.stats)
            
            // MARK: - Awards Tab
            NavigationStack(path: $coordinator.awardsPath) {
                TieredAchievementsGridView()
                    .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                        destinationView(for: destination)
                            .toolbar(.hidden, for: .tabBar)
                    }
            }
            .tabItem {
                Label(MainTab.awards.title, systemImage: MainTab.awards.icon)
            }
            .tag(MainTab.awards)
            
            // MARK: - Settings Tab
            NavigationStack(path: $coordinator.settingsPath) {
                SettingsView()
                    .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                        destinationView(for: destination)
                            .toolbar(.hidden, for: .tabBar)
                    }
            }
            .tabItem {
                Label(MainTab.settings.title, systemImage: MainTab.settings.icon)
            }
            .tag(MainTab.settings)
        }
        .tint(themeManager.primaryAccent)
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
