//
//  AppContainer.swift
//  StreakSync
//
//  Created by MiT on 7/29/25.
//

//
//  AppContainer.swift
//  StreakSync
//
//  Centralized dependency injection container
//

/*
 * APPCONTAINER - DEPENDENCY INJECTION SYSTEM
 * 
 * WHAT THIS FILE DOES:
 * This is the "brain" of the app's architecture. It creates and manages all the services that the app needs,
 * like a factory that builds all the parts and connects them together. Think of it as the conductor of an
 * orchestra - it doesn't play the music itself, but it makes sure all the musicians (services) are in place
 * and working together.
 * 
 * WHY IT EXISTS:
 * Without this file, every part of the app would need to create its own services, leading to chaos and
 * duplicated code. This centralizes all service creation and makes the app much more organized and testable.
 * It's a design pattern called "Dependency Injection" that makes code more modular and easier to maintain.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This is the foundation that makes the entire app architecture possible
 * - Manages the lifecycle of all app services (when they're created, how long they live)
 * - Ensures services are created in the right order (some services depend on others)
 * - Provides a single place to configure how services work together
 * - Makes testing easier by allowing mock services to be injected
 * 
 * WHAT IT REFERENCES:
 * - AppState: The main data store for the entire app
 * - NavigationCoordinator: Manages app navigation and routing
 * - PersistenceService: Handles saving/loading data
 * - SocialService: Manages friend features and leaderboards
 * - AnalyticsService: Tracks user behavior and app performance
 * - NotificationCoordinator: Handles push notifications
 * - All other core services and utilities
 * 
 * WHAT REFERENCES IT:
 * - StreakSyncApp.swift: Creates the AppContainer when the app starts
 * - All SwiftUI views: Access services through the container
 * - Test files: Use mock containers for testing
 * - Preview files: Use preview containers for SwiftUI previews
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. SERVICE REGISTRATION IMPROVEMENTS:
 *    - Currently services are created manually in init() - could use a registration system
 *    - Consider using a protocol-based approach for easier testing
 *    - Add service lifecycle management (start/stop services when needed)
 * 
 * 2. DEPENDENCY RESOLUTION:
 *    - The current approach manually wires dependencies - could be automated
 *    - Consider using a dependency injection framework for larger apps
 *    - Add circular dependency detection to prevent infinite loops
 * 
 * 3. CONFIGURATION MANAGEMENT:
 *    - Hard-coded service creation could be moved to configuration files
 *    - Add environment-specific configurations (dev, staging, production)
 *    - Consider feature flags for enabling/disabling services
 * 
 * 4. ERROR HANDLING:
 *    - Add error handling for service initialization failures
 *    - Implement fallback services when primary services fail
 *    - Add health checks for critical services
 * 
 * 5. PERFORMANCE OPTIMIZATIONS:
 *    - Some services could be lazy-loaded (created only when needed)
 *    - Add service pooling for expensive-to-create services
 *    - Implement service caching for frequently accessed services
 * 
 * 6. TESTING ENHANCEMENTS:
 *    - The MockPersistenceService is good, but could add more mock services
 *    - Add integration tests that use the full container
 *    - Create test utilities for common testing scenarios
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add documentation for each service and its purpose
 *    - Create dependency diagrams showing how services relate
 *    - Add examples of how to add new services
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - @MainActor ensures all operations happen on the main thread (required for UI)
 * - ObservableObject makes this class work with SwiftUI's reactive system
 * - The init() method is where all the "magic" happens - services are created and connected
 * - setupDependencies() is where services are "wired together" so they can communicate
 * - The factory methods (makeDashboardViewModel, etc.) create view models when needed
 * - MockPersistenceService shows how to create fake services for testing
 * - Dependency injection is a pattern that makes code more testable and flexible
 */

import SwiftUI
import OSLog
import CloudKit
import FirebaseCore
import FirebaseFirestore

// MARK: - Firebase Early Configuration
// This ensures Firebase is configured before any class initializers run
private enum FirebaseEarlyConfiguration {
    static let isConfigured: Bool = {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            
            // Configure Firestore settings
            let settings = FirestoreSettings()
            settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024))
            Firestore.firestore().settings = settings
        }
        return true
    }()
}

