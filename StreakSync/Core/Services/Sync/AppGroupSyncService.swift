//
//  AppGroupSyncService.swift
//  StreakSync
//
//  Created by MiT on 7/28/25.
//
//
//
//  AppGroupSyncCoordinator.swift
//  StreakSync
//
//  Coordinates loading and duplicate detection for Share Extension results
//

import Foundation
import OSLog

final class AppGroupSyncCoordinator {
    private let appGroupPersistence: AppGroupPersistenceService
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AppGroupSyncCoordinator")
    
    // MARK: - Duplicate Detection Cache
    private var processedResultHashes: Set<String> = []
    private var lastProcessedTimestamp: Date?
    
    init(appGroupID: String = AppConstants.AppGroup.identifier) {
        self.appGroupPersistence = AppGroupPersistenceService(appGroupID: appGroupID)
    }
    
    // MARK: - Load Pending Results
    func loadPendingResults() async throws -> [GameResult] {
        logger.info("📥 Loading pending results from App Group")
        
        var results: [GameResult] = []
        
        // Load latest result first
        if let latestResult = loadLatestResult() {
            if !isDuplicate(latestResult) {
                results.append(latestResult)
                markAsProcessed(latestResult)
                logger.info("✅ Loaded latest result: \(latestResult.gameName) #\(latestResult.parsedData["puzzleNumber"] ?? "")")
            } else {
                logger.info("⚠️ Skipped duplicate latest result")
            }
            
            // Always clear latest result after checking
            clearLatestResult()
        }
        
        // Load queued results
        if let queuedResults = loadQueuedResults() {
            logger.info("📦 Found \(queuedResults.count) queued results")
            
            for result in queuedResults {
                if !isDuplicate(result) {
                    results.append(result)
                    markAsProcessed(result)
                } else {
                    logger.debug("Skipped duplicate queued result: \(result.gameName)")
                }
            }
            
            // Clear queue after processing
            if !queuedResults.isEmpty {
                clearQueuedResults()
            }
        }
        
        logger.info("✅ Loaded \(results.count) new results total")
        return results
    }
    
    // MARK: - Individual Loading Methods
    private func loadLatestResult() -> GameResult? {
        appGroupPersistence.load(
            GameResult.self,
            forKey: AppConstants.AppGroup.latestResultKey
        )
    }
    
    private func loadQueuedResults() -> [GameResult]? {
        appGroupPersistence.load(
            [GameResult].self,
            forKey: AppConstants.AppGroup.queuedResultsKey
        )
    }
    
    // MARK: - Cleanup Methods
    private func clearLatestResult() {
        appGroupPersistence.remove(forKey: AppConstants.AppGroup.latestResultKey)
        logger.debug("🗑️ Cleared latest result from App Group")
    }
    
    private func clearQueuedResults() {
        appGroupPersistence.remove(forKey: AppConstants.AppGroup.queuedResultsKey)
        logger.debug("🗑️ Cleared queued results from App Group")
    }
    
    // MARK: - Duplicate Detection
    func isDuplicate(_ result: GameResult) -> Bool {
        let hash = generateHash(for: result)
        
        // Check hash cache
        if processedResultHashes.contains(hash) {
            logger.debug("Duplicate by hash: \(hash)")
            return true
        }
        
        // Check timestamp proximity
        if let lastTimestamp = lastProcessedTimestamp {
            let timeDiff = abs(result.date.timeIntervalSince(lastTimestamp))
            if timeDiff < AppConstants.Storage.duplicateTimeWindow &&
               result.gameName == result.gameName { // Same game
                logger.debug("Duplicate by timestamp proximity: \(timeDiff)s")
                return true
            }
        }
        
        return false
    }
    
    private func generateHash(for result: GameResult) -> String {
        // Clean puzzle number for consistent hashing
        let puzzleNumber = (result.parsedData["puzzleNumber"] ?? "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Include score in hash to differentiate retries
        let scoreComponent = result.score.map(String.init) ?? "X"
        
        return "\(result.gameName)-\(puzzleNumber)-\(scoreComponent)"
    }
    
    private func markAsProcessed(_ result: GameResult) {
        let hash = generateHash(for: result)
        processedResultHashes.insert(hash)
        lastProcessedTimestamp = result.date
        
        // Maintain cache size
        if processedResultHashes.count > AppConstants.Storage.maxCacheSize {
            processedResultHashes.removeAll()
            logger.debug("Reset duplicate detection cache")
        }
    }
    
    // MARK: - Status Check
    func hasNewResults() -> Bool {
        let hasLatest = loadLatestResult() != nil
        let hasQueued = !(loadQueuedResults()?.isEmpty ?? true)
        
        return hasLatest || hasQueued
    }
}
