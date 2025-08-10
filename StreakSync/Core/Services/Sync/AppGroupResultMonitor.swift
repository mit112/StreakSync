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
        guard !isMonitoring else { return }
        
        logger.info("🔄 Starting continuous monitoring for new results")
        isMonitoring = true
        
        monitoringTask?.cancel()
        monitoringTask = Task { @MainActor in
            while !Task.isCancelled && isMonitoring {
                if await checkForNewResult() {
                    await onNewResult()
                }
                
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
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
    
    // MARK: - Cleanup
    deinit {
        // Cancel the task - this is safe from deinit
        monitoringTask?.cancel()
    }
}
