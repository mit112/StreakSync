//
//  ContentView.swift
//  Root view with tab-based navigation
//  FIXED: Removed deprecated ThemeManager references
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        MainTabView()
            .achievementCelebrations(coordinator: container.achievementCelebrationCoordinator)
            .sheet(item: $navigationCoordinator.presentedSheet) { sheet in
                sheetView(for: sheet)
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(20)
                    .presentationBackground(.ultraThinMaterial)
            }
            .background(
                StreakSyncColors.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()
            )
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
    }
    
    // MARK: - Scene Phase Handling
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // No need to update theme - it follows system automatically
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
            
        // Legacy achievement detail removed
        case .tieredAchievementDetail(let achievement):
            navigationCoordinator.tieredAchievementDetailSheet(for: achievement)
                .environmentObject(container)
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(AppContainer())
        .environmentObject(NavigationCoordinator())
}
