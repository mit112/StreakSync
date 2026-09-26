//
//  ContentView.swift
//  StreakSync
//
//  Root view with tab-based navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var guestSessionManager: GuestSessionManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showFirstLaunchNotificationPrompt = false
    @State private var didCheckFirstLaunchNotificationPrompt = false
    
    var body: some View {
        VStack(spacing: 0) {
            if guestSessionManager.isGuestMode {
                HStack {
                    Image(systemName: "person.circle.fill")
                    Text("Guest Mode Active")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange)
                // Black on orange is ~9.5:1 (WCAG AA); white was ~2.2:1 and failed.
                .foregroundStyle(.black)
            }
            
            if container.appState.reviewModeEnabled {
                HStack {
                    Image(systemName: "eye.fill")
                    Text("Demo Data Active")
                        .fontWeight(.semibold)
                    Spacer()
                    Button("Exit") {
                        Task { await container.appState.exitReviewMode() }
                    }
                    .fontWeight(.semibold)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                // Same treatment as Guest Mode above: black on orange is ~9.5:1 (WCAG AA).
                .background(Color.orange)
                .foregroundStyle(.black)
                .accessibilityElement(children: .contain)
            }

            // Sync status banner — shows when offline or scores are pending.
            // Suppressed on Friends, which owns that tab's single offline/failure
            // explanation; unchanged on Home, Awards, and Settings (DESIGN_AUDIT §4.5).
            if navigationCoordinator.selectedTab != .friends {
                SyncStatusBanner(
                    syncState: container.gameResultSyncService.syncState,
                    pendingScoreCount: container.socialService.pendingScoreCount
                )
            }
            
            MainTabView()
                .firstShareCelebration()
                .achievementCelebrations(coordinator: container.achievementCelebrationCoordinator)
                .sheet(item: $navigationCoordinator.presentedSheet) { sheet in
                    sheetView(for: sheet)
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(CornerRadius.sheet)
                        .presentationBackground(.ultraThinMaterial)
                }
        }
        .sheet(isPresented: $showFirstLaunchNotificationPrompt) {
            NotificationPermissionFlowView()
        }
        .task {
            await evaluateFirstLaunchNotificationPromptIfNeeded()
        }
        .background(
            Color(.systemGroupedBackground)
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
            Task {
                await container.handleAppBecameActive()
                await evaluateFirstLaunchNotificationPromptIfNeeded()
            }
        case .inactive, .background:
            break
        @unknown default:
            break
        }
    }

    @MainActor
    private func evaluateFirstLaunchNotificationPromptIfNeeded() async {
        guard !didCheckFirstLaunchNotificationPrompt else { return }
        didCheckFirstLaunchNotificationPrompt = true
        guard await NotificationPermissionFlowViewModel.shouldShowFirstLaunchPrompt() else { return }
        NotificationPermissionFlowViewModel.markFirstLaunchPromptShown()
        showFirstLaunchNotificationPrompt = true
    }
    
    // MARK: - Sheet Views
    @ViewBuilder
    private func sheetView(for sheet: NavigationCoordinator.SheetDestination) -> some View {
        switch sheet {
        case .gameResult(let result):
            GameResultDetailView(result: result)
                .environmentObject(container)
            
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
