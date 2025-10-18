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

@MainActor
final class AppContainer: ObservableObject {
    // MARK: - Core Services
    let appState: AppState
    let navigationCoordinator: NavigationCoordinator
    
    // MARK: - Data Services
    let persistenceService: PersistenceServiceProtocol
    let syncCoordinator: AppGroupSyncCoordinator
    let appGroupBridge: AppGroupBridge
    
    let gameCatalog: GameCatalog
    let gameManagementState: GameManagementState

    
    // MARK: - UI Services
    let themeManager: ThemeManager
    let hapticManager: HapticManager
    let browserLauncher: BrowserLauncher
    
    let achievementCelebrationCoordinator: AchievementCelebrationCoordinator

    // MARK: - Social Service
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
        
        // 4. Sync services
        self.syncCoordinator = AppGroupSyncCoordinator()
        self.appGroupBridge = AppGroupBridge.shared
        
        // 5. UI services
        self.themeManager = ThemeManager.shared
        self.hapticManager = HapticManager.shared
        self.browserLauncher = BrowserLauncher.shared
        
        // 5b. Game Management (NEW)
        self.gameCatalog = GameCatalog()
        
        // Validate game catalog to catch SF Symbol issues early
        #if DEBUG
        Game.validateGameCatalog()
        #endif
        
        self.gameManagementState = GameManagementState()
        
        // 6. Notification handling
        self.notificationCoordinator = NotificationCoordinator()
        // 7. Achievement celebrations
        self.achievementCelebrationCoordinator = AchievementCelebrationCoordinator()

        // 8. Social service (Hybrid: CloudKit with fallback to local)
        self.socialService = HybridSocialService()
        // Attach to app state
        self.appState.socialService = socialService
        
        // 9. Analytics service
        self.analyticsService = AnalyticsService(appState: appState)
        // 10. CloudKit achievements sync (feature-flagged)
        self.achievementSyncService = AchievementSyncService(appState: appState)

        
        // Wire up dependencies
        setupDependencies()
        
        // Start day change detection
        DayChangeDetector.shared.startMonitoring()
        
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
            guard let self else { return }
            await self.ingestionActor.ingest(result, into: self.appState)
        }
        
        // Wire analytics service to app state for cache invalidation
        appState.analyticsService = analyticsService
        
        // Setup observers
        notificationCoordinator.setupObservers()
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
