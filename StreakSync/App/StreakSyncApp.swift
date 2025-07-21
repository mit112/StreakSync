//
//  StreakSyncApp.swift - ENHANCED WITH PERSISTENCE INITIALIZATION
//  Main app entry point with persistence support
//
//  ADDED: Proper data loading lifecycle and persistence integration
//

import SwiftUI
import OSLog
import UserNotifications

// MARK: - Main App (Enhanced with Persistence)
@main
struct StreakSyncApp: App {
    @State private var appState = AppState()
    @State private var isInitialized = false
    @State private var initializationError: String?
    
    private let logger = Logger(subsystem: "com.streaksync.app", category: "StreakSyncApp")
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isInitialized {
                    ContentView()
                        .environment(appState)
                        .applyAppearanceMode()  // This handles theme switching
                        .onOpenURL { url in
                            handleURLScheme(url)
                        }
                    // REMOVED: .preferredColorScheme(nil) - was overriding theme
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                            handleAppDidBecomeActive()
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                            handleAppWillResignActive()
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
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Check for new results when app becomes active
                Task {
                    await AppGroupBridge.shared.checkForPendingResults()
                }
            }
        }
    }
    
    // MARK: - App Initialization (Enhanced with Data Loading)
    private func initializeApp() async {
        logger.info("Starting app initialization with persistence support")
        
        do {
            // Request notification permissions
            await requestNotificationPermissions()
            
            // Set up Share Extension bridge
            try await setupShareExtensionBridge()
            
            // CRITICAL: Load persisted data
            await loadAppData()
            
            // Check for pending results from Share Extension
            await checkForPendingResults()
            
            // Mark as initialized on main thread
            await MainActor.run {
                isInitialized = true
                logger.info("App initialization completed successfully with data loaded")
            }
            
        } catch {
            await MainActor.run {
                initializationError = error.localizedDescription
                logger.error("App initialization failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadAppData() async {
        logger.info("Loading persisted app data")
        
        // AppState will load its own persisted data
        await appState.loadPersistedData()
        
        logger.info("App data loading completed")
    }
    
    private func retryInitialization() {
        initializationError = nil
        isInitialized = false
        
        Task {
            await initializeApp()
        }
    }
    
    // MARK: - Notification Permissions (Unchanged)
    private func requestNotificationPermissions() async {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            
            if granted {
                logger.info("Notification permissions granted")
            } else {
                logger.warning("Notification permissions denied")
            }
            
        } catch {
            logger.error("Failed to request notification permissions: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Share Extension Bridge Setup (Enhanced)
    @MainActor
    private func setupShareExtensionBridge() async throws {
        // Set up notification observers with proper weak references
        NotificationCenter.default.addObserver(
            forName: .gameResultReceived,
            object: nil,
            queue: .main
        ) { [weak appState] notification in
            guard let appState = appState,
                  let result = notification.object as? GameResult else { return }
            
            // Process on main actor context with persistence
            Task { @MainActor in
                processNewGameResult(result, in: appState)
            }
        }
        
        logger.debug("Share Extension bridge configured with persistence support")
    }
    
    private func checkForPendingResults() async {
        let bridge = AppGroupBridge.shared
        
        if await bridge.hasNewResults {
            await bridge.processLatestResult()
        }
    }
    
    // MARK: - Game Result Processing (Enhanced with Persistence)
    @MainActor
    private func processNewGameResult(_ result: GameResult, in state: AppState) {
        logger.info("Processing new game result: \(result.gameName) - \(result.displayScore)")
        
        // Validate result before processing
        guard result.isValid else {
            logger.warning("Invalid game result received, skipping")
            return
        }
        
        // Add to app state (this will automatically persist via AppState)
        state.addGameResult(result)
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        logger.info("Successfully processed and persisted game result for \(result.gameName)")
    }
    
    // MARK: - URL Scheme Handling (Unchanged)
    private func handleURLScheme(_ url: URL) {
        logger.info("Handling URL scheme: \(url.absoluteString)")
        
        let success = AppGroupBridge.shared.handleURLScheme(url)
        
        if !success {
            logger.warning("Failed to handle URL scheme: \(url.absoluteString)")
        }
    }
    
    // MARK: - App Lifecycle Handlers (Enhanced)
    private func handleAppDidBecomeActive() {
        logger.debug("App became active - refreshing data")
        
        Task {
            // Refresh data when app becomes active
            await appState.refreshData()
            await checkForPendingResults()
        }
        
        // Reset badge count
        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(0)
            } catch {
                logger.error("Failed to reset badge count: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleAppWillResignActive() {
        logger.debug("App will resign active")
        
        // Note: AppState automatically saves data when modified,
        // so no explicit save needed here
    }
}

// MARK: - Initialization Views (Enhanced)
struct InitializationView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
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
                    // This could clear all data and restart fresh
                    Task {
                        let appState = AppState()
                        await appState.clearAllData()
                        onRetry()
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
