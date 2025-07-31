//
//  ContentView.swift - SIMPLIFIED WITH CONTAINER
//  Root navigation container
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var navigationNamespace
    @State private var showTabBar = true
    
    var body: some View {
        NavigationStack(path: $navigationCoordinator.path) {
            ImprovedDashboardView(showTabBar: $showTabBar)
                .id(container.notificationCoordinator.refreshID)
                .environmentObject(container.gameManagementState)
                .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                    destinationView(for: destination)
                        .navigationTransition()
                        .onAppear {
                            withAnimation(.spring(response: 0.3)) {
                                showTabBar = false
                            }
                        }
                        .onDisappear {
                            withAnimation(.spring(response: 0.3)) {
                                showTabBar = true
                            }
                        }
                }
        }
        .environmentObject(container.themeManager)
        .sheet(item: $navigationCoordinator.presentedSheet) { sheet in
            sheetView(for: sheet)
                .environmentObject(container.themeManager)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
                .presentationBackground(.ultraThinMaterial)
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
        case .gameManagement:
            GameManagementView()
                .environment(container.appState)
                .environment(container.gameCatalog)
                .environmentObject(container.gameManagementState)
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
