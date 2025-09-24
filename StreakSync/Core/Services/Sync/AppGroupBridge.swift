//
//  AppGroupBridge.swift - REFACTORED
//  StreakSync
//
//  Lightweight coordinator for App Group communication
//

import Foundation
import UIKit
import OSLog

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
        Task { await checkForNewResults() }
    }
    
    deinit {
        // Clean up lifecycle observers
        lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
        lifecycleObservers.removeAll()
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
                forName: Notification.Name("HandleNewGameResult"),
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
    func checkForNewResults() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        hasNewResults = dataManager.hasData(forKey: AppConstants.AppGroup.latestResultKey)
        
        if hasNewResults {
            lastResultProcessedTime = Date()
            
            // Load the result
            if let result = try? await dataManager.loadGameResult(forKey: AppConstants.AppGroup.latestResultKey) {
                latestResult = result
                logger.info("📥 Loaded new result: \(result.gameName)")
            }
            
            // Post notification
            NotificationCenter.default.post(
                name: .gameResultReceived,
                object: nil
            )
        }
    }
    
    func clearLatestResult() {
        dataManager.removeData(forKey: AppConstants.AppGroup.latestResultKey)
        hasNewResults = false
        latestResult = nil
        logger.info("🗑️ Cleared latest result")
    }
    
    // MARK: - Private Methods
    private func processNewResult() async {
        await checkForNewResults()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let gameResultReceived = Notification.Name("gameResultReceived")
    static let openGameRequested = Notification.Name("openGameRequested")
    static let openAchievementRequested = Notification.Name("openAchievementRequested")
    static let streakUpdated = Notification.Name("streakUpdated")
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
}