@MainActor
final class AppContainer: ObservableObject {
    // Ensure Firebase is configured before any properties are initialized
    private let _firebaseConfigured = FirebaseEarlyConfiguration.isConfigured
    // MARK: - Core Services
    let appState: AppState
    let navigationCoordinator: NavigationCoordinator
    let userDataSyncService: UserDataSyncService
    let guestSessionManager: GuestSessionManager
    
    // MARK: - Data Services
    let persistenceService: PersistenceServiceProtocol
    let syncCoordinator: AppGroupSyncCoordinator
    let appGroupBridge: AppGroupBridge
    
    let gameCatalog: GameCatalog
    let gameManagementState: GameManagementState
    let socialSettingsService: SocialSettingsService

    
    // MARK: - UI Services
    let themeManager: ThemeManager
    let hapticManager: HapticManager
    let browserLauncher: BrowserLauncher
    let networkMonitor: NetworkMonitor
    
    let achievementCelebrationCoordinator: AchievementCelebrationCoordinator

    // MARK: - Firebase Services
    let firebaseAuthManager: FirebaseAuthStateManager
    let socialService: SocialService
    
    // MARK: - Analytics Service
    let analyticsService: AnalyticsService
    let achievementSyncService: AchievementSyncService

    // MARK: - Notification Coordinator
    let notificationCoordinator: NotificationCoordinator
    private let ingestionActor = GameResultIngestionActor()
    
    // MARK: - Logger
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AppContainer")
    
