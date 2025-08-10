//
//  AppError.swift
//  StreakSync
//
//  Comprehensive error handling system with localization and recovery
//

import Foundation
import SwiftUI

// MARK: - App Error
enum AppError: LocalizedError {
    
    // MARK: Share Extension Errors
    case shareExtension(ShareExtensionError)
    
    // MARK: Game Parsing Errors
    case parsing(ParsingError)
    
    // MARK: Persistence Errors
    case persistence(PersistenceError)
    
    // MARK: Sync/Communication Errors
    case sync(SyncError)
    
    // MARK: UI/State Errors
    case ui(UIError)
    
    // MARK: - Nested Error Types
    
    enum ShareExtensionError {
        case noContent
        case invalidContentType(String)
        case processingTimeout
        case appGroupAccessFailed
        case saveFailed(underlying: Error?)
        case notificationFailed
    }
    
    enum ParsingError {
        case unknownGameFormat(text: String)
        case invalidScoreFormat(game: String, score: String)
        case missingPuzzleNumber(game: String)
        case malformedGameData(game: String, reason: String)
        case unsupportedGame(detectedName: String)
        case dateParsingFailed
    }
    
    enum PersistenceError {
        case saveFailed(dataType: String, underlying: Error?)
        case loadFailed(dataType: String, underlying: Error?)
        case dataCorrupted(dataType: String)
        case migrationFailed(from: String, to: String)
        case storageFull
        case keyNotFound(key: String)
        case encodingFailed(underlying: Error)
        case decodingFailed(underlying: Error)
    }
    
    enum SyncError {
        case appGroupCommunicationFailed
        case notificationPostFailed
        case urlSchemeInvalid(url: String)
        case darwinNotificationFailed
        case resultAlreadyProcessed
        case syncTimeout
    }
    
    enum UIError {
        case navigationFailed(destination: String)
        case missingRequiredData(viewName: String)
        case sheetPresentationFailed
        case stateInconsistency(description: String)
        case viewModelNotInitialized
    }
    
    // MARK: - LocalizedError Implementation
    
    var errorDescription: String? {
        switch self {
        case .shareExtension(let error):
            return error.localizedDescription
        case .parsing(let error):
            return error.localizedDescription
        case .persistence(let error):
            return error.localizedDescription
        case .sync(let error):
            return error.localizedDescription
        case .ui(let error):
            return error.localizedDescription
        }
    }
    
    var failureReason: String? {
        switch self {
        case .shareExtension(let error):
            return error.failureReason
        case .parsing(let error):
            return error.failureReason
        case .persistence(let error):
            return error.failureReason
        case .sync(let error):
            return error.failureReason
        case .ui(let error):
            return error.failureReason
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .shareExtension(let error):
            return error.recoverySuggestion
        case .parsing(let error):
            return error.recoverySuggestion
        case .persistence(let error):
            return error.recoverySuggestion
        case .sync(let error):
            return error.recoverySuggestion
        case .ui(let error):
            return error.recoverySuggestion
        }
    }
    
    var helpAnchor: String? {
        // This could link to specific help documentation
        switch self {
        case .shareExtension:
            return "share-extension-errors"
        case .parsing:
            return "game-parsing-errors"
        case .persistence:
            return "data-storage-errors"
        case .sync:
            return "sync-errors"
        case .ui:
            return "interface-errors"
        }
    }
}

