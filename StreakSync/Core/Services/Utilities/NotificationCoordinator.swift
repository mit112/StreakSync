//
//  NotificationCoordinator.swift
//  StreakSync
//
//  Centralized notification handling and app communication
//

import SwiftUI
import UIKit
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
    // Injected ingestion closure to serialize result handling (returns whether added)
    var resultIngestion: ((GameResult) async -> Bool)?
    // Debounce UI refresh spam
    private var lastUIRefreshAt: Date?
    private let uiRefreshDebounceInterval: TimeInterval = 0.3
    
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
 logger.info("Setting up notification observers")
        
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
                    self?.handleGameResult(result, quiet: false)
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
                forName: .appGameDataUpdated,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.triggerUIRefresh()
                }
            }
                
        )
        
 logger.info("Set up \(self.observers.count) notification observers")
    }
    
    private func removeObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
    
    // MARK: - Cleanup
    func cleanup() {
        removeObservers()
 logger.info("NotificationCoordinator cleaned up")
    }
    
    // MARK: - Notification Handlers
    
    private func handleGameResult(_ result: GameResult, quiet: Bool) {
 logger.info("Handling game result: \(result.gameName) - \(result.displayScore)")
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            // Ingest and capture whether it actually added
            let added: Bool
            if let ingest = self.resultIngestion {
                added = await ingest(result)
            } else {
                added = self.appState?.addGameResult(result) ?? false
            }
            
            // Trigger UI refresh
            self.triggerUIRefresh()
            
            // Gate haptics: only when app is active and the result was added
            let isActive = UIApplication.shared.applicationState == .active
            if isActive && added && !quiet {
                HapticManager.shared.trigger(.streakUpdate)
            } else {
                let reason = !isActive ? "app not active" : !added ? "duplicate/invalid result" : "quiet batch"
 self.logger.debug("Haptics suppressed: \(reason)")
            }
        }
    }
    
    private func handleGameDeepLinkWithId(_ gameId: UUID) {
        if let game = appState?.games.first(where: { $0.id == gameId }) {
 logger.info("Handling game deep link by id: \(gameId)")
            navigationCoordinator?.navigateTo(.gameDetail(game))
        } else {
 logger.error("Game not found for id: \(gameId)")
        }
    }
    
    private func handleAchievementDeepLinkWithId(_ achievementId: UUID) {
 logger.info("Handling achievement deep link: \(achievementId)")
        
        // Navigate to achievements
        navigationCoordinator?.navigateTo(.achievements)
        
        // Present tiered achievement detail if found
        if let tiered = appState?.tieredAchievements.first(where: { $0.id == achievementId }) {
            navigationCoordinator?.presentSheet(.tieredAchievementDetail(tiered))
        }
    }
    
    // MARK: - App Lifecycle
    
    private func handleAppDidBecomeActive() async {
 logger.info("App became active (via notification)")
        
        // Skip expensive operations if navigating from notification
        if appState?.isNavigatingFromNotification == true {
 logger.info("Skipping share extension check - navigating from notification")
            return
        }
        
        // No-op: AppGroupBridge owns lifecycle share checks to avoid duplicates
    }
    
    private func handleAppWillResignActive() {
        // Downgrade to debug to avoid duplicate lifecycle noise; AppContainer handles monitoring stop.
 logger.debug("App will resign active (NotificationCoordinator)")
    }
    
    private func handleShareExtensionResult() async {
        // No-op: AppGroupBridge's Darwin observer triggers the check; avoid duplicate processing here.
 logger.info("Received Share Extension notification (handled by bridge)")
    }
    
    // MARK: - UI Updates
    
    func triggerUIRefresh() {
        // Debounce to avoid rapid repeated refreshes from batch operations
        let now = Date()
        if let last = lastUIRefreshAt, now.timeIntervalSince(last) < uiRefreshDebounceInterval {
 logger.debug("Skipping UI refresh (debounced)")
            return
        }
        lastUIRefreshAt = now
        
 logger.info("Triggering UI refresh")
        refreshID = UUID()
        
        // Post additional notifications for specific UI updates
        NotificationCenter.default.post(
            name: NSNotification.Name(AppConstants.Notification.gameResultReceived),
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    func handleURLScheme(_ url: URL) -> Bool {
 logger.info("NotificationCoordinator handling URL: \(url.absoluteString)")
        return appGroupBridge?.handleURLScheme(url) ?? false
    }
}
