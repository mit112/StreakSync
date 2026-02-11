//
//  AppGroupBridge.swift - REFACTORED
//  StreakSync
//
//  Lightweight coordinator for App Group communication
//

/*
 * APPGROUPBRIDGE - INTER-APP COMMUNICATION COORDINATOR
 * 
 * WHAT THIS FILE DOES:
 * This file is the "messenger" between the main StreakSync app and the Share Extension. It's like
 * a "postal service" that delivers game results from the Share Extension to the main app. When
 * users share game results from other apps, the Share Extension saves them to shared storage,
 * and this bridge picks them up and delivers them to the main app. It also handles deep links
 * and app lifecycle events to ensure seamless communication between the two parts of the app.
 * 
 * WHY IT EXISTS:
 * iOS apps and their extensions run in separate processes and can't directly communicate. This
 * bridge uses App Groups (shared storage) and Darwin notifications (system-level messaging) to
 * enable communication between the main app and the Share Extension. Without this bridge, the
 * Share Extension couldn't deliver game results to the main app, making the core feature useless.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This enables the core feature of adding game results from other apps
 * - Coordinates communication between main app and Share Extension
 * - Handles deep links and URL schemes for seamless user experience
 * - Monitors app lifecycle events to check for new results
 * - Provides real-time updates when new game results are available
 * - Manages shared storage access and data synchronization
 * - Ensures thread-safe communication between app components
 * 
 * WHAT IT REFERENCES:
 * - AppGroupDataManager: Handles reading/writing shared storage
 * - AppGroupDarwinNotificationHandler: Manages system-level notifications
 * - AppGroupURLSchemeHandler: Processes deep links and URL schemes
 * - AppGroupResultMonitor: Monitors for new results in shared storage
 * - NotificationCenter: For app lifecycle and custom notifications
 * - UIKit: For app lifecycle events and notifications
 * 
 * WHAT REFERENCES IT:
 * - AppContainer: Creates and manages the AppGroupBridge
 * - AppState: Uses this to receive new game results
 * - Share Extension: Saves results that this bridge picks up
 * - Deep link handlers: Use this to process incoming URLs
 * - App lifecycle managers: Use this to check for new results
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. ARCHITECTURE IMPROVEMENTS:
 *    - The current singleton pattern could be replaced with dependency injection
 *    - Consider using a protocol-based approach for better testability
 *    - Add support for multiple result sources and destinations
 *    - Implement proper error handling and recovery strategies
 * 
 * 2. COMMUNICATION IMPROVEMENTS:
 *    - The current communication is basic - could be more sophisticated
 *    - Add support for bidirectional communication
 *    - Implement message queuing for reliable delivery
 *    - Add support for different message types and priorities
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current monitoring could be more efficient
 *    - Consider using file system events instead of polling
 *    - Add result batching for better performance
 *    - Implement smart polling based on user activity
 * 
 * 4. ERROR HANDLING:
 *    - The current error handling is basic - could be more robust
 *    - Add retry mechanisms for failed operations
 *    - Implement fallback strategies for communication failures
 *    - Add detailed logging for debugging communication issues
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for all communication logic
 *    - Test error handling and edge cases
 *    - Add integration tests with mock Share Extension
 *    - Test app lifecycle and notification handling
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for communication protocols
 *    - Document the data flow and message formats
 *    - Add examples of how to use the bridge
 *    - Create communication flow diagrams
 * 
 * 7. SECURITY IMPROVEMENTS:
 *    - Add validation for incoming data
 *    - Implement access controls for shared storage
 *    - Add audit logging for security monitoring
 *    - Consider adding data encryption for sensitive information
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new communication channels
 *    - Add support for different data formats
 *    - Implement plugin system for custom handlers
 *    - Add support for versioned communication protocols
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - App Groups: Shared storage between the main app and extensions
 * - Darwin notifications: System-level messaging between processes
 * - URL schemes: Custom URLs that can open specific parts of an app
 * - App lifecycle: Events when the app becomes active, goes to background, etc.
 * - Singleton pattern: A design pattern that ensures only one instance exists
 * - ObservableObject: Makes this class work with SwiftUI's reactive system
 * - @Published: Properties that trigger UI updates when they change
 * - @MainActor: Ensures all operations happen on the main thread
 * - Inter-process communication: How different parts of an app talk to each other
 * - Shared storage: Data that can be accessed by multiple app components
 */

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
    func checkForNewResults() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Check for queued results first
        let queuedResults = await resultMonitor.processQueuedResults()
        
        if !queuedResults.isEmpty {
            hasNewResults = true
            lastResultProcessedTime = Date()
            
            logger.info("📥 Processing \(queuedResults.count) queued results")
            
            // Process each result in the queue
            for result in queuedResults {
                latestResult = result
                logger.info("📥 Processing queued result: \(result.gameName)")
                
                // Post notification with the result object
                NotificationCenter.default.post(
                    name: .gameResultReceived,
                    object: result,
                    userInfo: ["quiet": true]
                )
            }
            
            // Clear single-result key to prevent duplicate handling via fallback path
            dataManager.removeData(forKey: AppConstants.AppGroup.latestResultKey)
            logger.info("🧹 Cleared latest result after queue processing to prevent duplicates")
            
            return
        }
        
        // Fallback to single result for backward compatibility
        hasNewResults = dataManager.hasData(forKey: AppConstants.AppGroup.latestResultKey)
        
        if hasNewResults {
            lastResultProcessedTime = Date()
            
            // Load the result
            if let result = try? await dataManager.loadGameResult(forKey: AppConstants.AppGroup.latestResultKey) {
                latestResult = result
                logger.info("📥 Loaded new result: \(result.gameName)")
                
                // Post notification with the result object
                NotificationCenter.default.post(
                    name: .gameResultReceived,
                    object: result
                )
                
                // Clear the single-result key so we don't re-ingest on subsequent lifecycle events
                clearLatestResult()
                logger.debug("🧹 Cleared single-result App Group key after posting")
            }
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
    static let joinGroupRequested = Notification.Name("joinGroupRequested")
    static let streakUpdated = Notification.Name("streakUpdated")
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
}