// MARK: - Share Extension Error Details
extension AppError.ShareExtensionError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .noContent:
            return NSLocalizedString("error.share.no_content", comment: "No content to share")
        case .invalidContentType(let type):
            return String(format: NSLocalizedString("error.share.invalid_type", comment: "Invalid content type: %@"), type)
        case .processingTimeout:
            return NSLocalizedString("error.share.timeout", comment: "Processing took too long")
        case .appGroupAccessFailed:
            return NSLocalizedString("error.share.app_group", comment: "Cannot access shared data")
        case .saveFailed:
            return NSLocalizedString("error.share.save_failed", comment: "Failed to save game result")
        case .notificationFailed:
            return NSLocalizedString("error.share.notification_failed", comment: "Failed to notify main app")
        }
    }
    
    var failureReason: String? {
        switch self {
        case .noContent:
            return NSLocalizedString("error.share.no_content.reason", comment: "The shared content was empty")
        case .invalidContentType(let type):
            return String(format: NSLocalizedString("error.share.invalid_type.reason", comment: "Expected text content, received %@"), type)
        case .processingTimeout:
            return NSLocalizedString("error.share.timeout.reason", comment: "The share extension took too long to process")
        case .appGroupAccessFailed:
            return NSLocalizedString("error.share.app_group.reason", comment: "App group configuration may be incorrect")
        case .saveFailed(let underlying):
            if let error = underlying {
                return error.localizedDescription
            }
            return NSLocalizedString("error.share.save_failed.reason", comment: "Data could not be written to shared storage")
        case .notificationFailed:
            return NSLocalizedString("error.share.notification_failed.reason", comment: "Inter-process communication failed")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noContent:
            return NSLocalizedString("error.share.no_content.recovery", comment: "Try sharing again with game results selected")
        case .invalidContentType:
            return NSLocalizedString("error.share.invalid_type.recovery", comment: "Only text-based game results are supported")
        case .processingTimeout:
            return NSLocalizedString("error.share.timeout.recovery", comment: "Try sharing again or use Manual Entry")
        case .appGroupAccessFailed:
            return NSLocalizedString("error.share.app_group.recovery", comment: "Try reinstalling the app")
        case .saveFailed:
            return NSLocalizedString("error.share.save_failed.recovery", comment: "Check available storage and try again")
        case .notificationFailed:
            return NSLocalizedString("error.share.notification_failed.recovery", comment: "Open StreakSync to sync manually")
        }
    }
}

// MARK: - Parsing Error Details
extension AppError.ParsingError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .unknownGameFormat:
            return NSLocalizedString("error.parsing.unknown_format", comment: "Unknown game format")
        case .invalidScoreFormat(let game, _):
            return String(format: NSLocalizedString("error.parsing.invalid_score", comment: "Invalid %@ score format"), game)
        case .missingPuzzleNumber(let game):
            return String(format: NSLocalizedString("error.parsing.missing_puzzle", comment: "%@ puzzle number not found"), game)
        case .malformedGameData(let game, _):
            return String(format: NSLocalizedString("error.parsing.malformed_data", comment: "Invalid %@ game data"), game)
        case .unsupportedGame(let name):
            return String(format: NSLocalizedString("error.parsing.unsupported_game", comment: "%@ is not yet supported"), name)
        case .dateParsingFailed:
            return NSLocalizedString("error.parsing.date_failed", comment: "Could not determine game date")
        }
    }
    
    var failureReason: String? {
        switch self {
        case .unknownGameFormat(let text):
            let preview = String(text.prefix(50))
            return String(format: NSLocalizedString("error.parsing.unknown_format.reason", comment: "Could not identify game in: %@..."), preview)
        case .invalidScoreFormat(_, let score):
            return String(format: NSLocalizedString("error.parsing.invalid_score.reason", comment: "Score '%@' is not valid"), score)
        case .missingPuzzleNumber:
            return NSLocalizedString("error.parsing.missing_puzzle.reason", comment: "Puzzle number is required for tracking")
        case .malformedGameData(_, let reason):
            return reason
        case .unsupportedGame:
            return NSLocalizedString("error.parsing.unsupported_game.reason", comment: "This game hasn't been added to StreakSync yet")
        case .dateParsingFailed:
            return NSLocalizedString("error.parsing.date_failed.reason", comment: "Game date could not be extracted from results")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .unknownGameFormat:
            return NSLocalizedString("error.parsing.unknown_format.recovery", comment: "Make sure to share the complete game result")
        case .invalidScoreFormat:
            return NSLocalizedString("error.parsing.invalid_score.recovery", comment: "Use Manual Entry to add this result")
        case .missingPuzzleNumber:
            return NSLocalizedString("error.parsing.missing_puzzle.recovery", comment: "Include the puzzle number when sharing")
        case .malformedGameData:
            return NSLocalizedString("error.parsing.malformed_data.recovery", comment: "Try copying and sharing the result again")
        case .unsupportedGame:
            return NSLocalizedString("error.parsing.unsupported_game.recovery", comment: "Use Manual Entry or wait for an app update")
        case .dateParsingFailed:
            return NSLocalizedString("error.parsing.date_failed.recovery", comment: "Add the result manually with today's date")
        }
    }
}

