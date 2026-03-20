//
//  Game+Validation.swift
//  StreakSync
//
//  Game model validation and safety extensions
//  Prevents SF Symbol empty string errors
//

import Foundation
import OSLog

private let validationLogger = Logger(subsystem: "com.streaksync.app", category: "GameValidation")

extension Game {
    /// Validates and fixes game data
    /// Logs warnings for games with missing icons in debug builds
    static func validateGameCatalog() {
        #if DEBUG
        let invalidGames = allAvailableGames.filter { $0.iconSystemName.isEmpty }
        if !invalidGames.isEmpty {
            validationLogger.warning("🚨 Games with missing icons:")
            for game in invalidGames {
                validationLogger.warning("  - \(game.displayName) (\(game.name)): Missing icon")
            }
            validationLogger.warning("🚨 Consider adding default icons to prevent SF Symbol errors")
        } else {
            validationLogger.debug("✅ All games have valid icons")
        }
        #endif
    }
}
