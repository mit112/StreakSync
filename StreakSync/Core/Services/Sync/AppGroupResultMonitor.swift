//
//  AppGroupResultMonitor.swift
//  StreakSync
//
//  Monitors App Group for new game results
//

import Foundation
import OSLog

@MainActor
final class AppGroupResultMonitor {
    // MARK: - Properties
    private let dataManager: AppGroupDataManager
    private let logger = Logger(subsystem: "com.streaksync.app", category: "ResultMonitor")
    
    @Published var isMonitoring = false
    private var monitoringTask: Task<Void, Never>?
    private var lastKnownResultId: UUID?
    
    // MARK: - Initialization
    init(dataManager: AppGroupDataManager) {
        self.dataManager = dataManager
    }
    
    // MARK: - Monitoring Control
    func startMonitoring(onNewResult: @escaping () async -> Void) {
        // Event-driven via Darwin notifications and lifecycle; no polling needed
        guard !isMonitoring else { return }
        logger.info("🔄 Enabling event-driven monitoring (no polling)")
        isMonitoring = true
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    func stopMonitoring() {
        logger.info("⏹️ Stopping continuous monitoring")
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    // MARK: - Result Checking
    func checkForNewResult() async -> Bool {
        do {
            // Check for queued results first
            let queuedResults = try await dataManager.loadGameResultQueue()
            
            if !queuedResults.isEmpty {
                logger.info("✅ Found \(queuedResults.count) queued results")
                return true
            }
            
            // Fallback to single result for backward compatibility
            guard let result = try await dataManager.loadGameResult(forKey: "latestGameResult") else {
                return false
            }
            
            // Check if it's different from last known
            if let lastKnown = lastKnownResultId, lastKnown == result.id {
                return false // Same result
            }
            
            // New result detected
            lastKnownResultId = result.id
            logger.info("✅ New result detected: \(result.gameName)")
            return true
            
        } catch {
            logger.error("Error checking for result: \(error)")
            return false
        }
    }
    
    // MARK: - Queue Processing
    func processQueuedResults() async -> [GameResult] {
        do {
            let queuedResults = try await dataManager.loadGameResultQueue()
            
            if !queuedResults.isEmpty {
                // Clear the queue after processing
                dataManager.clearGameResultQueue()
                logger.info("✅ Processed and cleared \(queuedResults.count) queued results")
            }
            
            return queuedResults
            
        } catch {
            logger.error("Error processing queued results: \(error)")
            return []
        }
    }
    
    // MARK: - Cleanup
    deinit {
        // Cancel the task - this is safe from deinit
        monitoringTask?.cancel()
    }
}
