//
//  ContentView.swift - SIMPLIFIED WITH CONTAINER
//  Root navigation container
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationStack(path: $navigationCoordinator.path) {
            ImprovedDashboardView()
                .id(container.notificationCoordinator.refreshID)
                .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .environmentObject(container.themeManager)
        .sheet(item: $navigationCoordinator.presentedSheet) { sheet in
            sheetView(for: sheet)
                .environmentObject(container.themeManager)
        }
        .background(container.themeManager.primaryBackground)
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    // MARK: - Scene Phase Handling
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            container.themeManager.updateThemeIfNeeded()
            Task {
                await container.handleAppBecameActive()
            }
        case .inactive:
            container.handleAppWillResignActive()
        case .background:
            break
        @unknown default:
            break
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
            AchievementsView()
                .environmentObject(container)
            
        case .settings:
            SettingsView()
                .environmentObject(container)
        }
    }
    
    // MARK: - Sheet Views
    @ViewBuilder
    private func sheetView(for sheet: NavigationCoordinator.SheetDestination) -> some View {
        switch sheet {
        case .addCustomGame:
            AddCustomGameView()
                .environmentObject(container)
            
        case .gameResult(let result):
            GameResultDetailView(result: result)
                .environmentObject(container)
            
        case .achievementDetail(let achievement):
            AchievementDetailView(achievement: achievement)
                .environmentObject(container)
        }
    }
}
