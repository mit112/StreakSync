//
//  AppGroupDataManager.swift
//  StreakSync
//
//  Manages reading and writing data to App Group shared storage
//

import Foundation
import OSLog

@MainActor
final class AppGroupDataManager {
    // MARK: - Properties
    private let appGroupID: String
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AppGroupDataManager")
    
    // MARK: - Decoder/Encoder
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    // MARK: - Initialization
    init(appGroupID: String = "group.com.mitsheth.StreakSync") {
        self.appGroupID = appGroupID
    }
    
    // MARK: - UserDefaults Access
    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    // MARK: - Data Operations
    func hasData(forKey key: String) -> Bool {
        userDefaults?.data(forKey: key) != nil
    }
    
    func loadGameResult(forKey key: String) async throws -> GameResult? {
        guard let userDefaults = userDefaults else {
            throw AppError.sync(.appGroupCommunicationFailed)
        }
        
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            return try decoder.decode(GameResult.self, from: data)
        } catch {
 logger.error("Failed to decode game result: \(error)")
            // Provide the required string argument describing what data was corrupted
            throw AppError.persistence(.dataCorrupted(dataType: "GameResult"))
        }
    }
    
    func saveGameResult(_ result: GameResult, forKey key: String) async throws {
        guard let userDefaults = userDefaults else {
            throw AppError.sync(.appGroupCommunicationFailed)
        }
        
        let data = try encoder.encode(result)
        userDefaults.set(data, forKey: key)
        userDefaults.synchronize()
        
 logger.debug("Saved game result to key: \(key)")
    }
    
    func removeData(forKey key: String) {
        userDefaults?.removeObject(forKey: key)
        userDefaults?.synchronize()
 logger.debug("Removed data for key: \(key)")
    }
    
    /// Loads queued results and returns both results and the keys that were loaded.
    /// Callers should pass the returned keys to `clearProcessedKeys(_:)` after
    /// successful processing to avoid the cross-process TOCTOU race where the
    /// Share Extension appends a new key between our read and clear.
    func loadGameResultQueue() async -> (results: [GameResult], processedKeys: [String]) {
        guard let userDefaults = userDefaults else {
            return ([], [])
        }

        guard let keysData = userDefaults.data(forKey: "gameResultKeys") else {
            return ([], [])
        }

        guard let resultKeys = (try? JSONSerialization.jsonObject(with: keysData)) as? [String] else {
            // Corrupted keys data — clear it to prevent permanent queue blockage
            logger.error("Corrupted gameResultKeys data — clearing to recover")
            userDefaults.removeObject(forKey: "gameResultKeys")
            userDefaults.synchronize()
            return ([], [])
        }

        // Load each result by its key
        var results: [GameResult] = []
        for key in resultKeys {
            if let resultData = userDefaults.data(forKey: key) {
                do {
                    let result = try decoder.decode(GameResult.self, from: resultData)
                    results.append(result)
                } catch {
                    logger.error("Failed to decode game result for key \(key): \(error)")
                    // Continue processing other results — corrupted individual
                    // entries are skipped but their keys are still cleared below.
                }
            }
        }

        logger.info("Loaded \(results.count) results from queue (\(resultKeys.count) keys)")
        return (results, resultKeys)
    }

    /// Removes only the specific keys that were loaded, then rewrites the keys
    /// list minus the processed entries. This avoids a TOCTOU race: if the Share
    /// Extension appends a new key between our load and clear, it is preserved.
    func clearProcessedKeys(_ processedKeys: [String]) {
        guard let userDefaults = userDefaults else { return }

        let processedSet = Set(processedKeys)

        // Remove individual result entries
        for key in processedKeys {
            userDefaults.removeObject(forKey: key)
        }

        // Re-read the current keys list (may have new entries from Share Extension)
        if let keysData = userDefaults.data(forKey: "gameResultKeys"),
           let currentKeys = (try? JSONSerialization.jsonObject(with: keysData)) as? [String] {
            let remaining = currentKeys.filter { !processedSet.contains($0) }
            if remaining.isEmpty {
                userDefaults.removeObject(forKey: "gameResultKeys")
            } else {
                if let data = try? JSONSerialization.data(withJSONObject: remaining) {
                    userDefaults.set(data, forKey: "gameResultKeys")
                }
            }
        } else {
            userDefaults.removeObject(forKey: "gameResultKeys")
        }

        userDefaults.synchronize()
        logger.info("Cleared \(processedKeys.count) processed keys from queue")
    }
    
    // MARK: - Legacy Queue (Array) Support
    /// Loads legacy queued results saved as a single array under `AppConstants.AppGroup.queuedResultsKey`
    /// Returns nil if not present or decoding fails.
    func loadLegacyQueuedResultsArray() -> [GameResult]? {
        guard let userDefaults = userDefaults else { return nil }
        guard let data = userDefaults.data(forKey: AppConstants.AppGroup.queuedResultsKey) else {
            return nil
        }
        
        do {
            let results = try decoder.decode([GameResult].self, from: data)
            if !results.isEmpty {
 logger.info("Loaded \(results.count) legacy queued results (array)")
            }
            return results
        } catch {
 logger.error("Failed to decode legacy queued results array: \(error)")
            return nil
        }
    }
    
    /// Clears the legacy queued results array saved under `AppConstants.AppGroup.queuedResultsKey`
    func clearLegacyQueuedResultsArray() {
        guard let userDefaults = userDefaults else { return }
        userDefaults.removeObject(forKey: AppConstants.AppGroup.queuedResultsKey)
        userDefaults.synchronize()
 logger.info("Cleared legacy queued results array")
    }
    
    func clearAll() {
        guard let userDefaults = userDefaults else { return }

        // Clean up dynamic gameResult_<uuid> keys before removing the index
        if let keysData = userDefaults.data(forKey: "gameResultKeys"),
           let resultKeys = (try? JSONSerialization.jsonObject(with: keysData)) as? [String] {
            for key in resultKeys {
                userDefaults.removeObject(forKey: key)
            }
        }

        let staticKeys = ["latestGameResult", "queuedResults", "gameResultQueue", "gameResultKeys"]
        for key in staticKeys {
            userDefaults.removeObject(forKey: key)
        }
        userDefaults.synchronize()

        logger.info("Cleared all App Group data")
    }
}
