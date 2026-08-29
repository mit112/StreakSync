//
//  AppErrorFixtures.swift
//  StreakSyncTests
//
//  Exhaustive AppError case list shared by the Core/Errors test files.
//

import Foundation
@testable import StreakSync

/// One value per `AppError` case (31 in total). Adding a case to `AppError`
/// without adding it here is exactly what these lists exist to make obvious:
/// the "every case" tests below stop covering the new case silently.
enum AppErrorFixtures {
    /// Stand-in for a framework error handed to the `underlying:` payloads.
    /// `NSError` is used deliberately — a bare Swift error would produce an
    /// unstable "The operation couldn't be completed" description.
    static let underlying = NSError(
        domain: "AppErrorFixtures",
        code: 42,
        userInfo: [NSLocalizedDescriptionKey: "the disk gave up"]
    )

    static let shareExtension: [AppError.ShareExtensionError] = [
        .noContent,
        .invalidContentType("public.image"),
        .processingTimeout,
        .appGroupAccessFailed,
        .saveFailed(underlying: nil),
        .notificationFailed
    ]

    static let parsing: [AppError.ParsingError] = [
        .unknownGameFormat(text: "this is not a game share"),
        .invalidScoreFormat(game: "Wordle", score: "9/6"),
        .missingPuzzleNumber(game: "Wordle"),
        .malformedGameData(game: "Wordle", reason: "no grid rows"),
        .unsupportedGame(detectedName: "Sudoku Deluxe"),
        .dateParsingFailed
    ]

    static let persistence: [AppError.PersistenceError] = [
        .saveFailed(dataType: "GameResult", underlying: nil),
        .loadFailed(dataType: "GameResult", underlying: nil),
        .dataCorrupted(dataType: "GameResult"),
        .migrationFailed(from: "1", to: "2"),
        .storageFull,
        .keyNotFound(key: "gameResults"),
        .encodingFailed(underlying: underlying),
        .decodingFailed(underlying: underlying)
    ]

    static let sync: [AppError.SyncError] = [
        .appGroupCommunicationFailed,
        .notificationPostFailed,
        .urlSchemeInvalid(url: "streaksync://game/"),
        .darwinNotificationFailed,
        .resultAlreadyProcessed,
        .syncTimeout
    ]

    static let ui: [AppError.UIError] = [
        .navigationFailed(destination: "GameDetail"),
        .missingRequiredData(viewName: "GameDetailView"),
        .sheetPresentationFailed,
        .stateInconsistency(description: "streaks desynced"),
        .viewModelNotInitialized
    ]

    /// Every nested case, wrapped in its `AppError` parent.
    static var all: [AppError] {
        var errors = shareExtension.map(AppError.shareExtension)
        errors.append(contentsOf: parsing.map(AppError.parsing))
        errors.append(contentsOf: persistence.map(AppError.persistence))
        errors.append(contentsOf: sync.map(AppError.sync))
        errors.append(contentsOf: ui.map(AppError.ui))
        return errors
    }
}
