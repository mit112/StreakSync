//
//  AppContainer.swift
//  StreakSync
//
//  Centralized dependency injection container
//

import Combine
import FirebaseCore
import FirebaseFirestore
import OSLog
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    // MARK: - Core Services
    let appState: AppState
    let navigationCoordinator: NavigationCoordinator
    let gameResultSyncService: FirestoreGameResultSyncService
    let guestSessionManager: GuestSessionManager
    
    // MARK: - Data Services
    let persistenceService: PersistenceServiceProtocol
    let appGroupBridge: AppGroupBridge
    
    let gameCatalog: GameCatalog
    let gameManagementState: GameManagementState
    let socialSettingsService: SocialSettingsService

    // MARK: - UI Services
    let hapticManager: HapticManager
    let browserLauncher: BrowserLauncher
    let achievementCelebrationCoordinator: AchievementCelebrationCoordinator

    // MARK: - Firebase Services
    let firebaseAuthManager: FirebaseAuthStateManager
    let socialService: SocialService
    
    // MARK: - Analytics Service
    let analyticsService: AnalyticsService
    let achievementSyncService: FirestoreAchievementSyncService

    // MARK: - Notification Coordinator
    let notificationCoordinator: NotificationCoordinator

    // MARK: - Auth State Observation
    // Tracks the Firebase UID that was active when the observer was last notified.
    // Used to distinguish a genuine account switch (UID-A → UID-B, needs full
    // data clear + re-sync) from a provider upgrade (anonymous → Apple/Google on
    // the same UID, needs only an incremental sync).
    private var lastKnownUID: String?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Logger
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AppContainer")
    
    // MARK: - Initialization
    init(isPreview: Bool = false, isTest: Bool = false) {
        // Note: Firebase is configured in AppDelegate.didFinishLaunchingWithOptions
        // which runs before SwiftUI creates this @StateObject.
        
 logger.info("Initializing AppContainer (preview: \(isPreview), test: \(isTest))")
        
        // Initialize services in dependency order
        
        // 1. Persistence layer
        if isPreview || isTest {
            self.persistenceService = MockPersistenceService()
        } else {
            self.persistenceService = UserDefaultsPersistenceService()
        }
        
        // 2. Core data state
        self.appState = AppState(persistenceService: persistenceService)
        
        // 3. Navigation
        self.navigationCoordinator = NavigationCoordinator()
        self.navigationCoordinator.setupDeepLinkObservers()
        
        // 4. Sync services
        self.appGroupBridge = AppGroupBridge.shared
        
        // 5. UI services
        self.hapticManager = HapticManager.shared
        self.browserLauncher = BrowserLauncher.shared
        
        // 5a. Firestore game result sync
        self.gameResultSyncService = FirestoreGameResultSyncService(appState: appState)
        // 5b. Guest Mode manager (local-only guest sessions)
        self.guestSessionManager = GuestSessionManager(appState: appState, syncService: gameResultSyncService)
        
        // 5c. Game Management
        self.gameCatalog = GameCatalog()
        
        // Validate game catalog to catch SF Symbol issues early
        #if DEBUG
        Game.validateGameCatalog()
        #endif
        
        self.gameManagementState = GameManagementState()
        self.socialSettingsService = SocialSettingsService.shared
        
        // 6. Notification handling
        self.notificationCoordinator = NotificationCoordinator()
        // 7. Achievement celebrations
        self.achievementCelebrationCoordinator = AchievementCelebrationCoordinator()
        // Wire celebration coordinator to app state for direct unlock calls
        self.appState.celebrationCoordinator = self.achievementCelebrationCoordinator

        // 8. Firebase Auth Manager (handles auth state and automatic re-authentication)
        self.firebaseAuthManager = FirebaseAuthStateManager()
        
        // 9. Social service (Firebase-backed; falls back to local cache patterns in service)
        self.socialService = FirebaseSocialService()
        // Attach to app state
        self.appState.socialService = socialService
        
        // 10. Analytics service
        self.analyticsService = AnalyticsService(appState: appState)
        // 11. Firestore achievements sync
        self.achievementSyncService = FirestoreAchievementSyncService(appState: appState)

        // Wire up dependencies
        setupDependencies()
        
        // Start day change detection
        DayChangeDetector.shared.startMonitoring()
        
        // Handle any stranded guest sessions (e.g. app killed while in Guest Mode).
        guestSessionManager.handleStrandedGuestSessionIfNeeded()
        
        // Kick off achievement sync if enabled
        Task { @MainActor in
            await self.achievementSyncService.syncIfEnabled()
        }
        
 logger.info("AppContainer initialized successfully")
    }
    
    // MARK: - Dependency Wiring
    private func setupDependencies() {
        // Wire notification coordinator
        notificationCoordinator.appState = appState
        notificationCoordinator.navigationCoordinator = navigationCoordinator
        notificationCoordinator.appGroupBridge = appGroupBridge
        notificationCoordinator.gameResultSyncService = gameResultSyncService

        // Wire analytics service to app state for cache invalidation
        appState.analyticsService = analyticsService

        // Setup observers
        notificationCoordinator.setupObservers()

        // Observe Firebase auth state so the app re-syncs immediately when the
        // user signs in mid-session, rather than waiting for the next cold launch.
        setupAuthStateObserver()
    }

    // MARK: - Auth State Observer

    /// Subscribes to `firebaseAuthManager.$currentUser` and re-runs the appropriate
    /// portion of the sync pipeline whenever the Firebase UID changes.
    ///
    /// Two distinct scenarios trigger this path:
    ///
    /// **Account switch (UID-A → UID-B)**
    /// Occurs when the Apple/Google credential supplied during sign-in is already
    /// linked to a *different* Firebase account (the `credentialAlreadyInUse` path
    /// in `FirebaseAuthStateManager`). Firebase silently swaps the active user, so
    /// the in-memory AppState and on-disk UserDefaults still hold UID-A's data.
    /// Without intervention the user would see wrong data until the next cold launch.
    /// Fix: wipe everything and run a full sync under the new UID.
    ///
    /// **Provider upgrade (same UID)**
    /// Occurs when an anonymous account is successfully *linked* to Apple/Google,
    /// preserving the same UID. Local data is already correct; only an incremental
    /// Firestore sync is needed to pull any results that were stored on other devices.
    ///
    /// `dropFirst()` skips the initial value Combine emits synchronously on
    /// subscription. App startup (`initializeApp()`) already ran the full pipeline,
    /// so we must not re-run it here or we'd double-sync on every launch.
    private func setupAuthStateObserver() {
        // Capture the UID active at subscription time as the baseline.
        lastKnownUID = firebaseAuthManager.uid

        firebaseAuthManager.$currentUser
            .dropFirst()
            .sink { [weak self] newUser in
                guard let self else { return }

                let newUID = newUser?.uid
                let previousUID = self.lastKnownUID
                self.lastKnownUID = newUID

                // Skip if UID did not actually change (e.g. displayName update).
                guard newUID != previousUID else { return }

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.handleAuthUserChanged(from: previousUID, to: newUID)
                }
            }
            .store(in: &cancellables)
    }

    /// Runs the correct sync pipeline for the given UID transition.
    ///
    /// - Parameters:
    ///   - previousUID: The Firebase UID before the auth change, or `nil` if the
    ///     app was unauthenticated (shouldn't happen in practice, but handled safely).
    ///   - newUID: The Firebase UID after the auth change, or `nil` if the user
    ///     signed out (re-auth is handled by `FirebaseAuthStateManager` itself).
    ///
    /// Expected flow on UID change:
    ///   1. If newUID is nil (signed out) → return; FirebaseAuthStateManager re-auths.
    ///   2. If UID changed (account switch):
    ///      a. Remove the previous UID's gameResultSync_lastTimestamp_<uid> key.
    ///      b. cleanupForSignOut: clears AppState data, sync timestamp (new UID, no-op
    ///         beyond defense-in-depth), and AppGroup queue.
    ///   3. Else (same UID — provider upgrade): log only, no clear.
    ///   4. loadPersistedData → syncIfNeeded → rebuildStreaksFromResults →
    ///      normalizeStreaksForMissedDays → achievementSyncService.syncIfEnabled.
    private func handleAuthUserChanged(from previousUID: String?, to newUID: String?) async {
        guard let newUID else {
            // Signed-out state — FirebaseAuthStateManager re-authenticates anonymously,
            // which will fire another auth change. Nothing to do here.
            logger.info("Auth: signed out — waiting for re-authentication")
            return
        }

        if let previousUID, previousUID != newUID {
            // ──────────────────────────────────────────────────────────────
            // Account switch: UID changed. The in-memory and on-disk data
            // belong to the previous user and must be wiped before syncing.
            // Remove the old UID's sync timestamp BEFORE cleanupForSignOut()
            // so we target the correct key (cleanupForSignOut uses the new
            // UID's key, which is fine as defense-in-depth but not the stale one).
            // cleanupForSignOut() also flushes the App Group queue so Share
            // Extension results from the old session don't get ingested into
            // the new one.
            // ──────────────────────────────────────────────────────────────
            logger.info("Auth: UID changed (\(previousUID) → \(newUID)) — clearing stale data and re-syncing")
            let oldKey = "gameResultSync_lastTimestamp_\(previousUID)"
            UserDefaults.standard.removeObject(forKey: oldKey)
            await cleanupForSignOut()
        } else {
            // ──────────────────────────────────────────────────────────────
            // Provider upgrade: anonymous → Apple/Google on the same UID.
            // Local data is correct. A full sync still runs so any results
            // recorded on another device are pulled down immediately.
            // ──────────────────────────────────────────────────────────────
            logger.info("Auth: provider upgraded for UID \(newUID) — running incremental sync")
        }

        // Re-run the same pipeline as cold-launch initializeApp(), minus the
        // notification-permission setup (not needed for a mid-session transition).
        await appState.loadPersistedData()
        await gameResultSyncService.syncIfNeeded()
        await appState.rebuildStreaksFromResults()
        await appState.normalizeStreaksForMissedDays()
        await achievementSyncService.syncIfEnabled()

        logger.info("Auth: post-sign-in sync complete for UID \(newUID)")
    }
    
    // MARK: - Sign-Out Cleanup

    /// Consolidates all cleanup needed when a user signs out.
    /// Call this instead of manually calling clearAllData + clearLastSyncTimestamp
    /// to prevent future sign-out paths from missing a step.
    func cleanupForSignOut() async {
        await appState.clearAllData()
        gameResultSyncService.clearLastSyncTimestamp()
        // Clear App Group queue so stale Share Extension results
        // aren't ingested by the next user session.
        appGroupBridge.clearAllData()
    }

    // MARK: - App Lifecycle
    
    /// Call when app becomes active
    ///
    /// Expected flow on app foreground:
    ///   1. If guest mode active → return (guest sessions are local-only).
    ///   2. Flush any saves that failed in a previous session (appState.flushPendingSaves).
    ///   3. Start AppGroupBridge monitoring for incoming Share Extension results.
    ///   4. Refresh app data:
    ///      - If navigating from a notification → refreshDataForNotification (lightweight).
    ///      - Else, if AppGroupBridge has no new results → appState.refreshData (UserDefaults).
    ///   5. Time-gated Firestore sync (>5 min since last sync): syncIfNeeded →
    ///      rebuildStreaksFromResults → normalizeStreaksForMissedDays → achievement sync.
    ///   6. Flush pending social scores if FirebaseSocialService is wired.
    ///   7. Stop AppGroupBridge monitoring after 5 seconds.
    func handleAppBecameActive() async {
 logger.info("App became active")

        // In Guest Mode we avoid refreshing host data from persistence or
        // triggering cloud sync; guest sessions are local-only.
        if appState.isGuestMode {
 logger.info("Guest Mode active – skipping host data refresh on app activation")
            return
        }

        // Retry any saves that failed in a previous session
        await appState.flushPendingSaves()

        // Start monitoring for share extension results
        appGroupBridge.startMonitoringForResults()

        // Use lightweight refresh if we're navigating from notification
        if appState.isNavigatingFromNotification {
 logger.info("Using lightweight data refresh - navigating from notification")
            await appState.refreshDataForNotification()

            // Reset the flag after a short delay
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                appState.isNavigatingFromNotification = false
            }
        } else {
            // Refresh data if needed
            if !appGroupBridge.hasNewResults {
                await appState.refreshData()
            }
        }

        // Time-gated Firestore sync: if more than 5 minutes have passed since the
        // last successful sync, run the full sync pipeline so multi-device users
        // see updates without needing to relaunch the app.
        let shouldSync: Bool
        if case .synced(let lastSyncDate) = gameResultSyncService.syncState {
            shouldSync = Date().timeIntervalSince(lastSyncDate) > 300
        } else {
            // .notStarted / .syncing / .failed / .offline → always attempt
            shouldSync = true
        }
        if shouldSync {
            await gameResultSyncService.syncIfNeeded()
            await appState.rebuildStreaksFromResults()
            await appState.normalizeStreaksForMissedDays()
            await achievementSyncService.syncIfEnabled()
        }

        // Flush any pending scores that failed to publish previously
        if let firebaseSocial = socialService as? FirebaseSocialService {
            await firebaseSocial.flushPendingScoresIfNeeded()
        }

        // Stop monitoring after 5 seconds
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            appGroupBridge.stopMonitoringForResults()
 logger.info("Stopped monitoring after 5 seconds")
        }
    }
    
    /// Call when app will resign active
    func handleAppWillResignActive() {
 logger.info("App will resign active")
        appGroupBridge.stopMonitoringForResults()
    }
    
    /// Handle URL scheme
    func handleURLScheme(_ url: URL) -> Bool {
 logger.info("Handling URL: \(url.absoluteString)")
        return appGroupBridge.handleURLScheme(url)
    }
    
    // MARK: - Testing Support
    
#if DEBUG
    /// Creates a mock container for previews
    static func preview() -> AppContainer {
        let container = AppContainer(isPreview: true)
        // Add sample data if needed
        Task { @MainActor in
            await container.appState.loadPersistedData()
        }
        return container
    }
    
    /// Creates a test container with mock services
    static func test() -> AppContainer {
        AppContainer(isTest: true)
    }
#endif
}

// MARK: - Mock Persistence for Previews/Tests
final class MockPersistenceService: PersistenceServiceProtocol {
    private var storage: [String: Data] = [:]
    
    func save<T: Codable>(_ object: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        storage[key] = try encoder.encode(object)
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = storage[key] else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }
    
    func remove(forKey key: String) {
        storage.removeValue(forKey: key)
    }
    
    func clearAll() {
        storage.removeAll()
    }
}
