//
//  StreakSyncApp.swift - REFACTORED WITH APPCONTAINER
//  Main app entry point with dependency injection
//

import SwiftUI
import OSLog
import UserNotifications

// MARK: - Main App
@main
struct StreakSyncApp: App {
    @StateObject private var container = AppContainer()
    @State private var isInitialized = false
    @State private var initializationError: String?
    
    private let logger = Logger(subsystem: "com.streaksync.app", category: "StreakSyncApp")
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isInitialized {
                    ContentView()
                        .environmentObject(container)
                        .environment(container.appState)
                        .environmentObject(container.navigationCoordinator)
                        .environment(container.gameCatalog)
                        .applyAppearanceMode()
                        .onOpenURL { url in
                            _ = container.handleURLScheme(url)
                        }
                        .onAppear {
                            // Initialize notification delegate
                            NotificationDelegate.shared.appState = container.appState
                            NotificationDelegate.shared.navigationCoordinator = container.navigationCoordinator
                        }
                } else if let error = initializationError {
                    InitializationErrorView(error: error) {
                        retryInitialization()
                    }
                } else {
                    InitializationView()
                }
            }
            .task {
                await initializeApp()
            }
        }
    }
    
    // MARK: - App Initialization
    private func initializeApp() async {
        logger.info("🚀 Starting app initialization")
        
        // Load app data
        await container.appState.loadPersistedData()
        
        // Check for streak reminders on app launch
        await container.appState.checkAndScheduleStreakReminders()
        
        // Mark as initialized
        await MainActor.run {
            isInitialized = true
            logger.info("✅ App initialization completed")
        }
    }
    
    private func retryInitialization() {
        initializationError = nil
        isInitialized = false
        
        Task {
            await initializeApp()
        }
    }
    

}

// MARK: - Initialization Views
struct InitializationView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)
            
            Text("StreakSync")
                .font(.largeTitle.weight(.bold))
            
            Text("Track your daily puzzle streaks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Loading your data...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top)
        }
        .padding(40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("StreakSync is loading your data")
    }
}

struct InitializationErrorView: View {
    let error: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("Something went wrong")
                .font(.title2.weight(.semibold))
            
            Text(error)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                Button("Try Again") {
                    onRetry()
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding()
                .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                
                Button("Reset App Data") {
                    // Clear all data and restart
                    Task { @MainActor in
                        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                        exit(0) // Force app restart
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Initialization error: \(error)")
    }
}
