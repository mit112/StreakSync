//
//  AppGroupResultMonitor.swift
//  StreakSync
//
//  Reads and acknowledges the App Group result queue
//

import Foundation
import OSLog

@MainActor
final class AppGroupResultMonitor {
    // MARK: - Properties
    private let dataManager: AppGroupDataManager
    private let logger = Logger(subsystem: "com.streaksync.app", category: "ResultMonitor")

    // MARK: - Initialization
    init(dataManager: AppGroupDataManager) {
        self.dataManager = dataManager
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
}
