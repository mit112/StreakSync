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
final class UserDefaultsPersistenceService: PersistenceServiceProtocol {
    private let logger = Logger(subsystem: "com.streaksync.app", category: "PersistenceService")
    private let userDefaults: UserDefaults
    
    // CRITICAL: Configured JSON encoder/decoder with proper date strategy
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
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
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func save<T: Codable>(_ object: T, forKey key: String) throws {
        logger.info("💾 Saving data for key: \(key)")
        
        do {
            let data = try encoder.encode(object)
            userDefaults.set(data, forKey: key)
            // synchronize() is unnecessary on modern iOS; let the system flush
            
            // CRITICAL: Verify the save worked immediately
            if let _ = userDefaults.data(forKey: key) {
                logger.info("✅ Successfully saved data for key: \(key) (\(data.count) bytes)")
            } else {
                logger.error("❌ Failed to verify save for key: \(key)")
                throw AppError.persistence(.saveFailed(dataType: key, underlying: nil))
            }
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.persistence(.encodingFailed(underlying: error))
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        logger.info("📖 Loading data for key: \(key)")
        
        guard let data = userDefaults.data(forKey: key) else {
            logger.debug("No data found for key: \(key)")
            return nil
        }
        
        do {
            let object = try decoder.decode(type, from: data)
            logger.info("✅ Successfully loaded data for key: \(key)")
            
            // CRITICAL: Log date verification for GameResult arrays
            if let results = object as? [GameResult], let firstResult = results.first {
                logger.info("🕐 LOADED RESULT DATE: \(firstResult.date)")
                logger.info("📅 YEAR VERIFICATION: \(Calendar.current.component(.year, from: firstResult.date))")
            }
            
            return object
        } catch {
            logger.error("❌ Failed to decode data for key: \(key) - \(error.localizedDescription)")
            return nil
        }
    }
    
    func remove(forKey key: String) {
        userDefaults.removeObject(forKey: key)
        // synchronize() is unnecessary on modern iOS; let the system flush
        logger.info("🗑️ Removed data for key: \(key)")
    }
    
    func clearAll() {
        let keys = [Keys.gameResults, Keys.achievements, Keys.streaks]
        for key in keys {
            remove(forKey: key)
        }
        logger.info("🗑️ Cleared all persistence data")
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
        
        logger.info("💾 Saving to App Group for key: \(key)")
        
        do {
            let data = try encoder.encode(object)
            userDefaults.set(data, forKey: key)
            // synchronize() is unnecessary on modern iOS; let the system flush
            
            logger.info("✅ Successfully saved to App Group for key: \(key)")
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.persistence(.encodingFailed(underlying: error))
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            logger.error("❌ Invalid App Group ID: \(self.appGroupID)")
            return nil
        }
        
        guard let data = userDefaults.data(forKey: key) else {
            logger.debug("No App Group data found for key: \(key)")
            return nil
        }
        
        do {
            let object = try decoder.decode(type, from: data)
            logger.info("✅ Successfully loaded from App Group for key: \(key)")
            
            // CRITICAL: Log date verification for GameResult
            if let result = object as? GameResult {
                logger.info("🕐 LOADED APP GROUP RESULT DATE: \(result.date)")
                logger.info("📅 YEAR VERIFICATION: \(Calendar.current.component(.year, from: result.date))")
            }
            
            return object
        } catch {
            logger.error("❌ Failed to decode App Group data for key: \(key) - \(error.localizedDescription)")
            return nil
        }
    }
    
    func remove(forKey key: String) {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else { return }
        
        userDefaults.removeObject(forKey: key)
        // synchronize() is unnecessary on modern iOS; let the system flush
        logger.info("🗑️ Removed App Group data for key: \(key)")
    }
}
