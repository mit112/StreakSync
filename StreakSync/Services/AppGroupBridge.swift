//
//  AppGroupBridge.swift - MIGRATED TO APPERROR
//  StreakSync
//
//  UPDATED: Using centralized AppError instead of local AppGroupBridgeError
//

import Foundation
import UIKit
import UserNotifications
import OSLog

// MARK: - App Group Bridge (Using AppError)
@MainActor
final class AppGroupBridge: ObservableObject {
    
    // MARK: - Singleton
    static let shared = AppGroupBridge()
    
    // MARK: - Properties
    private let appGroupID = "group.com.mitsheth.StreakSync"
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AppGroupBridge")
    private var notificationObserver: NSObjectProtocol?
    private var lifecycleObservers: [NSObjectProtocol] = []
    
    // MARK: - iOS-Specific Duplicate Prevention
    private var lastProcessedTimestamp: Date?
    private var processedResultHashes: Set<String> = []
    private let calendar = Calendar.current
    
    // MARK: - Published Properties (MainActor Safe)
    @Published private(set) var hasNewResults = false
    @Published private(set) var latestResult: GameResult?
    @Published private(set) var isProcessing = false
    
    // MARK: - CRITICAL: New property for UI refresh
    @Published var lastResultProcessedTime: Date = Date()
    
    // MARK: - CRITICAL FIX: Matching decoder with Share Extension
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    // Add these properties to AppGroupBridge
    @Published var isMonitoringForResults = false
    private var monitoringTask: Task<Void, Never>?
    private var lastKnownResultId: UUID?
    
    // MARK: - Darwin Notification Support
    private let darwinNotificationName = "com.streaksync.app.newResult"
    
    // MARK: - Initialization (Private - Singleton)
    private init() {
        setupObservers()
        Task { await checkForNewResults() }
    }
    
    deinit {
        // Remove Darwin observer (safe to do from any thread)
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        // Clean up other observers on MainActor
        Task { @MainActor in
            lifecycleObservers.forEach { observer in
                NotificationCenter.default.removeObserver(observer)
            }
            lifecycleObservers.removeAll()
            
            if let notificationObserver = notificationObserver {
                NotificationCenter.default.removeObserver(notificationObserver)
            }
        }
    }
    
