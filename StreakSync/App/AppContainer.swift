//
//  AppContainer.swift
//  StreakSync
//
//  Centralized dependency injection container
//

import SwiftUI
import OSLog
import FirebaseCore
import FirebaseFirestore

@MainActor
final class AppContainer: ObservableObject {
    // MARK: - Core Services
    let appState: AppState
    let navigationCoordinator: NavigationCoordinator
    let gameResultSyncService: FirestoreGameResultSyncService
    let guestSessionManager: GuestSessionManager
    
    // MARK: - Data Services
    let persistenceService: PersistenceServiceProtocol
    let syncCoordinator: AppGroupSyncCoordinator
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
    private let ingestionActor = GameResultIngestionActor()
    
    // MARK: - Logger
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AppContainer")
    
    // MARK: - Initialization
    init(isPreview: Bool = false, isTest: Bool = false) {
        // Note: Firebase is configured in AppDelegate.didFinishLaunchingWithOptions
        // which runs before SwiftUI creates this @StateObject.
        
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
    
    // MARK: - View Model Factories
    
    /// Creates a new DashboardViewModel
    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(appState: appState)
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
        // triggering cloud sync; guest sessions are local-only.
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
        
        // Flush any pending scores that failed to publish previously
        if let firebaseSocial = socialService as? FirebaseSocialService {
            await firebaseSocial.flushPendingScoresIfNeeded()
        }
        
        // Stop monitoring after 5 seconds
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            appGroupBridge.stopMonitoringForResults()
            logger.info("⚡ Stopped monitoring after 5 seconds")
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
