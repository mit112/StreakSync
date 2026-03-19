//
//  AppError+ErrorDetails.swift
//  StreakSync
//
//  Localized error details for each nested error type
//

import Foundation

// MARK: - Share Extension Error Details
extension AppError.ShareExtensionError {
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
extension AppError.ParsingError {
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
extension AppError.PersistenceError {
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
extension AppError.SyncError {
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
extension AppError.UIError {
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
