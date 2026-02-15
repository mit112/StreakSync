//
//  PersistenceService.swift - MIGRATED TO APPERROR
//  StreakSync
//
//  UPDATED: Using centralized AppError instead of local PersistenceError
//

import Foundation
import OSLog

// MARK: - Persistence Service Protocol
protocol PersistenceServiceProtocol {
    func save<T: Codable>(_ object: T, forKey key: String) throws
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T?
    func remove(forKey key: String)
    func clearAll()
}

// MARK: - UserDefaults Persistence Service (Using AppError)
// Game results use file-based storage (not UserDefaults) to avoid loading
// large datasets into memory at launch. Streaks and achievements remain in
// UserDefaults since they're small (<10KB each).
final class UserDefaultsPersistenceService: PersistenceServiceProtocol {
    private let logger = Logger(subsystem: "com.streaksync.app", category: "PersistenceService")
    private let userDefaults: UserDefaults
    
    // CRITICAL: Configured JSON encoder/decoder with proper date strategy
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    struct Keys {
        static let gameResults = "streaksync_game_results"
        static let achievements = "streaksync_achievements"
        static let streaks = "streaksync_streaks"
    }
    
    /// File URL for game results (Documents directory, backed up by iCloud)
    private var gameResultsFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("game_results.json")
    }
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func save<T: Codable>(_ object: T, forKey key: String) throws {
        // Route game results to file storage
        if key == Keys.gameResults {
            try saveToFile(object, url: gameResultsFileURL)
            return
        }
        
 logger.debug("Saving data for key: \(key)")
        do {
            let data = try encoder.encode(object)
            userDefaults.set(data, forKey: key)
 logger.debug("Successfully saved data for key: \(key) (\(data.count) bytes)")
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.persistence(.encodingFailed(underlying: error))
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        // Route game results to file storage (with UserDefaults migration)
        if key == Keys.gameResults {
            return loadFromFile(type, url: gameResultsFileURL) ?? migrateGameResultsFromUserDefaults(type)
        }
        
 logger.debug("Loading data for key: \(key)")
        guard let data = userDefaults.data(forKey: key) else {
 logger.debug("No data found for key: \(key)")
            return nil
        }
        do {
            let object = try decoder.decode(type, from: data)
 logger.debug("Successfully loaded data for key: \(key)")
            return object
        } catch {
 logger.error("Failed to decode data for key: \(key) - \(error.localizedDescription)")
            return nil
        }
    }
    
    func remove(forKey key: String) {
        if key == Keys.gameResults {
            try? FileManager.default.removeItem(at: gameResultsFileURL)
        }
        userDefaults.removeObject(forKey: key)
 logger.info("Removed data for key: \(key)")
    }
    
    func clearAll() {
        let keys = [Keys.gameResults, Keys.achievements, Keys.streaks]
        for key in keys {
            remove(forKey: key)
        }
 logger.info("Cleared all persistence data")
    }
    
    // MARK: - File-Based Storage (for large datasets like game results)
    
    private func saveToFile<T: Codable>(_ object: T, url: URL) throws {
        do {
            let data = try encoder.encode(object)
            try data.write(to: url, options: .atomic)
 logger.debug("Saved \(data.count) bytes to \(url.lastPathComponent)")
        } catch {
 logger.error("Failed to save to file \(url.lastPathComponent): \(error.localizedDescription)")
            throw AppError.persistence(.saveFailed(dataType: url.lastPathComponent, underlying: error))
        }
    }
    
    private func loadFromFile<T: Codable>(_ type: T.Type, url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let object = try decoder.decode(type, from: data)
 logger.debug("Loaded \(data.count) bytes from \(url.lastPathComponent)")
            return object
        } catch {
 logger.error("Failed to load from file \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// One-time migration: moves game results from UserDefaults to file storage.
    /// Returns the migrated data (or nil if nothing to migrate).
    private func migrateGameResultsFromUserDefaults<T: Codable>(_ type: T.Type) -> T? {
        guard let data = userDefaults.data(forKey: Keys.gameResults) else { return nil }
        do {
            let object = try decoder.decode(type, from: data)
            // Write to file
            let encoded = try encoder.encode(object)
            try encoded.write(to: gameResultsFileURL, options: .atomic)
            // Remove from UserDefaults
            userDefaults.removeObject(forKey: Keys.gameResults)
 logger.info("Migrated game results from UserDefaults to file storage (\(encoded.count) bytes)")
            return object
        } catch {
 logger.error("Game results migration failed: \(error.localizedDescription)")
            // Fall through — data stays in UserDefaults until next successful migration
            return try? decoder.decode(type, from: data)
        }
    }
}

// MARK: - App Group Persistence Service (Using AppError)
final class AppGroupPersistenceService {
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AppGroupPersistence")
    private let appGroupID: String
    
    // CRITICAL: Configured JSON encoder/decoder with proper date strategy
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    init(appGroupID: String) {
        self.appGroupID = appGroupID
    }
    
    func save<T: Codable>(_ object: T, forKey key: String) throws {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            throw AppError.sync(.appGroupCommunicationFailed)
        }
        
 logger.debug("Saving to App Group for key: \(key)")
        
        do {
            let data = try encoder.encode(object)
            userDefaults.set(data, forKey: key)
            // synchronize() is unnecessary on modern iOS; let the system flush
            
 logger.debug("Successfully saved to App Group for key: \(key)")
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.persistence(.encodingFailed(underlying: error))
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
 logger.error("Invalid App Group ID: \(self.appGroupID)")
            return nil
        }
        
        guard let data = userDefaults.data(forKey: key) else {
 logger.debug("No App Group data found for key: \(key)")
            return nil
        }
        
        do {
            let object = try decoder.decode(type, from: data)
 logger.debug("Successfully loaded from App Group for key: \(key)")
            
            // CRITICAL: Log date verification for GameResult
            if let result = object as? GameResult {
 logger.debug("LOADED APP GROUP RESULT DATE: \(result.date)")
 logger.debug("YEAR VERIFICATION: \(Calendar.current.component(.year, from: result.date))")
            }
            
            return object
        } catch {
 logger.error("Failed to decode App Group data for key: \(key) - \(error.localizedDescription)")
            return nil
        }
    }
    
    func remove(forKey key: String) {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else { return }
        
        userDefaults.removeObject(forKey: key)
        // synchronize() is unnecessary on modern iOS; let the system flush
 logger.info("Removed App Group data for key: \(key)")
    }
}
