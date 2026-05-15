//
//  AppContainer.swift
//  StreakSync
//
//  Centralized dependency injection container
//

import Combine
import FirebaseAuth
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
    private var lastKnownProvider: AuthProvider = .anonymous
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
        lastKnownUID = firebaseAuthManager.uid
        lastKnownProvider = firebaseAuthManager.authProvider

        firebaseAuthManager.$currentUser
            .dropFirst()
            .sink { [weak self] newUser in
                guard let self else { return }

                let newUID = newUser?.uid
                let newProvider = AppContainer.deriveProvider(from: newUser)
                let previousUID = self.lastKnownUID
                let previousProvider = self.lastKnownProvider
                self.lastKnownUID = newUID
                self.lastKnownProvider = newProvider

                if newUID != previousUID {
                    // Account switch: UID changed — wipe stale data and full sync.
                    logger.info("Auth: UID changed (\(previousUID ?? "nil") → \(newUID ?? "nil")) — clearing stale data and re-syncing")
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        await self.handleAuthUserChanged(from: previousUID, to: newUID)
                    }
                } else if previousProvider == .anonymous, newProvider != .anonymous {
                    // Provider upgrade: same UID, anonymous → social.
                    // Capture values now; auth state may change before the Task runs.
                    let provider = newProvider
                    let name = newUser?.displayName
                    logger.info("Auth: provider upgraded for UID \(newUID ?? "nil")")
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        await self.handleProviderUpgraded(to: provider, displayName: name)
                    }
                }
                // else: no-op (display name update, re-auth to same anonymous UID, etc.)
            }
            .store(in: &cancellables)
    }

    /// Handles a Firebase UID change (account switch: UID-A → UID-B).
    ///
    /// Expected flow:
    ///   1. If newUID is nil (signed out) → return; FirebaseAuthStateManager re-auths anonymously.
    ///   2. Remove the previous UID's sync timestamp key (stale — targets the old UID).
    ///   3. cleanupForSignOut: clears AppState, sync timestamp (new UID, defense-in-depth),
    ///      and AppGroup queue so Share Extension results from the old session are discarded.
    ///   4. loadPersistedData → syncIfNeeded → rebuildStreaksFromResults →
    ///      normalizeStreaksForMissedDays → achievementSyncService.syncIfEnabled.
    private func handleAuthUserChanged(from previousUID: String?, to newUID: String?) async {
        guard let newUID else {
            logger.info("Auth: signed out — waiting for re-authentication")
            return
        }

        if let previousUID, previousUID != newUID {
            let oldKey = "gameResultSync_lastTimestamp_\(previousUID)"
            UserDefaults.standard.removeObject(forKey: oldKey)
            await cleanupForSignOut()
        }

        await appState.loadPersistedData()
        await gameResultSyncService.syncIfNeeded()
        await appState.rebuildStreaksFromResults()
        await appState.normalizeStreaksForMissedDays()
        await achievementSyncService.syncIfEnabled()

        logger.info("Auth: post-sign-in sync complete for UID \(newUID)")
    }

    /// Handles an anonymous → social provider upgrade on the same Firebase UID.
    ///
    /// Expected flow:
    ///   1. updateProfile: writes correct displayName and authProvider to Firestore.
    ///   2. syncIfNeeded → rebuildStreaksFromResults → achievementSyncService.syncIfEnabled.
    ///
    /// Parameters are captured at subscriber time for determinism — auth state may
    /// change again before this Task executes.
    private func handleProviderUpgraded(to provider: AuthProvider, displayName: String?) async {
        logger.info("Auth: provider upgraded to \(provider.rawValue) — updating profile")
        try? await socialService.updateProfile(
            displayName: displayName,
            authProvider: provider.rawValue
        )
        await gameResultSyncService.syncIfNeeded()
        await appState.rebuildStreaksFromResults()
        await achievementSyncService.syncIfEnabled()
        logger.info("Auth: provider upgrade complete")
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

    // MARK: - Provider Derivation

    /// Derives the auth provider from a Firebase User's providerData.
    /// Called in the $currentUser subscriber — cannot read firebaseAuthManager.authProvider
    /// because it is set on the line after currentUser in setupAuthListener.
    private static func deriveProvider(from user: User?) -> AuthProvider {
        guard let user, !user.isAnonymous else { return .anonymous }
        return deriveProvider(fromProviderIDs: user.providerData.map { $0.providerID })
    }

    /// Pure derivation from provider ID strings. `internal nonisolated` for testability.
    internal nonisolated static func deriveProvider(fromProviderIDs ids: [String]) -> AuthProvider {
        if ids.contains("apple.com") { return .apple }
        if ids.contains("google.com") { return .google }
        return .anonymous
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
