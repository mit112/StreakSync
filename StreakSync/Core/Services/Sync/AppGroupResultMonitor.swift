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

    /// Loads queued results WITHOUT clearing them. Each result stays in the queue
    /// until `acknowledgeProcessedResult(id:)` is called after the main app
    /// confirms a durable local write, so a jetsam/crash mid-ingest can't lose a
    /// result that was already removed from the queue (T1-2).
    func loadQueuedResults() async -> [GameResult] {
        // Key-based queue — results remain queued until individually acknowledged.
        let queue = await dataManager.loadGameResultQueue()
        if !queue.results.isEmpty {
            logger.info("Loaded \(queue.results.count) queued results (awaiting durable-write ack)")
            return queue.results
        }

        // Legacy array-based queue: a near-dead compatibility path for data that
        // predates the per-key queue. Cleared on load — new writes never use it.
        if let legacy = dataManager.loadLegacyQueuedResultsArray(), !legacy.isEmpty {
            dataManager.clearLegacyQueuedResultsArray()
            logger.info("Processed and cleared \(legacy.count) legacy queued results (array)")
            return legacy
        }

        return []
    }

    /// Removes a single result's queue entry after the main app confirms a durable
    /// local write. TOCTOU-safe: only the acknowledged key is removed, so results
    /// the Share Extension appended in the meantime are preserved.
    func acknowledgeProcessedResult(id: UUID) {
        dataManager.clearProcessedKeys(["gameResult_\(id.uuidString)"])
    }
    
    // MARK: - Cleanup
    deinit {
        // Cancel the task - this is safe from deinit
        monitoringTask?.cancel()
    }
}
