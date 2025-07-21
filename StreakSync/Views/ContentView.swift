//
//  ContentView.swift - ENHANCED WITH AUTO-REFRESH
//  Root navigation container with auto-refresh on share extension results
//
//  FIXED: Auto-refresh when results are shared from external apps
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var coordinator = NavigationCoordinator()
    @StateObject private var appGroupBridge = AppGroupBridge.shared
    @State private var refreshID = UUID() // ADD THIS
    
    var body: some View {
        NavigationStack(path: $coordinator.path) {
            ImprovedDashboardView()
                .id(refreshID) // ADD THIS - Forces refresh
                .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .environment(coordinator)
        .sheet(item: $coordinator.presentedSheet) { sheet in
            sheetView(for: sheet)
                .environment(coordinator)
        }

        // CRITICAL: Observe AppGroupBridge for new results
        .onChange(of: appGroupBridge.lastResultProcessedTime) { _, _ in
            print("📱 ContentView detected new result processing")
            // Force refresh by changing ID
            refreshID = UUID()
        }
        // CRITICAL: Handle game result notifications
        .onReceive(NotificationCenter.default.publisher(for: .gameResultReceived)) { notification in
            handleGameResultNotification(notification)
            // Force refresh after handling
            refreshID = UUID()
        }
        // CRITICAL: Handle deep link navigation
        .onReceive(NotificationCenter.default.publisher(for: .openGameRequested)) { notification in
            handleGameDeepLink(notification)
        }
        // Replace the didBecomeActive handler with this:
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("📱 App did become active - starting continuous monitoring")
            
            // Start monitoring for results
            appGroupBridge.startMonitoringForResults()
            
            // Stop monitoring after 10 seconds to save battery
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                await MainActor.run {
                    appGroupBridge.stopMonitoringForResults()
                    print("⏱️ Stopped monitoring after 10 seconds")
                }
            }
            
            // Also refresh app state
            Task {
                if !appGroupBridge.hasNewResults {
                    await appState.refreshData()
                }
            }
        }

        // Add monitoring stop when app goes to background
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("📱 App will resign active - stopping monitoring")
            appGroupBridge.stopMonitoringForResults()
        }

        .onOpenURL { url in
            // Handle URL scheme directly - Use shared instance
            print("📱 ContentView received URL: \(url.absoluteString)")
            let handled = AppGroupBridge.shared.handleURLScheme(url)
            if !handled {
                print("❌ Failed to handle URL: \(url.absoluteString)")
            }
        }
    }
    
    // In handleGameResultNotification method
    private func handleGameResultNotification(_ notification: Notification) {
        guard let result = notification.object as? GameResult else {
            print("❌ Invalid game result in notification")
            return
        }
        
        print("✅ ContentView handling game result:")
        print("  - Game: \(result.gameName)")
        print("  - Score: \(result.displayScore)")
        
        // Add to app state (this will handle duplicate checking)
        appState.addGameResult(result)
        
        // CRITICAL: Post notification for Dashboard
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("GameResultAdded"),
                object: result
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("GameDataUpdated"),
                object: nil
            )
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        }
    }
    
    // MARK: - Handle Deep Link Navigation
    private func handleGameDeepLink(_ notification: Notification) {
        guard let gameInfo = notification.object as? [String: String],
              let gameName = gameInfo["name"] else {
            print("❌ Invalid game deep link data")
            return
        }
        
        print("🔗 Handling deep link for game: \(gameName)")
        
        // Find the game
        guard let game = appState.games.first(where: {
            $0.name.lowercased() == gameName.lowercased() ||
            $0.id.uuidString == gameInfo["id"]
        }) else {
            print("❌ Game not found: \(gameName)")
            return
        }
        
        // Navigate to the game detail view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Pop to root first
            coordinator.popToRoot()
            
            // Then navigate to game detail
            coordinator.navigateTo(.gameDetail(game))
            
            print("✅ Navigated to game detail for: \(game.displayName)")
            
            // Force a refresh of the game data
            NotificationCenter.default.post(
                name: Notification.Name("RefreshGameData"),
                object: game
            )
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: NavigationCoordinator.Destination) -> some View {
        switch destination {
        case .gameDetail(let game):
            GameDetailView(game: game)
                .environment(coordinator)
        case .streakHistory(let streak):
            StreakHistoryView(streak: streak)
                .environment(coordinator)
        case .allStreaks:
            AllStreaksView()
                .environment(coordinator)
        case .achievements:
            AchievementsView()
                .environment(coordinator)
        case .settings:
            SettingsView()
                .environment(coordinator)
        }
    }
    
    @ViewBuilder
    private func sheetView(for sheet: NavigationCoordinator.SheetDestination) -> some View {
        switch sheet {
        case .addCustomGame:
            AddCustomGameView()
                .environment(coordinator)
        case .gameResult(let result):
            GameResultDetailView(result: result)
                .environment(coordinator)
        case .achievementDetail(let achievement):
            AchievementDetailView(achievement: achievement)
                .environment(coordinator)
        }
    }
}

// MARK: - Preview Provider
#Preview {
    ContentView()
        .environment(AppState())
        .onOpenURL { url in
            // Handle URL scheme directly
            print("📱 ContentView received URL: \(url.absoluteString)")
            let handled = AppGroupBridge.shared.handleURLScheme(url)
            if !handled {
                print("❌ Failed to handle URL: \(url.absoluteString)")
            }
        }
}
