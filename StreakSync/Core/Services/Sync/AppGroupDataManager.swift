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
    
    func clearAll() {
        guard let userDefaults = userDefaults else { return }
        
        let keys = ["latestGameResult", "queuedResults"] // Add all known keys
        keys.forEach { key in
            userDefaults.removeObject(forKey: key)
        }
        userDefaults.synchronize()
        
        logger.info("Cleared all App Group data")
    }
}
