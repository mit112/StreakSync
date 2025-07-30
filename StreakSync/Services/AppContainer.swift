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
    
    // MARK: - UI Services
    let themeManager: ThemeManager
    let hapticManager: HapticManager
    let browserLauncher: BrowserLauncher
    
    // MARK: - Notification Coordinator
    let notificationCoordinator: NotificationCoordinator
    
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
        
        // 6. Notification handling
        self.notificationCoordinator = NotificationCoordinator()
        
        // Wire up dependencies
        setupDependencies()
        
        logger.info("✅ AppContainer initialized successfully")
    }
    
    // MARK: - Dependency Wiring
    private func setupDependencies() {
        // Wire notification coordinator
        notificationCoordinator.appState = appState
        notificationCoordinator.navigationCoordinator = navigationCoordinator
        notificationCoordinator.appGroupBridge = appGroupBridge
        
        // Setup observers
        notificationCoordinator.setupObservers()
    }
    
    // MARK: - View Model Factories
    
    /// Creates a new DashboardViewModel
    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(
            appState: appState,
            themeManager: themeManager
        )
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
        
        // Refresh data if needed
        if !appGroupBridge.hasNewResults {
            await appState.refreshData()
        }
        
        // Stop monitoring after 10 seconds
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                appGroupBridge.stopMonitoringForResults()
                logger.info("⏱️ Stopped monitoring after 10 seconds")
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
}
