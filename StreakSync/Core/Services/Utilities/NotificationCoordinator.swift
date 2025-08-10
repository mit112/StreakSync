//
//  NotificationCoordinator.swift
//  StreakSync
//
//  Centralized notification handling and app communication
//

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
                Task { @MainActor in
                    self?.handleGameResultNotification(notification)
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
                Task { @MainActor in
                    self?.handleGameDeepLink(notification)
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
                Task { @MainActor in
                    self?.handleAchievementDeepLink(notification)
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
                Task { @MainActor in
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
                forName: NSNotification.Name("GameDataUpdated"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
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
    
    private func handleGameResultNotification(_ notification: Notification) {
        guard let result = notification.object as? GameResult else {
            logger.error("❌ Invalid game result in notification")
            return
        }
        
        logger.info("✅ Handling game result: \(result.gameName) - \(result.displayScore)")
        
        appState?.addGameResult(result)
        
        // Trigger UI refresh
        triggerUIRefresh()
        
        // Haptic feedback
        HapticManager.shared.trigger(.streakUpdate)
    }
    
    private func handleGameDeepLink(_ notification: Notification) {
        guard let gameInfo = notification.object as? [String: Any],
              let gameId = gameInfo["gameId"] as? UUID else {
            logger.error("❌ Invalid game deep link data")
            return
        }
        
        logger.info("🔗 Handling game deep link: \(gameId)")
        
        // Find the game and navigate
        if let game = appState?.games.first(where: { $0.id == gameId }) {
            navigationCoordinator?.navigateTo(.gameDetail(game))
        }
    }
    
    private func handleAchievementDeepLink(_ notification: Notification) {
        guard let achievementInfo = notification.object as? [String: Any],
              let achievementId = achievementInfo["achievementId"] as? UUID else {
            logger.error("❌ Invalid achievement deep link data")
            return
        }
        
        logger.info("🔗 Handling achievement deep link: \(achievementId)")
        
        // Navigate to achievements
        navigationCoordinator?.navigateTo(.achievements)
        
        // Present achievement detail if found
        if let achievement = appState?.unlockedAchievements.first(where: { $0.id == achievementId }) {
            navigationCoordinator?.presentSheet(.achievementDetail(achievement))
        }
    }
    
    // MARK: - App Lifecycle
    
    private func handleAppDidBecomeActive() async {
        logger.info("📱 App became active (via notification)")
        
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
        logger.info("📱 Received Share Extension notification")
        
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
            name: NSNotification.Name("GameResultAdded"),
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    func handleURLScheme(_ url: URL) -> Bool {
        logger.info("🔗 NotificationCoordinator handling URL: \(url.absoluteString)")
        return appGroupBridge?.handleURLScheme(url) ?? false
    }
}
