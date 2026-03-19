//
//  AppError+Analytics.swift
//  StreakSync
//
//  Error severity classification and analytics properties
//

import Foundation

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
