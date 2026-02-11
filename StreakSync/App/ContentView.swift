//
//  ContentView.swift
//  Root view with tab-based navigation
//
/* test
 * CONTENTVIEW - ROOT UI CONTAINER
 * 
 * WHAT THIS FILE DOES:
 * This is the main UI container that holds everything the user sees. It's like the "frame" of a picture -
 * it doesn't contain the actual content, but it provides the structure and handles important app-wide
 * behaviors like responding to the app going to the background or coming back to the foreground.
 * 
 * WHY IT EXISTS:
 * Every SwiftUI app needs a root view that manages the overall app structure. This file serves as the
 * bridge between the app's core services (managed by AppContainer) and the user interface. It handles
 * app lifecycle events and coordinates between different parts of the UI.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This is the main UI entry point that users interact with
 * - Manages app lifecycle (when app goes to background/foreground)
 * - Handles modal presentations (sheets that pop up over the main content)
 * - Coordinates achievement celebrations across the entire app
 * - Sets up the overall visual theme and background
 * 
 * WHAT IT REFERENCES:
 * - MainTabView: The main tab-based navigation system
 * - AppContainer: Access to all app services and data
 * - NavigationCoordinator: Manages navigation state and modal presentations
 * - StreakSyncColors: Provides the app's visual theme
 * - Various sheet views: AddCustomGameView, GameResultDetailView, etc.
 * 
 * WHAT REFERENCES IT:
 * - StreakSyncApp.swift: This is the main view shown after app initialization
 * - No other views directly reference this (it's the root)
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. SCENE PHASE HANDLING IMPROVEMENTS:
 *    - The current scene phase handling is basic - could add more sophisticated state management
 *    - Consider adding analytics tracking for app usage patterns
 *    - Add memory pressure monitoring when app goes to background
 *    - Implement proper state restoration when app returns from background
 * 
 * 2. SHEET MANAGEMENT ENHANCEMENTS:
 *    - The sheetView function could be moved to a separate file for better organization
 *    - Add sheet presentation animations and transitions
 *    - Consider adding sheet dismissal handling for unsaved changes
 *    - Implement sheet stacking for complex navigation flows
 * 
 * 3. THEME AND STYLING IMPROVEMENTS:
 *    - The background gradient is hard-coded - could be made configurable
 *    - Add support for dynamic type changes
 *    - Consider adding accessibility improvements for the root container
 *    - Implement theme switching animations
 * 
 * 4. ERROR HANDLING:
 *    - Add error boundary handling for the root view
 *    - Implement crash recovery mechanisms
 *    - Add user-friendly error messages for critical failures
 * 
 * 5. PERFORMANCE OPTIMIZATIONS:
 *    - Consider lazy loading of sheet views
 *    - Add view recycling for better memory management
 *    - Implement view preloading for smoother transitions
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add unit tests for scene phase handling
 *    - Test sheet presentation logic
 *    - Add UI tests for the root view behavior
 * 
 * 7. ACCESSIBILITY ENHANCEMENTS:
 *    - Add accessibility labels for the root container
 *    - Implement VoiceOver navigation improvements
 *    - Add support for accessibility shortcuts
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - @EnvironmentObject gives access to shared data from parent views
 * - @Environment gives access to system-provided values like scenePhase and colorScheme
 * - .sheet() is a SwiftUI modifier that presents modal views
 * - .onChange() is a SwiftUI modifier that responds to value changes
 * - ScenePhase tracks whether the app is active, inactive, or in the background
 * - @ViewBuilder is a Swift attribute that lets you build views conditionally
 * - The body property is where you define what the view looks like
 */

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var guestSessionManager: GuestSessionManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    
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
                .foregroundStyle(.white)
            }
            
            MainTabView()
                .achievementCelebrations(coordinator: container.achievementCelebrationCoordinator)
                .sheet(item: $navigationCoordinator.presentedSheet) { sheet in
                    sheetView(for: sheet)
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(20)
                        .presentationBackground(.ultraThinMaterial)
                }
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
