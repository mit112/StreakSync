//
//  MainTabView.swift
//  StreakSync
//
//  Tab-based navigation with shared tab definitions and iOS 26 enhancements
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState

    var body: some View {
        tabContent
            .onChange(of: coordinator.selectedTab) { _, _ in
                Task { @MainActor in HapticManager.shared.trigger(.buttonTap) }
            }
    }

    // MARK: - Tab Content (shared across iOS versions)

    @ViewBuilder
    private var tabContent: some View {
        sharedTabView
            .tabBarMinimizeBehavior(.onScrollDown)
    }

    private var sharedTabView: some View {
        TabView(selection: $coordinator.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: MainTab.home) {
                NavigationStack(path: $coordinator.homePath) {
                    ImprovedDashboardView()
                        .environmentObject(container.gameManagementState)
                        .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            }

            Tab("Awards", systemImage: "trophy.fill", value: MainTab.awards) {
                NavigationStack(path: $coordinator.awardsPath) {
                    LazyAwardsTabContent()
                        .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            }

            Tab("Friends", systemImage: "person.2.fill", value: MainTab.friends) {
                NavigationStack(path: $coordinator.friendsPath) {
                    LazyFriendsTabContent(socialService: container.socialService)
                }
            }

            Tab("Settings", systemImage: "gearshape.fill", value: MainTab.settings) {
                NavigationStack(path: $coordinator.settingsPath) {
                    LazySettingsTabContent()
                        .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            }
        }
    }

    // MARK: - Destination Views (single implementation)

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

        case .analyticsDashboard:
            AnalyticsDashboardView(analyticsService: container.analyticsService)
                .environmentObject(container)

        case .streakTrendsDetail(let timeRange, let game):
            StreakTrendsDetailView(
                analyticsService: container.analyticsService,
                timeRange: timeRange,
                selectedGame: game
            )
            .environment(container.appState)
            .environmentObject(container)

        case .account:
            AccountView(authManager: container.firebaseAuthManager)
                .environmentObject(container)
        }
    }
}

// MARK: - Lazy Tab Wrappers

private struct LazyAwardsTabContent: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @State private var hasBeenSelected = false

    var body: some View {
        Group {
            if hasBeenSelected {
                TieredAchievementsGridView()
            } else {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: coordinator.selectedTab) { _, newTab in
            if newTab == .awards && !hasBeenSelected { hasBeenSelected = true }
        }
        .onAppear {
            if coordinator.selectedTab == .awards { hasBeenSelected = true }
        }
    }
}

private struct LazyFriendsTabContent: View {
    let socialService: any SocialService
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @State private var hasBeenSelected = false

    var body: some View {
        Group {
            if hasBeenSelected {
                FriendsView(socialService: socialService)
            } else {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: coordinator.selectedTab) { _, newTab in
            if newTab == .friends && !hasBeenSelected { hasBeenSelected = true }
        }
        .onAppear {
            if coordinator.selectedTab == .friends { hasBeenSelected = true }
        }
    }
}

private struct LazySettingsTabContent: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @State private var hasBeenSelected = false

    var body: some View {
        Group {
            if hasBeenSelected {
                SettingsView()
            } else {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: coordinator.selectedTab) { _, newTab in
            if newTab == .settings && !hasBeenSelected { hasBeenSelected = true }
        }
        .onAppear {
            if coordinator.selectedTab == .settings { hasBeenSelected = true }
        }
    }
}
