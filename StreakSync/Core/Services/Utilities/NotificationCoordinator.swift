//
//  NotificationCoordinator.swift
//  StreakSync
//
//  Centralized notification handling and app communication
//

/*
 * NOTIFICATIONCOORDINATOR - CENTRALIZED NOTIFICATION HANDLING AND APP COMMUNICATION
 * 
 * WHAT THIS FILE DOES:
 * This file provides centralized notification handling that coordinates communication
 * between different parts of the app and external systems. It's like a "notification
 * traffic controller" that manages incoming notifications, deep links, and app
 * lifecycle events. Think of it as the "communication hub" that ensures all
 * notifications are handled properly and the app responds correctly to external
 * events like share extension results, deep links, and app state changes.
 * 
 * WHY IT EXISTS:
 * Modern apps need to handle various types of notifications and communication
 * from external sources. This coordinator provides a centralized way to manage
 * all notification handling, ensuring that game results from the share extension,
 * deep links from other apps, and app lifecycle events are all handled consistently
 * and reliably. It prevents notification handling from being scattered throughout
 * the codebase.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This handles all external communication and notifications
 * - Manages game results from the share extension
 * - Handles deep links for navigation to specific games and achievements
 * - Coordinates app lifecycle events and state changes
 * - Ensures proper notification handling and routing
 * - Provides centralized communication management
 * - Makes the app responsive to external events
 * 
 * WHAT IT REFERENCES:
 * - SwiftUI: For UI state management
 * - OSLog: For logging and debugging
 * - NotificationCenter: For system notification handling
 * - AppState: For app state management
 * - NavigationCoordinator: For navigation management
 * - AppGroupBridge: For inter-app communication
 * - GameResult: For game result data
 * 
 * WHAT REFERENCES IT:
 * - AppContainer: Sets up and manages this coordinator
 * - Share Extension: Sends notifications through this coordinator
 * - Deep link handling: Uses this for navigation
 * - App lifecycle: Uses this for state management
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. NOTIFICATION HANDLING IMPROVEMENTS:
 *    - The current handling is good but could be more sophisticated
 *    - Consider adding more notification types and scenarios
 *    - Add support for notification queuing and prioritization
 *    - Implement smart notification routing
 * 
 * 2. ERROR HANDLING IMPROVEMENTS:
 *    - The current error handling could be enhanced
 *    - Add support for notification failure recovery
 *    - Implement smart error handling and retry logic
 *    - Add support for notification validation
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient notification processing
 *    - Add support for notification batching
 *    - Implement smart notification management
 * 
 * 4. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for notification handling
 *    - Test different notification scenarios and edge cases
 *    - Add integration tests with real notifications
 *    - Test error handling and recovery
 * 
 * 5. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for notification handling
 *    - Document the different notification types and scenarios
 *    - Add examples of how to handle different notifications
 *    - Create notification handling guidelines
 * 
 * 6. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new notification types
 *    - Add support for custom notification configurations
 *    - Implement notification plugins
 *    - Add support for third-party notification integrations
 * 
 * 7. MONITORING AND OBSERVABILITY:
 *    - Add detailed logging for notification handling
 *    - Implement metrics for notification effectiveness
 *    - Add support for notification debugging
 *    - Monitor notification performance and reliability
 * 
 * 8. SECURITY IMPROVEMENTS:
 *    - The current security could be enhanced
 *    - Add support for notification validation and sanitization
 *    - Implement secure notification handling
 *    - Add support for notification encryption
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Notification handling: Managing incoming messages and events
 * - Deep links: URLs that open specific parts of an app
 * - App lifecycle: The different states an app goes through
 * - Communication: How different parts of an app talk to each other
 * - Event-driven architecture: Designing systems that respond to events
 * - Error handling: Managing what happens when things go wrong
 * - Performance: Making sure notification handling is efficient
 * - Testing: Ensuring notification handling works correctly
 * - Security: Making sure notifications are handled safely
 * - Code organization: Keeping related functionality together
 */

import SwiftUI
import OSLog

