//
//  ContentView.swift
//  Root view with tab-based navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        MainTabView()
            .achievementCelebrations(coordinator: container.achievementCelebrationCoordinator)
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
                
        case .tieredAchievementDetail(let achievement):
            navigationCoordinator.tieredAchievementDetailSheet(for: achievement)
                .environmentObject(container)
        }
    }
}
