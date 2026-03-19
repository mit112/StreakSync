//
//  AppError.swift
//  StreakSync
//
//  Comprehensive error handling system with localization and recovery
//

import Foundation

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

    enum ShareExtensionError: LocalizedError {
        case noContent
        case invalidContentType(String)
        case processingTimeout
        case appGroupAccessFailed
        case saveFailed(underlying: Error?)
        case notificationFailed
    }

    enum ParsingError: LocalizedError {
        case unknownGameFormat(text: String)
        case invalidScoreFormat(game: String, score: String)
        case missingPuzzleNumber(game: String)
        case malformedGameData(game: String, reason: String)
        case unsupportedGame(detectedName: String)
        case dateParsingFailed
    }

    enum PersistenceError: LocalizedError {
        case saveFailed(dataType: String, underlying: Error?)
        case loadFailed(dataType: String, underlying: Error?)
        case dataCorrupted(dataType: String)
        case migrationFailed(from: String, to: String)
        case storageFull
        case keyNotFound(key: String)
        case encodingFailed(underlying: Error)
        case decodingFailed(underlying: Error)
    }

    enum SyncError: LocalizedError {
        case appGroupCommunicationFailed
        case notificationPostFailed
        case urlSchemeInvalid(url: String)
        case darwinNotificationFailed
        case resultAlreadyProcessed
        case syncTimeout
    }

    enum UIError: LocalizedError {
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