@MainActor
final class NotificationCoordinator: ObservableObject {
    // MARK: - Dependencies
    weak var appState: AppState?
    weak var navigationCoordinator: NavigationCoordinator?
    weak var appGroupBridge: AppGroupBridge?
    
    // MARK: - Properties
    private var observers: [NSObjectProtocol] = []
    private let logger = Logger(subsystem: "com.streaksync.app", category: "NotificationCoordinator")
    // Injected ingestion closure to serialize result handling
    var resultIngestion: ((GameResult) async -> Void)?
    
    // MARK: - Published State
    @Published var refreshID = UUID()
    
    // MARK: - Initialization
    init() {
        // Observers will be set up by AppContainer after dependencies are wired
    }
    
    deinit {
        // Cleanup happens automatically when observers are deallocated
        // No need to manually remove observers in deinit
    }
    
    // MARK: - Setup
    func setupObservers() {
        logger.info("📡 Setting up notification observers")
        
        // Remove any existing observers first
        removeObservers()
        
        // Game result received from share extension
        self.observers.append(
            NotificationCenter.default.addObserver(
                forName: .gameResultReceived,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                // Extract object before using it to avoid Sendable issues
                guard let result = notification.object as? GameResult else { return }
                Task { @MainActor [weak self] in
                    self?.handleGameResult(result)
                }
            }
        )

        
        // Open game deep link request
        self.observers.append(
            NotificationCenter.default.addObserver(
                forName: .openGameRequested,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                // Extract object before using it to avoid Sendable issues
                guard let payload = notification.object as? [String: Any],
                      let gameId = payload[AppConstants.DeepLinkKeys.gameId] as? UUID else { return }
                Task { @MainActor [weak self] in
                    self?.handleGameDeepLinkWithId(gameId)
                }
            }

        )
        
        // Open achievement deep link request
        self.observers.append(
            NotificationCenter.default.addObserver(
                forName: .openAchievementRequested,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                // Extract object before using it to avoid Sendable issues
                guard let payload = notification.object as? [String: Any],
                      let achievementId = payload[AppConstants.DeepLinkKeys.achievementId] as? UUID else { return }
                Task { @MainActor [weak self] in
                    self?.handleAchievementDeepLinkWithId(achievementId)
                }
            }

        )
        
        // App lifecycle notifications
        self.observers.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.handleAppDidBecomeActive()
                }
            }
        )
        
        self.observers.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleAppWillResignActive()
                }
            }
        )
        
        // Share extension result available
        self.observers.append(
            NotificationCenter.default.addObserver(
                forName: .init(AppConstants.Notification.shareExtensionResultAvailable),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.handleShareExtensionResult()
                }
            }
        )
        
        // Listen for refresh triggers
        self.observers.append(
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name(AppConstants.Notification.gameDataUpdated),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.triggerUIRefresh()
                }
            }
                
        )
        
        logger.info("✅ Set up \(self.observers.count) notification observers")
    }
    
    private func removeObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
    
    // MARK: - Cleanup
    func cleanup() {
        removeObservers()
        logger.info("🧹 NotificationCoordinator cleaned up")
    }
    
    // MARK: - Notification Handlers
    
    private func handleGameResult(_ result: GameResult) {
        logger.info("✅ Handling game result: \(result.gameName) - \(result.displayScore)")
        
        if let ingest = resultIngestion {
            Task { await ingest(result) }
        } else {
            appState?.addGameResult(result)
        }
        
        // Trigger UI refresh
        triggerUIRefresh()
        
        // Haptic feedback
        HapticManager.shared.trigger(.streakUpdate)
    }
    
    private func handleGameResultNotification(_ notification: Notification) {
        guard let result = notification.object as? GameResult else {
            logger.error("❌ Invalid game result in notification")
            return
        }
        
        logger.info("✅ Handling game result: \(result.gameName) - \(result.displayScore)")
        
        if let ingest = resultIngestion {
            Task { await ingest(result) }
        } else {
            appState?.addGameResult(result)
        }
        
        // Trigger UI refresh
        triggerUIRefresh()
        
        // Haptic feedback
        HapticManager.shared.trigger(.streakUpdate)
    }
    
    private func handleGameDeepLink(_ notification: Notification) {
        guard let payload = notification.object as? [String: Any] else {
            logger.error("❌ Invalid game deep link payload")
            return
        }
        // Prefer id; fallback to name
        if let gameId = payload[AppConstants.DeepLinkKeys.gameId] as? UUID,
           let game = appState?.games.first(where: { $0.id == gameId }) {
            logger.info("🔗 Handling game deep link by id: \(gameId)")
            navigationCoordinator?.navigateTo(.gameDetail(game))
            return
        }
        if let name = payload[AppConstants.DeepLinkKeys.name] as? String,
           let game = appState?.games.first(where: { $0.name.lowercased() == name.lowercased() || $0.displayName.lowercased() == name.lowercased() }) {
            logger.info("🔗 Handling game deep link by name: \(name)")
            navigationCoordinator?.navigateTo(.gameDetail(game))
            return
        }
        logger.error("❌ Game not found for deep link payload: \(payload)")
    }
    
    private func handleGameDeepLinkWithId(_ gameId: UUID) {
        if let game = appState?.games.first(where: { $0.id == gameId }) {
            logger.info("🔗 Handling game deep link by id: \(gameId)")
            navigationCoordinator?.navigateTo(.gameDetail(game))
        } else {
            logger.error("❌ Game not found for id: \(gameId)")
        }
    }
    
    private func handleAchievementDeepLink(_ notification: Notification) {
        guard let payload = notification.object as? [String: Any],
              let achievementId = payload[AppConstants.DeepLinkKeys.achievementId] as? UUID else {
            logger.error("❌ Invalid achievement deep link payload")
            return
        }
        
        logger.info("🔗 Handling achievement deep link: \(achievementId)")
        
        // Navigate to achievements
        navigationCoordinator?.navigateTo(.achievements)
        
        // Present tiered achievement detail if found
        if let tiered = appState?.tieredAchievements.first(where: { $0.id == achievementId }) {
            navigationCoordinator?.presentSheet(.tieredAchievementDetail(tiered))
        }
    }
    
    private func handleAchievementDeepLinkWithId(_ achievementId: UUID) {
        logger.info("🔗 Handling achievement deep link: \(achievementId)")
        
        // Navigate to achievements
        navigationCoordinator?.navigateTo(.achievements)
        
        // Present tiered achievement detail if found
        if let tiered = appState?.tieredAchievements.first(where: { $0.id == achievementId }) {
            navigationCoordinator?.presentSheet(.tieredAchievementDetail(tiered))
        }
    }
    
    // MARK: - App Lifecycle
    
    private func handleAppDidBecomeActive() async {
        logger.info("📱 App became active (via notification)")
        
        // Skip expensive operations if navigating from notification
        if appState?.isNavigatingFromNotification == true {
            logger.info("🚀 Skipping share extension check - navigating from notification")
            return
        }
        
        // Check for new results from share extension
        if appGroupBridge?.hasNewResults ?? false {
            await handleShareExtensionResult()
        }
    }
    
    private func handleAppWillResignActive() {
        logger.info("📱 App will resign active")
        appGroupBridge?.stopMonitoringForResults()
    }
    
    private func handleShareExtensionResult() async {
        logger.info("📤 Received Share Extension notification")
        
        // Let AppState handle the sync
        await appState?.loadPersistedData()
        
        // Clear the bridge
        appGroupBridge?.clearLatestResult()
        
        // Trigger UI refresh
        triggerUIRefresh()
    }
    
    // MARK: - UI Updates
    
    func triggerUIRefresh() {
        logger.info("🔄 Triggering UI refresh")
        refreshID = UUID()
        
        // Post additional notifications for specific UI updates
        NotificationCenter.default.post(
            name: NSNotification.Name(AppConstants.Notification.gameResultReceived),
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    func handleURLScheme(_ url: URL) -> Bool {
        logger.info("🔗 NotificationCoordinator handling URL: \(url.absoluteString)")
        return appGroupBridge?.handleURLScheme(url) ?? false
    }
}
