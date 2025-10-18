//
//  PersistenceService.swift - MIGRATED TO APPERROR
//  StreakSync
//
//  UPDATED: Using centralized AppError instead of local PersistenceError
//

/*
 * PERSISTENCESERVICE - DATA STORAGE AND RETRIEVAL SYSTEM
 * 
 * WHAT THIS FILE DOES:
 * This file is the "filing cabinet" of the app. It handles saving and loading all the important
 * data (game results, achievements, streaks) so that when users close and reopen the app, their
 * progress is preserved. Think of it as the "memory keeper" that makes sure nothing gets lost
 * when the app is closed or the phone is restarted.
 * 
 * WHY IT EXISTS:
 * Apps need to remember data between sessions. Without this service, every time users opened
 * the app, they would lose all their game results, streaks, and achievements. This service
 * uses UserDefaults (iOS's built-in storage system) to save data as JSON, making it easy
 * to store complex data structures and retrieve them later.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This is how the app remembers all user data between sessions
 * - Handles saving and loading of game results, achievements, and streaks
 * - Uses JSON encoding/decoding for complex data structures
 * - Provides error handling for storage failures
 * - Includes logging for debugging storage issues
 * - Supports App Groups for sharing data with extensions
 * - Validates data integrity after saving and loading
 * 
 * WHAT IT REFERENCES:
 * - UserDefaults: iOS's built-in storage system
 * - JSONEncoder/JSONDecoder: For converting data to/from JSON format
 * - AppError: Centralized error handling system
 * - Logger: For debugging and monitoring storage operations
 * - Codable: Protocol for data that can be saved/loaded
 * 
 * WHAT REFERENCES IT:
 * - AppState: Uses this to save and load all app data
 * - AppContainer: Creates and manages the PersistenceService
 * - Share Extension: Uses this to save shared game results
 * - All data models: Must conform to Codable to be saved
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. STORAGE STRATEGY IMPROVEMENTS:
 *    - The current approach uses UserDefaults for everything - could be more sophisticated
 *    - Consider using Core Data for complex relationships
 *    - Add support for different storage backends (CloudKit, local files)
 *    - Implement data migration strategies for schema changes
 * 
 * 2. ERROR HANDLING ENHANCEMENTS:
 *    - The current error handling is good but could be more specific
 *    - Add retry mechanisms for failed operations
 *    - Implement data corruption detection and recovery
 *    - Add user-friendly error messages for storage failures
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation loads all data at once - could be optimized
 *    - Consider lazy loading for large datasets
 *    - Add data compression for better storage efficiency
 *    - Implement background saving for better user experience
 * 
 * 4. DATA VALIDATION:
 *    - The current validation is basic - could be more comprehensive
 *    - Add schema validation for saved data
 *    - Implement data integrity checks
 *    - Add versioning support for data format changes
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for all storage operations
 *    - Test error handling and edge cases
 *    - Add integration tests with real data
 *    - Test data migration scenarios
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for each storage method
 *    - Document the data format and schema
 *    - Add examples of how to use each method
 *    - Create data flow diagrams
 * 
 * 7. SECURITY IMPROVEMENTS:
 *    - Add data encryption for sensitive information
 *    - Implement access controls for different data types
 *    - Add audit logging for data access
 *    - Consider adding data backup and restore features
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new data types
 *    - Add support for custom storage backends
 *    - Implement plugin system for storage providers
 *    - Add support for data synchronization
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Persistence: Saving data so it survives app restarts
 * - UserDefaults: iOS's built-in storage system for app preferences and data
 * - JSON: A text format for storing structured data
 * - Codable: A Swift protocol that makes data easy to save and load
 * - Error handling: What to do when saving or loading fails
 * - Logging: Recording what the app is doing for debugging purposes
 * - Data validation: Making sure saved data is correct and complete
 * - App Groups: Shared storage between the main app and extensions
 */

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