// MARK: - Persistence Error Details
extension AppError.PersistenceError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .saveFailed(let dataType, _):
            return String(format: NSLocalizedString("error.persistence.save_failed", comment: "Failed to save %@"), dataType)
        case .loadFailed(let dataType, _):
            return String(format: NSLocalizedString("error.persistence.load_failed", comment: "Failed to load %@"), dataType)
        case .dataCorrupted(let dataType):
            return String(format: NSLocalizedString("error.persistence.corrupted", comment: "%@ data is corrupted"), dataType)
        case .migrationFailed:
            return NSLocalizedString("error.persistence.migration_failed", comment: "Data migration failed")
        case .storageFull:
            return NSLocalizedString("error.persistence.storage_full", comment: "Device storage is full")
        case .keyNotFound:
            return NSLocalizedString("error.persistence.key_not_found", comment: "Data not found")
        case .encodingFailed:
            return NSLocalizedString("error.persistence.encoding_failed", comment: "Failed to encode data")
        case .decodingFailed:
            return NSLocalizedString("error.persistence.decoding_failed", comment: "Failed to decode data")
        }
    }
    
    var failureReason: String? {
        switch self {
        case .saveFailed(_, let underlying):
            return underlying?.localizedDescription ?? NSLocalizedString("error.persistence.save_failed.reason", comment: "Data could not be written to storage")
        case .loadFailed(_, let underlying):
            return underlying?.localizedDescription ?? NSLocalizedString("error.persistence.load_failed.reason", comment: "Data could not be read from storage")
        case .dataCorrupted:
            return NSLocalizedString("error.persistence.corrupted.reason", comment: "The stored data is in an invalid format")
        case .migrationFailed(let from, let to):
            return String(format: NSLocalizedString("error.persistence.migration_failed.reason", comment: "Could not migrate from version %@ to %@"), from, to)
        case .storageFull:
            return NSLocalizedString("error.persistence.storage_full.reason", comment: "There is not enough space to save data")
        case .keyNotFound(let key):
            return String(format: NSLocalizedString("error.persistence.key_not_found.reason", comment: "No data found for key: %@"), key)
        case .encodingFailed(let underlying):
            return underlying.localizedDescription
        case .decodingFailed(let underlying):
            return underlying.localizedDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .saveFailed:
            return NSLocalizedString("error.persistence.save_failed.recovery", comment: "Try again or restart the app")
        case .loadFailed:
            return NSLocalizedString("error.persistence.load_failed.recovery", comment: "Pull to refresh or restart the app")
        case .dataCorrupted:
            return NSLocalizedString("error.persistence.corrupted.recovery", comment: "You may need to reset app data in Settings")
        case .migrationFailed:
            return NSLocalizedString("error.persistence.migration_failed.recovery", comment: "Update to the latest app version")
        case .storageFull:
            return NSLocalizedString("error.persistence.storage_full.recovery", comment: "Free up space on your device")
        case .keyNotFound:
            return NSLocalizedString("error.persistence.key_not_found.recovery", comment: "This data may have been deleted")
        case .encodingFailed, .decodingFailed:
            return NSLocalizedString("error.persistence.coding_failed.recovery", comment: "Try updating the app or contact support")
        }
    }
}

// MARK: - Sync Error Details
extension AppError.SyncError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .appGroupCommunicationFailed:
            return NSLocalizedString("error.sync.app_group", comment: "Communication between app components failed")
        case .notificationPostFailed:
            return NSLocalizedString("error.sync.notification", comment: "Failed to send update notification")
        case .urlSchemeInvalid:
            return NSLocalizedString("error.sync.url_scheme", comment: "Invalid app link")
        case .darwinNotificationFailed:
            return NSLocalizedString("error.sync.darwin", comment: "System notification failed")
        case .resultAlreadyProcessed:
            return NSLocalizedString("error.sync.duplicate", comment: "This result was already saved")
        case .syncTimeout:
            return NSLocalizedString("error.sync.timeout", comment: "Sync timed out")
        }
    }
    
    var failureReason: String? {
        switch self {
        case .appGroupCommunicationFailed:
            return NSLocalizedString("error.sync.app_group.reason", comment: "Share Extension couldn't communicate with main app")
        case .notificationPostFailed:
            return NSLocalizedString("error.sync.notification.reason", comment: "The system couldn't deliver the notification")
        case .urlSchemeInvalid(let url):
            return String(format: NSLocalizedString("error.sync.url_scheme.reason", comment: "The URL '%@' is not valid"), url)
        case .darwinNotificationFailed:
            return NSLocalizedString("error.sync.darwin.reason", comment: "Inter-process communication is unavailable")
        case .resultAlreadyProcessed:
            return NSLocalizedString("error.sync.duplicate.reason", comment: "Duplicate game results are not saved")
        case .syncTimeout:
            return NSLocalizedString("error.sync.timeout.reason", comment: "The operation took too long to complete")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .appGroupCommunicationFailed:
            return NSLocalizedString("error.sync.app_group.recovery", comment: "Open StreakSync to sync your results")
        case .notificationPostFailed:
            return NSLocalizedString("error.sync.notification.recovery", comment: "Pull to refresh in the main app")
        case .urlSchemeInvalid:
            return NSLocalizedString("error.sync.url_scheme.recovery", comment: "Update the app to the latest version")
        case .darwinNotificationFailed:
            return NSLocalizedString("error.sync.darwin.recovery", comment: "Restart your device if the problem persists")
        case .resultAlreadyProcessed:
            return nil // No recovery needed
        case .syncTimeout:
            return NSLocalizedString("error.sync.timeout.recovery", comment: "Check your internet connection and try again")
        }
    }
}

