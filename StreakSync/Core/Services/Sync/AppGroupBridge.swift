//
//  AppGroupBridge.swift - REFACTORED
//  StreakSync
//
//  Lightweight coordinator for App Group communication
//

import Foundation
import OSLog
import UIKit

@MainActor
final class AppGroupBridge: ObservableObject {
    // MARK: - Singleton
    static let shared = AppGroupBridge()
    
    // MARK: - Components
    private let dataManager: AppGroupDataManager
    private let darwinHandler: AppGroupDarwinNotificationHandler
    private let urlHandler: AppGroupURLSchemeHandler
    private let resultMonitor: AppGroupResultMonitor
    
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AppGroupBridge")
    private var lifecycleObservers: [NSObjectProtocol] = []
    
    // MARK: - Published State
    @Published private(set) var hasNewResults = false
    @Published private(set) var latestResult: GameResult?
    @Published private(set) var isProcessing = false
    @Published var lastResultProcessedTime = Date()
    
    // MARK: - Computed Properties
    var isMonitoringForResults: Bool {
        resultMonitor.isMonitoring
    }
    
    // MARK: - Initialization
    private init() {
        // Initialize components
        self.dataManager = AppGroupDataManager()
        self.darwinHandler = AppGroupDarwinNotificationHandler()
        self.urlHandler = AppGroupURLSchemeHandler()
        self.resultMonitor = AppGroupResultMonitor(dataManager: dataManager)
        
        setupObservers()
        setupDarwinNotifications()
    }
    
    deinit {
        // Note: lifecycleObservers cleanup happens automatically
        // Cannot access mutable state in deinit under strict concurrency
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // App lifecycle observers
        lifecycleObservers = [
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.checkForNewResults()
                }
            },
            
            NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.checkForNewResults()
                }
            },
            
            // Handle new result notifications
            NotificationCenter.default.addObserver(
                forName: .appHandleNewGameResult,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.checkForNewResults()
                }
            }
        ]
    }
    
    private func setupDarwinNotifications() {
        darwinHandler.startObserving { [weak self] in
            await self?.checkForNewResults()
        }
    }
    
    // MARK: - Public Methods
    func handleURLScheme(_ url: URL) -> Bool {
        urlHandler.handleURLScheme(url)
    }
    
    func startMonitoringForResults() {
        resultMonitor.startMonitoring { [weak self] in
            await self?.processNewResult()
        }
    }
    
    func stopMonitoringForResults() {
        resultMonitor.stopMonitoring()
    }
    
    // MARK: - Result Management

    /// Ingestion trigger handler for Share Extension results.
    ///
    /// Expected flow (per-result, gated on durable persistence — T1-2):
    ///   1. consumePendingDeepLinkIfNeeded() — honor a Share Extension "Show" tap.
    ///   2. resultMonitor.loadQueuedResults() — read the queue WITHOUT clearing it.
    ///   3. Post .gameResultReceived per result → NotificationCoordinator.handleGameResult
    ///      routes it through gameResultSyncService / appState.addGameResult.
    ///   4. handleGameResult awaits a confirmed durable local write, then calls
    ///      acknowledgeIngestedResult(id:) — the ONLY path that removes a result
    ///      from the queue. A crash before step 4 leaves the result queued so the
    ///      next activation re-ingests it (duplicate detection dedupes).
    func checkForNewResults() async {
        guard !isProcessing else { return }

        isProcessing = true
        defer { isProcessing = false }

        // Consume a pending deep-link gameId set by the Share Extension's
        // "Show" button. This is the fallback path when iOS blocks the
        // extension from launching the host app directly via URL scheme —
        // whenever the app activates we honor the intent.
        consumePendingDeepLinkIfNeeded()

        // Load queued results (they stay queued until each is acknowledged as
        // durably persisted by the main app — do NOT clear here).
        let queuedResults = await resultMonitor.loadQueuedResults()

        if !queuedResults.isEmpty {
            hasNewResults = true
            lastResultProcessedTime = Date()

 logger.info("Dispatching \(queuedResults.count) queued results for durable ingestion")

            for result in queuedResults {
                latestResult = result
 logger.info("Dispatching queued result: \(result.gameName)")

                // Post notification with the result object. Cleanup happens in
                // acknowledgeIngestedResult after a confirmed durable write.
                NotificationCenter.default.post(
                    name: .gameResultReceived,
                    object: result,
                    userInfo: ["quiet": true]
                )
            }

            return
        }

        // Fallback to single result for backward compatibility
        hasNewResults = dataManager.hasData(forKey: AppConstants.AppGroup.latestResultKey)

        if hasNewResults {
            lastResultProcessedTime = Date()

            // Load the result
            if let result = try? await dataManager.loadGameResult(forKey: AppConstants.AppGroup.latestResultKey) {
                latestResult = result
 logger.info("Loaded new result: \(result.gameName)")

                // Post notification with the result object. The single-result key
                // is cleared by acknowledgeIngestedResult only after a confirmed
                // durable write, not here (T1-2).
                NotificationCenter.default.post(
                    name: .gameResultReceived,
                    object: result
                )
            }
        }
    }

    /// Removes a result's App Group queue entry (both the per-key queue slot and
    /// the single-result fallback key) after the main app confirms a durable local
    /// write. This is the only path that removes a result from the cross-process
    /// queue, guaranteeing a result can't be lost before it's persisted (T1-2).
    func acknowledgeIngestedResult(id: UUID) {
        resultMonitor.acknowledgeProcessedResult(id: id)
        dataManager.removeData(forKey: AppConstants.AppGroup.latestResultKey)
    }
    
    func clearLatestResult() {
        dataManager.removeData(forKey: AppConstants.AppGroup.latestResultKey)
        hasNewResults = false
        latestResult = nil
 logger.info("Cleared latest result")
    }

    /// Clears all App Group data (queue, legacy entries, single-result key).
    /// Called during sign-out to prevent stale results from leaking to the next session.
    func clearAllData() {
        dataManager.clearAll()
        hasNewResults = false
        latestResult = nil
    }
    
    // MARK: - Private Methods
    private func processNewResult() async {
        await checkForNewResults()
    }

    /// Reads and clears the Share Extension's pending deep-link gameId.
    /// Fires `.openGameRequested` so the existing NotificationCoordinator
    /// routing path (used by URL schemes and notification taps) handles it.
    private func consumePendingDeepLinkIfNeeded() {
        let defaults = UserDefaults(suiteName: AppConstants.AppGroup.identifier)
        guard let raw = defaults?.string(forKey: AppConstants.AppGroup.pendingDeepLinkGameIdKey),
              let gameId = UUID(uuidString: raw) else {
            return
        }
        defaults?.removeObject(forKey: AppConstants.AppGroup.pendingDeepLinkGameIdKey)
        logger.info("Consuming pending deep link from Share Extension: \(gameId)")
        NotificationCenter.default.post(
            name: .openGameRequested,
            object: [AppConstants.DeepLinkKeys.gameId: gameId]
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let gameResultReceived = Notification.Name("gameResultReceived")
    static let openGameRequested = Notification.Name("openGameRequested")
    static let openAchievementRequested = Notification.Name("openAchievementRequested")
    static let joinGroupRequested = Notification.Name("joinGroupRequested")
    static let streakUpdated = Notification.Name("streakUpdated")
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
}
