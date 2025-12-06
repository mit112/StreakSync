//
//  StreakSyncApp.swift - REFACTORED WITH APPCONTAINER
//  Main app entry point with dependency injection
//

/*
 * STREAKSYNC APP ENTRY POINT - MAIN APPLICATION BOOTSTRAP
 * 
 * WHAT THIS FILE DOES:
 * This is the main entry point of the StreakSync iOS app. It's the first file that runs when the app launches.
 * It sets up the entire application by creating an AppContainer (dependency injection system) and managing
 * the app's initialization process.
 * 
 * WHY IT EXISTS:
 * Every iOS app needs a main entry point. This file serves as the "front door" of the application,
 * responsible for bootstrapping all the core services and setting up the app's architecture before
 * the user sees any content.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This is the foundation of the entire app - without it, nothing else works
 * - Manages app lifecycle and initialization state
 * - Sets up dependency injection (AppContainer) that all other parts of the app depend on
 * - Handles deep links and URL schemes
 * - Manages error states and recovery
 * 
 * WHAT IT REFERENCES:
 * - AppContainer: The dependency injection system that manages all app services
 * - ContentView: The main UI that users see after initialization
 * - NotificationDelegate: Handles push notifications
 * - InitializationView/InitializationErrorView: Loading and error screens
 * 
 * WHAT REFERENCES IT:
 * - Nothing directly references this file (it's the entry point)
 * - The iOS system calls this when the app launches
 * - Xcode uses this as the main target entry point
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. ERROR HANDLING IMPROVEMENTS:
 *    - The current error handling is basic (just shows a string)
 *    - Consider creating an AppError enum with specific error types
 *    - Add more detailed error logging for debugging
 *    - Implement different recovery strategies for different error types
 * 
 * 2. INITIALIZATION OPTIMIZATION:
 *    - The initialization is currently sequential - could be parallelized
 *    - Consider showing progress indicators for different initialization steps
 *    - Add timeout handling for initialization that takes too long
 * 
 * 3. DEPENDENCY INJECTION ENHANCEMENT:
 *    - The current setup injects many dependencies manually
 *    - Consider using a more sophisticated DI framework for larger apps
 *    - Could implement lazy loading of services that aren't immediately needed
 * 
 * 4. TESTING IMPROVEMENTS:
 *    - Add unit tests for initialization logic
 *    - Mock the AppContainer for testing different initialization scenarios
 *    - Test error recovery paths
 * 
 * 5. ACCESSIBILITY ENHANCEMENTS:
 *    - The loading views have basic accessibility but could be more descriptive
 *    - Add VoiceOver announcements for initialization progress
 *    - Consider different accessibility needs during loading states
 * 
 * 6. PERFORMANCE CONSIDERATIONS:
 *    - Consider preloading critical data in the background
 *    - Implement app state restoration for faster subsequent launches
 *    - Add memory pressure monitoring during initialization
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - @main tells Swift this is the app's entry point
 * - @StateObject creates and manages the AppContainer's lifecycle
 * - The Group with conditional views is a common SwiftUI pattern for different app states
 * - .task is a SwiftUI modifier that runs async code when the view appears
 * - Dependency injection (AppContainer) is a design pattern that makes code more testable and modular
 */

import SwiftUI
import OSLog
import UserNotifications
import UIKit
import FirebaseCore
import FirebaseAuth

// MARK: - Main App
@main
struct StreakSyncApp: App {
    @StateObject private var container = AppContainer()
    @State private var isInitialized = false
    @State private var initializationError: String?
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    private let logger = Logger(subsystem: "com.streaksync.app", category: "StreakSyncApp")
    
    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isInitialized {
                    ContentView()
                        .environmentObject(container)
                        .environment(container.appState)
                        .environmentObject(container.navigationCoordinator)
                        .environmentObject(container.guestSessionManager)
                        .environmentObject(container.userDataSyncService)
                        .environmentObject(BetaFeatureFlags.shared)
                        .environment(container.gameCatalog)
                        .applyAppearanceMode()
                        .onOpenURL { url in
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
        logger.info("🚀 Starting app initialization")
        
        // Initialize notification delegate dependencies early
        NotificationDelegate.shared.appState = container.appState
        NotificationDelegate.shared.navigationCoordinator = container.navigationCoordinator
        
        // Ensure Firebase Anonymous Auth for social backend
        await ensureAnonymousAuth()
        
        // Register categories on launch if already authorized
        let authStatus = await NotificationScheduler.shared.checkPermissionStatus()
        if authStatus == .authorized {
            await NotificationScheduler.shared.registerCategories()
        }
        
        // Load app data from local persistence first (instant UX)
        await container.appState.loadPersistedData()
        
        // Perform CloudKit user data sync (if iCloud available)
        await container.userDataSyncService.syncIfNeeded()
        
        // Rebuild streaks from any newly-synced results
        await container.appState.rebuildStreaksFromResults()
        
        // Normalize streaks again after rebuild to check for gaps up to today
        // (rebuildStreaksFromResults only checks gaps between results, not gaps to today)
        await container.appState.normalizeStreaksForMissedDays()
        
        // Check for streak reminders on app launch
        await container.appState.checkAndScheduleStreakReminders()
        
        // Start network monitoring to flush offline queue when network returns
        container.networkMonitor.startMonitoring()
        
        // Mark as initialized
        await MainActor.run {
            isInitialized = true
            logger.info("✅ App initialization completed")
        }
    }
    
    private func ensureAnonymousAuth() async {
        guard Auth.auth().currentUser == nil else { return }
        do {
            _ = try await Auth.auth().signInAnonymously()
            logger.info("✅ Firebase anonymous auth established")
        } catch {
            logger.error("⚠️ Firebase anonymous auth failed: \(error.localizedDescription)")
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
