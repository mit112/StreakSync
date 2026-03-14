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
 logger.info("Enabling event-driven monitoring (no polling)")
        isMonitoring = true
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    func stopMonitoring() {
 logger.debug("Stopping continuous monitoring")
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    // MARK: - Result Checking
    func checkForNewResult() async -> Bool {
        // Check for queued results first
        let queue = await dataManager.loadGameResultQueue()
        if !queue.results.isEmpty {
            logger.info("Found \(queue.results.count) queued results")
            return true
        }

        // Legacy array-based queue fallback
        if let legacy = dataManager.loadLegacyQueuedResultsArray(), !legacy.isEmpty {
            logger.info("Found \(legacy.count) legacy queued results (array)")
            return true
        }

        // Fallback to single result for backward compatibility
        guard let result = try? await dataManager.loadGameResult(forKey: "latestGameResult") else {
            return false
        }

        // Check if it's different from last known
        if let lastKnown = lastKnownResultId, lastKnown == result.id {
            return false
        }

        lastKnownResultId = result.id
        logger.info("New result detected: \(result.gameName)")
        return true
    }

    // MARK: - Queue Processing
    func processQueuedResults() async -> [GameResult] {
        // Process key-based queue (only clear the specific keys we loaded)
        let queue = await dataManager.loadGameResultQueue()
        if !queue.results.isEmpty {
            dataManager.clearProcessedKeys(queue.processedKeys)
            logger.info("Processed and cleared \(queue.results.count) queued results")
            return queue.results
        }

        // Fallback: process legacy array-based queue
        if let legacy = dataManager.loadLegacyQueuedResultsArray(), !legacy.isEmpty {
            dataManager.clearLegacyQueuedResultsArray()
            logger.info("Processed and cleared \(legacy.count) legacy queued results (array)")
            return legacy
        }

        return []
    }
    
    // MARK: - Cleanup
    deinit {
        // Cancel the task - this is safe from deinit
        monitoringTask?.cancel()
    }
}
