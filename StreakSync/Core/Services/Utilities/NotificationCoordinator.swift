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
                self?.handleGameResult(result)
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
                self?.handleGameDeepLinkWithId(gameId)
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
                self?.handleAchievementDeepLinkWithId(achievementId)
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