    // MARK: - Observer Setup (Fixed Memory Leaks)
    private func setupObservers() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, name, _, _ in
                guard let observer = observer else { return }
                let bridge = Unmanaged<AppGroupBridge>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    await bridge.handleDarwinNotification()
                }
            },
            darwinNotificationName as CFString,
            nil,
            .deliverImmediately
        )
        
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
            }
        ]
    }
    
    
    // MARK: - Darwin Notification Handling
    private func handleDarwinNotification() async {
        logger.info("📱 Received Darwin notification for new result")
        await checkForNewResults()
    }
    
    // MARK: - Result Checking (Updated with AppError)
    func checkForNewResults() async {
        guard !isProcessing else {
            logger.debug("Already processing, skipping check")
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Check App Group for new result
            guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
                throw AppError.sync(.appGroupCommunicationFailed)
            }
            
            // Check if share extension is still processing
            if userDefaults.bool(forKey: "isProcessingShare") {
                logger.info("Share Extension is still processing")
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await checkForNewResults() // Recursive check
                return
            }
            
            guard let data = userDefaults.data(forKey: "latestGameResult") else {
                logger.debug("No new game result data found")
                hasNewResults = false
                return
            }
            
            let result = try decoder.decode(GameResult.self, from: data)
            
            // Duplicate check
            guard !isDuplicateResult(result) else {
                logger.info("Skipping duplicate result for \(result.gameName)")
                throw AppError.sync(.resultAlreadyProcessed)
            }
            
            // Update state
            self.latestResult = result
            self.hasNewResults = true
            
            // CRITICAL: Update the timestamp to trigger UI refresh
            self.lastResultProcessedTime = Date()
            
            // Mark as processed
            markResultAsProcessed(result)
            
            // Post notification
            NotificationCenter.default.post(
                name: .gameResultReceived,
                object: result
            )
            
            logger.info("✅ New game result ready: \(result.gameName)")
            
        } catch let error as AppError {
            logger.error("❌ Error checking for results: \(error.localizedDescription)")
            hasNewResults = false
        } catch {
            // Convert unknown errors to AppError
            logger.error("❌ Unexpected error: \(error.localizedDescription)")
            hasNewResults = false
        }
    }
    
    // MARK: - Result Processing (Updated with AppError)
    func processLatestResult() async {
        guard hasNewResults, let result = latestResult else {
            logger.warning("No new result to process")
            return
        }
        
        logger.info("Processing result: \(result.gameName)")
        
        // Clear the result from App Group
        clearLatestResult()
        
        // Reset state
        hasNewResults = false
        latestResult = nil
        
        logger.info("✅ Result processed and cleared")
    }
    
    private func clearLatestResult() {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            logger.error("Failed to access App Group - \(AppError.sync(.appGroupCommunicationFailed).localizedDescription)")
            return
        }
        
        userDefaults.removeObject(forKey: "latestGameResult")
        userDefaults.synchronize()
    }
    
    // MARK: - Duplicate Prevention (Unchanged)
    private func isDuplicateResult(_ result: GameResult) -> Bool {
        let resultHash = "\(result.gameName)-\(result.score)-\(result.date.timeIntervalSince1970)"
        
        if processedResultHashes.contains(resultHash) {
            return true
        }
        
        if let lastTimestamp = lastProcessedTimestamp {
            let timeDiff = abs(result.date.timeIntervalSince(lastTimestamp))
            if timeDiff < 2.0 && result.gameName == latestResult?.gameName {
                return true
            }
        }
        
        return false
    }
    
    private func markResultAsProcessed(_ result: GameResult) {
        let resultHash = "\(result.gameName)-\(result.score)-\(result.date.timeIntervalSince1970)"
        processedResultHashes.insert(resultHash)
        lastProcessedTimestamp = result.date
        
        // Keep only recent hashes
        if processedResultHashes.count > 100 {
            processedResultHashes.removeAll()
        }
    }
    
    // MARK: - Manual Share Sheet Trigger (Updated with AppError)
    func handleManualShare(from userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == "com.streaksync.share" else {
            return false
        }
        
        logger.info("Manual share activity detected")
        
        Task { @MainActor in
            await checkForNewResults()
        }
        
        return true
    }
    
    // MARK: - iOS-Specific URL Scheme Handler (Updated with AppError)
    func handleURLScheme(_ url: URL) -> Bool {
        logger.info("Handling URL: \(url.absoluteString)")
        
        guard url.scheme == "streaksync" else {
            logger.error("Invalid URL scheme - \(AppError.sync(.urlSchemeInvalid(url: url.absoluteString)).localizedDescription)")
            return false
        }
        
        guard let host = url.host else {
            logger.warning("URL missing host component")
            return false
        }
        
        let parameters = url.queryParameters
        
        switch host {
        case "newresult":
            logger.info("Received new result URL scheme trigger")
            handleNewGameResult()
            return true
            
        case "game":
            return handleGameDeepLink(parameters)
            
        case "achievement":
            return handleAchievementDeepLink(parameters)
            
        default:
            logger.warning("Unknown URL scheme host: \(host)")
            return false
        }
    }
    
    private func handleGameDeepLink(_ parameters: [String: String]) -> Bool {
        guard let gameParameter = parameters["name"] else {
            logger.warning("Game deep link missing name parameter")
            return false
        }
        
        // Also get the game ID if available
        let gameId = parameters["id"]
        
        // Create a dictionary with both name and ID
        let gameInfo: [String: String] = [
            "name": gameParameter,
            "id": gameId ?? ""
        ]
        
        NotificationCenter.default.post(
            name: .openGameRequested,
            object: gameInfo
        )
        
        logger.info("Handled game deep link for: \(gameParameter) with ID: \(gameId ?? "none")")
        return true
    }
    
    private func handleAchievementDeepLink(_ parameters: [String: String]) -> Bool {
        guard let achievementId = parameters["id"] else {
            logger.warning("Achievement deep link missing id parameter")
            return false
        }
        
        NotificationCenter.default.post(
            name: .openAchievementRequested,
            object: achievementId
        )
        
        logger.info("Handled achievement deep link for: \(achievementId)")
        return true
    }
    
    // MARK: - Pending Results Check (Compatibility method)
    func checkForPendingResults() async {
        logger.info("Checking for pending results from Share Extension")
        
        if await hasNewResults {
            await processLatestResult()
        }
    }
    
    // MARK: - Real-time Monitoring (Updated with AppError)
    func startMonitoringForResults() {
        guard !isMonitoringForResults else { return }
        
        logger.info("🔄 Starting continuous monitoring for new results")
        isMonitoringForResults = true
        
        // Cancel any existing task
        monitoringTask?.cancel()
        
        // Start new monitoring task
        monitoringTask = Task { @MainActor in
            while !Task.isCancelled && isMonitoringForResults {
                await checkForNewResults()
                
                // Wait 1 second between checks
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
    
    func stopMonitoringForResults() {
        logger.info("⏹️ Stopping continuous monitoring")
        isMonitoringForResults = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    // MARK: - Direct Result Detection (Updated with AppError)
    func checkForResultUpdate() async -> Bool {
        do {
            guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
                throw AppError.sync(.appGroupCommunicationFailed)
            }
            
            // Check for result data
            guard let data = userDefaults.data(forKey: "latestGameResult") else {
                return false
            }
            
            // Try to decode it
            let result = try decoder.decode(GameResult.self, from: data)
            
            // Check if it's different from last known
            if let lastKnown = lastKnownResultId, lastKnown == result.id {
                return false // Same result
            }
            
            // New result detected
            lastKnownResultId = result.id
            return true
            
        } catch {
            logger.error("Error checking for result update: \(error)")
            return false
        }
    }
    
    func handleNewGameResult() {
        logger.info("New game result trigger received")
        Task { @MainActor in
            await checkForNewResults()
        }
    }
}

// MARK: - Notification Names (Unchanged)
extension Notification.Name {
    static let gameResultReceived = Notification.Name("gameResultReceived")
    static let openGameRequested = Notification.Name("openGameRequested")
    static let openAchievementRequested = Notification.Name("openAchievementRequested")
    static let streakUpdated = Notification.Name("streakUpdated")
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
}

// MARK: - URL Extensions for Query Parameters (Unchanged)
extension URL {
    var queryParameters: [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            return [:]
        }
        
        return queryItems.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value ?? ""
        }
    }
}