// MARK: - UI Error Details
extension AppError.UIError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .navigationFailed(let destination):
            return String(format: NSLocalizedString("error.ui.navigation", comment: "Could not navigate to %@"), destination)
        case .missingRequiredData(let viewName):
            return String(format: NSLocalizedString("error.ui.missing_data", comment: "%@ is missing required data"), viewName)
        case .sheetPresentationFailed:
            return NSLocalizedString("error.ui.sheet", comment: "Could not display content")
        case .stateInconsistency:
            return NSLocalizedString("error.ui.state", comment: "App state error occurred")
        case .viewModelNotInitialized:
            return NSLocalizedString("error.ui.viewmodel", comment: "View failed to load properly")
        }
    }
    
    var failureReason: String? {
        switch self {
        case .navigationFailed:
            return NSLocalizedString("error.ui.navigation.reason", comment: "The navigation stack is in an invalid state")
        case .missingRequiredData:
            return NSLocalizedString("error.ui.missing_data.reason", comment: "Required data was not available when the view loaded")
        case .sheetPresentationFailed:
            return NSLocalizedString("error.ui.sheet.reason", comment: "Another sheet may already be presented")
        case .stateInconsistency(let description):
            return description
        case .viewModelNotInitialized:
            return NSLocalizedString("error.ui.viewmodel.reason", comment: "The view's data model failed to initialize")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .navigationFailed:
            return NSLocalizedString("error.ui.navigation.recovery", comment: "Go back and try again")
        case .missingRequiredData:
            return NSLocalizedString("error.ui.missing_data.recovery", comment: "Return to the previous screen")
        case .sheetPresentationFailed:
            return NSLocalizedString("error.ui.sheet.recovery", comment: "Dismiss any open screens and try again")
        case .stateInconsistency:
            return NSLocalizedString("error.ui.state.recovery", comment: "Restart the app if the problem persists")
        case .viewModelNotInitialized:
            return NSLocalizedString("error.ui.viewmodel.recovery", comment: "Pull to refresh or restart the app")
        }
    }
}

// MARK: - Error Severity
extension AppError {
    enum Severity {
        case low      // Log only
        case medium   // Show inline error
        case high     // Show alert
        case critical // Show alert with app restart option
    }
    
    var severity: Severity {
        switch self {
        case .shareExtension(let error):
            switch error {
            case .noContent, .invalidContentType:
                return .medium
            case .processingTimeout:
                return .medium
            case .appGroupAccessFailed:
                return .critical
            case .saveFailed, .notificationFailed:
                return .high
            }
            
        case .parsing:
            return .medium // All parsing errors are recoverable
            
        case .persistence(let error):
            switch error {
            case .storageFull:
                return .critical
            case .dataCorrupted, .migrationFailed:
                return .high
            default:
                return .medium
            }
            
        case .sync(let error):
            switch error {
            case .resultAlreadyProcessed:
                return .low
            case .appGroupCommunicationFailed:
                return .high
            default:
                return .medium
            }
            
        case .ui(let error):
            switch error {
            case .stateInconsistency:
                return .high
            default:
                return .medium
            }
        }
    }
}

// MARK: - Analytics Properties
extension AppError {
    /// Properties safe for analytics (no user data)
    var analyticsProperties: [String: Any] {
        var properties: [String: Any] = [
            "error_category": errorCategory,
            "error_code": errorCode,
            "severity": severity.analyticsValue
        ]
        
        // Add specific properties based on error type
        switch self {
        case .shareExtension(let error):
            properties["share_error_type"] = error.analyticsIdentifier
        case .parsing(let error):
            properties["parsing_error_type"] = error.analyticsIdentifier
        case .persistence(let error):
            properties["persistence_error_type"] = error.analyticsIdentifier
        case .sync(let error):
            properties["sync_error_type"] = error.analyticsIdentifier
        case .ui(let error):
            properties["ui_error_type"] = error.analyticsIdentifier
        }
        
        return properties
    }
    
