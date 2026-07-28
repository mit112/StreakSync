//
//  StreakSyncApp.swift - REFACTORED WITH APPCONTAINER
//  Main app entry point with dependency injection
//

import GoogleSignIn
import OSLog
import SwiftUI
import UIKit
import UserNotifications

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
        // Expected flow on cold launch (local-first — DESIGN_AUDIT §4.7):
        //   1. Wire up NotificationDelegate with appState and navigationCoordinator
        //      so notification taps can navigate before ContentView appears (local).
        //   2. Load persisted UserDefaults data into AppState and normalize streaks
        //      for missed days — all local, no network.
        //   3. Flip isInitialized = true immediately so ContentView paints from
        //      cache; the dashboard skeleton covers the sub-second gap.
        //   4. In a detached Task AFTER paint: ensure Firebase Anonymous Auth,
        //      register notification categories if authorized, run the Firestore
        //      result sync, rebuild streaks from the merged set, re-check reminders,
        //      and reconcile recent social scores. AppState is @Observable, so the
        //      UI updates reactively when the background sync lands.
        logger.info("Starting app initialization (local-first)")
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")

        // Initialize notification delegate dependencies early (local, instant)
        NotificationDelegate.shared.appState = container.appState
        NotificationDelegate.shared.navigationCoordinator = container.navigationCoordinator

        // 1) Local-first paint: load cached data and normalize before any network.
        await container.appState.loadPersistedData()
        await container.appState.normalizeStreaksForMissedDays()

        await MainActor.run {
            isInitialized = true
            logger.info("Local data loaded — UI painted; syncing in background")
        }

        // 2) Background sync — runs after paint, applied reactively via @Observable.
        Task {
            // Ensure Firebase Anonymous Auth for social backend.
            // Uses the AuthStateManager which also re-authenticates on sign-out.
            await container.firebaseAuthManager.ensureAuthenticated()

            // Register categories on launch if already authorized.
            let authStatus = await NotificationScheduler.shared.checkPermissionStatus()
            if authStatus == .authorized {
                await NotificationScheduler.shared.registerCategories()
            }

            // Sync game results via Firestore (skipped in UI test mode).
            if !isUITesting {
                await container.gameResultSyncService.syncIfNeeded()
            }

            // Rebuild streaks from newly-synced results, then normalize gaps to today
            // (rebuildStreaksFromResults only checks gaps between results, not to today).
            await container.appState.rebuildStreaksFromResults()
            await container.appState.normalizeStreaksForMissedDays()

            // Check for streak reminders once the merged set is known.
            await container.appState.checkAndScheduleStreakReminders()

            // Reconcile recent scores — republishes any dropped by failures,
            // timezone bugs, or offline periods (skipped in UI test mode).
            if !isUITesting {
                if let socialService = container.socialService as? FirebaseSocialService {
                    await socialService.reconcileRecentScores(
                        results: container.appState.recentResults,
                        streaks: container.appState.streaks
                    )
                }
            }
            logger.info("Background sync completed")
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 20) {
            StreakSyncBrandMark(size: 64)
                .accessibilityLabel("StreakSync")
                .scaleEffect(pulse ? 1.05 : 1)
                .onAppear {
                    updatePulse(for: reduceMotion)
                }
                .onChange(of: reduceMotion) { _, isReduceMotionEnabled in
                    updatePulse(for: isReduceMotionEnabled)
                }
            
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

    private func updatePulse(for isReduceMotionEnabled: Bool) {
        if isReduceMotionEnabled {
            withAnimation(.none) {
                pulse = false
            }
        } else {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
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