    // MARK: - Initialization
    init(isPreview: Bool = false, isTest: Bool = false) {
        // Note: Firebase is configured via _firebaseConfigured stored property
        // which runs before this init() body executes
        
        logger.info("🏗️ Initializing AppContainer (preview: \(isPreview), test: \(isTest))")
        
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
        self.syncCoordinator = AppGroupSyncCoordinator()
        self.appGroupBridge = AppGroupBridge.shared
        
        // 5. UI services
        self.themeManager = ThemeManager.shared
        self.hapticManager = HapticManager.shared
        self.browserLauncher = BrowserLauncher.shared
        
        // 5a. User data CloudKit sync
        self.userDataSyncService = UserDataSyncService(appState: appState)
        // 5b. Guest Mode manager (local-only guest sessions)
        self.guestSessionManager = GuestSessionManager(appState: appState, syncService: userDataSyncService)
        self.networkMonitor = NetworkMonitor(syncService: userDataSyncService)
        
        // 5b. Game Management (NEW)
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

        // 8. Firebase Auth Manager (handles auth state and automatic re-authentication)
        self.firebaseAuthManager = FirebaseAuthStateManager()
        
        // 9. Social service (Firebase-backed; falls back to local cache patterns in service)
        self.socialService = FirebaseSocialService()
        // Attach to app state
        self.appState.socialService = socialService
        
        // 10. Analytics service
        self.analyticsService = AnalyticsService(appState: appState)
        // 11. CloudKit achievements sync (feature-flagged)
        self.achievementSyncService = AchievementSyncService(appState: appState)

        
        // Wire up dependencies
        setupDependencies()
        
        // Start day change detection
        DayChangeDetector.shared.startMonitoring()
        
        // Observe iCloud account changes to keep user data in sync and protect privacy
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.handleCloudKitAccountChanged()
            }
        }
        
        // Handle any stranded guest sessions (e.g. app killed while in Guest Mode).
        guestSessionManager.handleStrandedGuestSessionIfNeeded()
        
        // Kick off cloud sync if enabled
        Task { @MainActor in
            await self.achievementSyncService.syncIfEnabled()
        }
        
        logger.info("✅ AppContainer initialized successfully")
    }
    
    // MARK: - Dependency Wiring
    private func setupDependencies() {
        // Wire notification coordinator
        notificationCoordinator.appState = appState
        notificationCoordinator.navigationCoordinator = navigationCoordinator
        notificationCoordinator.appGroupBridge = appGroupBridge
        notificationCoordinator.resultIngestion = { [weak self] result in
            guard let self else { return false }
            return await self.ingestionActor.ingest(result, into: self.appState)
        }
        
        // Wire analytics service to app state for cache invalidation
        appState.analyticsService = analyticsService
        
        // Setup observers
        notificationCoordinator.setupObservers()
    }
    
    // MARK: - CloudKit Account Changes
    private func handleCloudKitAccountChanged() async {
        logger.info("👤 Detected CKAccountChanged – evaluating whether the iCloud account actually changed")
        
        // Load the last known userRecordID.recordName we successfully synced with.
        let previousRecordName = userDataSyncService.lastKnownUserRecordName()
        
        // If an iCloud account change occurs during Guest Mode, first exit guest
        // mode (discarding guest data) so that we can safely reset host data for
        // the new account without restoring a stale snapshot.
        if guestSessionManager.isGuestMode {
            logger.warning("⚠️ CKAccountChanged fired while Guest Mode is active – exiting Guest Mode before processing account change")
            _ = await guestSessionManager.exitGuestMode(exportGuestData: false, shouldSyncAfterExit: false)
        }
        var currentRecordName: String?
        
        do {
            let container = CKContainer(identifier: CloudKitConfiguration.containerIdentifier)
            let recordID = try await container.userRecordID()
            currentRecordName = recordID.recordName
        } catch {
            logger.error("⚠️ Failed to fetch current userRecordID after CKAccountChanged: \(error.localizedDescription)")
        }
        
        // Only treat this as a real account change when we have both a previous and
        // current record name and they differ. This avoids wiping data on spurious
        // CKAccountChanged notifications, first-time sign-ins, or transient states.
        guard
            let previous = previousRecordName,
            let current = currentRecordName,
            previous != current
        else {
            logger.info("👤 CKAccountChanged but userRecordID did not change in a confirmed way (previous=\(previousRecordName ?? "nil", privacy: .private), current=\(currentRecordName ?? "nil", privacy: .private)) – skipping data clear")
            return
        }
        
        logger.warning("👤 iCloud account changed from \(previous, privacy: .private) to \(current, privacy: .private) – resetting local data and sync state")
        
        // Clear all local data for privacy when account really changes.
        await appState.clearAllData()
        
        // Reset all CloudKit user-data sync state (incremental token, offline
        // queue, unsynced trackers, and last known userRecordID) so we never
        // upload results from the previous account under the new one.
        await userDataSyncService.resetForAccountChange()
        
        // Attempt to sync data for the new account (if available)
        await userDataSyncService.syncIfNeeded()
        
        // Rebuild streaks from the freshly-synced results
        await appState.rebuildStreaksFromResults()
        
        logger.info("✅ Completed CloudKit account change handling for new iCloud user")
    }
    
    // MARK: - View Model Factories
    
    /// Creates a new DashboardViewModel
    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(appState: appState)  // Removed themeManager parameter
    }
    
    /// Creates a new GameDetailViewModel for a specific game
    func makeGameDetailViewModel(for gameId: UUID) -> GameDetailViewModel {
        GameDetailViewModel(gameId: gameId)
    }
    
    /// Creates a SettingsViewModel
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel()
    }
    
    // MARK: - App Lifecycle
    
    /// Call when app becomes active
    func handleAppBecameActive() async {
        logger.info("📱 App became active")
        
        // In Guest Mode we avoid refreshing host data from persistence or
        // triggering CloudKit-related refreshes; guest sessions are local-only.
        if appState.isGuestMode {
            logger.info("🧑‍🤝‍🧑 Guest Mode active – skipping host data refresh on app activation")
            return
        }
        
        // Start monitoring for share extension results
        appGroupBridge.startMonitoringForResults()
        
        // Use lightweight refresh if we're navigating from notification
        if appState.isNavigatingFromNotification {
            logger.info("🚀 Using lightweight data refresh - navigating from notification")
            await appState.refreshDataForNotification()
            
            // Reset the flag after a short delay
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await MainActor.run {
                    appState.isNavigatingFromNotification = false
                }
            }
        } else {
            // Refresh data if needed
            if !appGroupBridge.hasNewResults {
                await appState.refreshData()
            }
        }
        
        // Stop monitoring after 10 seconds
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                appGroupBridge.stopMonitoringForResults()
                logger.info("⚡ Stopped monitoring after 10 seconds")
            }
        }
    }
    
    /// Call when app will resign active
    func handleAppWillResignActive() {
        logger.info("📱 App will resign active")
        appGroupBridge.stopMonitoringForResults()
    }
    
    /// Handle URL scheme
    func handleURLScheme(_ url: URL) -> Bool {
        logger.info("🔗 Handling URL: \(url.absoluteString)")
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
