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
    /// Validated icon system name that always returns a valid SF Symbol
    /// Prevents "No symbol named '' found in system symbol set" errors
    var safeIconSystemName: String {
        iconSystemName.isEmpty ? "gamecontroller" : iconSystemName
    }
    
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
    
    /// Creates a validated game with safe icon fallback
    /// Use this when creating games programmatically
    static func createValidatedGame(
        id: UUID = UUID(),
        name: String,
        displayName: String,
        url: URL,
        category: GameCategory,
        resultPattern: String,
        iconSystemName: String,
        backgroundColor: CodableColor,
        isPopular: Bool = false,
        isCustom: Bool = false
    ) -> Game {
        let safeIcon = iconSystemName.isEmpty ? "gamecontroller" : iconSystemName
        
        #if DEBUG
        if iconSystemName.isEmpty {
            validationLogger.warning("⚠️ Empty icon provided for '\(displayName)', using fallback: gamecontroller")
        }
        #endif
        
        return Game(
            id: id,
            name: name,
            displayName: displayName,
            url: url,
            category: category,
            resultPattern: resultPattern,
            iconSystemName: safeIcon,
            backgroundColor: backgroundColor,
            isPopular: isPopular,
            isCustom: isCustom
        )
    }
}

// MARK: - Achievement Tier Extensions
extension AchievementTier {
    /// Validated icon system name that always returns a valid SF Symbol
    var safeIconSystemName: String {
        iconSystemName.isEmpty ? "trophy.fill" : iconSystemName
    }
}