    internal var errorCategory: String {
        switch self {
        case .shareExtension: return "share_extension"
        case .parsing: return "parsing"
        case .persistence: return "persistence"
        case .sync: return "sync"
        case .ui: return "ui"
        }
    }
    
    internal var errorCode: String {
        switch self {
        case .shareExtension(let error): return "SE\(error.errorCode)"
        case .parsing(let error): return "PA\(error.errorCode)"
        case .persistence(let error): return "PE\(error.errorCode)"
        case .sync(let error): return "SY\(error.errorCode)"
        case .ui(let error): return "UI\(error.errorCode)"
        }
    }
}

// MARK: - Analytics Extensions
private extension AppError.Severity {
    var analyticsValue: String {
        switch self {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .critical: return "critical"
        }
    }
}

private extension AppError.ShareExtensionError {
    var analyticsIdentifier: String {
        switch self {
        case .noContent: return "no_content"
        case .invalidContentType: return "invalid_content_type"
        case .processingTimeout: return "timeout"
        case .appGroupAccessFailed: return "app_group_failed"
        case .saveFailed: return "save_failed"
        case .notificationFailed: return "notification_failed"
        }
    }
    
    var errorCode: Int {
        switch self {
        case .noContent: return 100
        case .invalidContentType: return 101
        case .processingTimeout: return 102
        case .appGroupAccessFailed: return 103
        case .saveFailed: return 104
        case .notificationFailed: return 105
        }
    }
}

private extension AppError.ParsingError {
    var analyticsIdentifier: String {
        switch self {
        case .unknownGameFormat: return "unknown_format"
        case .invalidScoreFormat: return "invalid_score"
        case .missingPuzzleNumber: return "missing_puzzle"
        case .malformedGameData: return "malformed_data"
        case .unsupportedGame: return "unsupported_game"
        case .dateParsingFailed: return "date_parsing_failed"
        }
    }
    
    var errorCode: Int {
        switch self {
        case .unknownGameFormat: return 200
        case .invalidScoreFormat: return 201
        case .missingPuzzleNumber: return 202
        case .malformedGameData: return 203
        case .unsupportedGame: return 204
        case .dateParsingFailed: return 205
        }
    }
}

private extension AppError.PersistenceError {
    var analyticsIdentifier: String {
        switch self {
        case .saveFailed: return "save_failed"
        case .loadFailed: return "load_failed"
        case .dataCorrupted: return "data_corrupted"
        case .migrationFailed: return "migration_failed"
        case .storageFull: return "storage_full"
        case .keyNotFound: return "key_not_found"
        case .encodingFailed: return "encoding_failed"
        case .decodingFailed: return "decoding_failed"
        }
    }
    
    var errorCode: Int {
        switch self {
        case .saveFailed: return 300
        case .loadFailed: return 301
        case .dataCorrupted: return 302
        case .migrationFailed: return 303
        case .storageFull: return 304
        case .keyNotFound: return 305
        case .encodingFailed: return 306
        case .decodingFailed: return 307
        }
    }
}

private extension AppError.SyncError {
    var analyticsIdentifier: String {
        switch self {
        case .appGroupCommunicationFailed: return "app_group_failed"
        case .notificationPostFailed: return "notification_failed"
        case .urlSchemeInvalid: return "invalid_url_scheme"
        case .darwinNotificationFailed: return "darwin_failed"
        case .resultAlreadyProcessed: return "duplicate_result"
        case .syncTimeout: return "timeout"
        }
    }
    
    var errorCode: Int {
        switch self {
        case .appGroupCommunicationFailed: return 400
        case .notificationPostFailed: return 401
        case .urlSchemeInvalid: return 402
        case .darwinNotificationFailed: return 403
        case .resultAlreadyProcessed: return 404
        case .syncTimeout: return 405
        }
    }
}

private extension AppError.UIError {
    var analyticsIdentifier: String {
        switch self {
        case .navigationFailed: return "navigation_failed"
        case .missingRequiredData: return "missing_data"
        case .sheetPresentationFailed: return "sheet_failed"
        case .stateInconsistency: return "state_error"
        case .viewModelNotInitialized: return "viewmodel_error"
        }
    }
    
    var errorCode: Int {
        switch self {
        case .navigationFailed: return 500
        case .missingRequiredData: return 501
        case .sheetPresentationFailed: return 502
        case .stateInconsistency: return 503
        case .viewModelNotInitialized: return 504
        }
    }
}
