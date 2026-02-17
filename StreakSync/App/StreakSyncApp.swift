//
//  StreakSyncApp.swift - REFACTORED WITH APPCONTAINER
//  Main app entry point with dependency injection
//

import SwiftUI
import OSLog
import UserNotifications
import UIKit
import GoogleSignIn

// MARK: - Main App
@main
struct StreakSyncApp: App {
    @StateObject private var container = AppContainer()
    @State private var isInitialized = false
    @State private var initializationError: String?
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    private let logger = Logger(subsystem: "com.streaksync.app", category: "StreakSyncApp")
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isInitialized {
                    ContentView()
                        .environmentObject(container)
                        .environment(container.appState)
                        .environmentObject(container.navigationCoordinator)
                        .environmentObject(container.guestSessionManager)
                        .environment(container.gameCatalog)
                        .applyAppearanceMode()
                        .onOpenURL { url in
                            if GIDSignIn.sharedInstance.handle(url) { return }
                            _ = container.handleURLScheme(url)
                        }
                        .onAppear {
                            // Initialize notification delegate
                            NotificationDelegate.shared.appState = container.appState
                            NotificationDelegate.shared.navigationCoordinator = container.navigationCoordinator
                            // Bridge container into AppDelegate for remote push handling
                            appDelegate.container = container
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
 logger.info("Starting app initialization")
        
        do {
            // Initialize notification delegate dependencies early
            NotificationDelegate.shared.appState = container.appState
            NotificationDelegate.shared.navigationCoordinator = container.navigationCoordinator
            
            // Ensure Firebase Anonymous Auth for social backend
            // Uses the AuthStateManager which also handles re-authentication on sign-out
            await container.firebaseAuthManager.ensureAuthenticated()
            
            // Register categories on launch if already authorized
            let authStatus = await NotificationScheduler.shared.checkPermissionStatus()
            if authStatus == .authorized {
                await NotificationScheduler.shared.registerCategories()
            }
            
            // Load app data from local persistence first (instant UX)
            await container.appState.loadPersistedData()
            
            // Sync game results via Firestore
            await container.gameResultSyncService.syncIfNeeded()
            
            // Rebuild streaks from any newly-synced results
            await container.appState.rebuildStreaksFromResults()
            
            // Normalize streaks again after rebuild to check for gaps up to today
            // (rebuildStreaksFromResults only checks gaps between results, not gaps to today)
            await container.appState.normalizeStreaksForMissedDays()
            
            // Check for streak reminders on app launch
            await container.appState.checkAndScheduleStreakReminders()
            
            // Reconcile today's scores — republishes any that were dropped by previous failures
            if let socialService = container.socialService as? FirebaseSocialService {
                await socialService.reconcileTodaysScores(
                    results: container.appState.recentResults,
                    streaks: container.appState.streaks
                )
            }
            
            // Mark as initialized
            await MainActor.run {
                isInitialized = true
 logger.info("App initialization completed")
            }
        } catch {
 logger.error("App initialization failed: \(error.localizedDescription)")
            await MainActor.run {
                initializationError = "Failed to initialize: \(error.localizedDescription)"
            }
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
                    // Clear all persisted data then re-initialize
                    if let bundleID = Bundle.main.bundleIdentifier {
                        UserDefaults.standard.removePersistentDomain(forName: bundleID)
                    }
                    onRetry()
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
