//
//  ContentView.swift - UPDATED WITH THEME SUPPORT
//  Root navigation container with theme management
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var coordinator = NavigationCoordinator()
    @StateObject private var appGroupBridge = AppGroupBridge.shared
    @State private var refreshID = UUID()
    
    // MARK: - Theme Support
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationStack(path: $coordinator.path) {
            ImprovedDashboardView()
                .id(refreshID)
                .navigationDestination(for: NavigationCoordinator.Destination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .environment(coordinator)
        .environmentObject(themeManager) // Provide theme to all children
        .sheet(item: $coordinator.presentedSheet) { sheet in
            sheetView(for: sheet)
                .environment(coordinator)
                .environmentObject(themeManager)
        }
        // Apply theme background to entire app
        .background(themeManager.primaryBackground)
        // Update theme when app becomes active
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                themeManager.updateThemeIfNeeded()
            }
        }
        // Existing observers...
        .onChange(of: appGroupBridge.lastResultProcessedTime) { _, _ in
            print("📱 ContentView detected new result processing")
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameResultReceived)) { notification in
            handleGameResultNotification(notification)
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openGameRequested)) { notification in
            handleGameDeepLink(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("📱 App did become active - starting continuous monitoring")
            
            appGroupBridge.startMonitoringForResults()
            
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                await MainActor.run {
                    appGroupBridge.stopMonitoringForResults()
                    print("⏱️ Stopped monitoring after 10 seconds")
                }
            }
            
            Task {
                if !appGroupBridge.hasNewResults {
                    await appState.refreshData()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("📱 App will resign active - stopping monitoring")
            appGroupBridge.stopMonitoringForResults()
        }
        .onOpenURL { url in
            print("📱 ContentView received URL: \(url.absoluteString)")
            let handled = AppGroupBridge.shared.handleURLScheme(url)
            if !handled {
                print("❌ Failed to handle URL: \(url.absoluteString)")
            }
        }
    }
    
    // MARK: - Handle Game Result Notification
    private func handleGameResultNotification(_ notification: Notification) {
        guard let result = notification.object as? GameResult else {
            print("❌ Invalid game result in notification")
            return
        }
        
        print("✅ ContentView handling game result:")
        print("  - Game: \(result.gameName)")
        print("  - Score: \(result.displayScore)")
        
        appState.addGameResult(result)
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("GameResultAdded"),
                object: result
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("GameDataUpdated"),
                object: nil
            )
            
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
        
        guard let game = appState.games.first(where: {
            $0.name.lowercased() == gameName.lowercased() ||
            $0.id.uuidString == gameInfo["id"]
        }) else {
            print("❌ Game not found: \(gameName)")
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            coordinator.popToRoot()
            coordinator.navigateTo(.gameDetail(game))
            
            print("✅ Navigated to game detail for: \(game.displayName)")
            
            NotificationCenter.default.post(
                name: Notification.Name("RefreshGameData"),
                object: game
            )
        }
    }
    
    // MARK: - Destination Views
    @ViewBuilder
    private func destinationView(for destination: NavigationCoordinator.Destination) -> some View {
        switch destination {
        case .gameDetail(let game):
            GameDetailView(game: game)
                .environment(coordinator)
                .environmentObject(themeManager)
        case .streakHistory(let streak):
            StreakHistoryView(streak: streak)
                .environment(coordinator)
                .environmentObject(themeManager)
        case .allStreaks:
            AllStreaksView()
                .environment(coordinator)
                .environmentObject(themeManager)
        case .achievements:
            AchievementsView()
                .environment(coordinator)
                .environmentObject(themeManager)
        case .settings:
            SettingsView()
                .environment(coordinator)
                .environmentObject(themeManager)
        }
    }
    
    // MARK: - Sheet Views
    @ViewBuilder
    private func sheetView(for sheet: NavigationCoordinator.SheetDestination) -> some View {
        switch sheet {
        case .addCustomGame:
            AddCustomGameView()
                .environment(coordinator)
                .environmentObject(themeManager)
        case .gameResult(let result):
            GameResultDetailView(result: result)
                .environment(coordinator)
                .environmentObject(themeManager)
        case .achievementDetail(let achievement):
            AchievementDetailView(achievement: achievement)
                .environment(coordinator)
                .environmentObject(themeManager)
        }
    }
}

// MARK: - Preview Provider
#Preview {
    ContentView()
        .environment(AppState())
        .onOpenURL { url in
            print("📱 ContentView received URL: \(url.absoluteString)")
            let handled = AppGroupBridge.shared.handleURLScheme(url)
            if !handled {
                print("❌ Failed to handle URL: \(url.absoluteString)")
            }
        }
}
