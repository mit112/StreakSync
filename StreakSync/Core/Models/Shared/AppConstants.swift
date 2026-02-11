//
//  AppConstants.swift
//  StreakSync
//
//  Created by MiT on 7/28/25.
//

///
//  AppConstants.swift
//  StreakSync
//
//  Centralized constants and configuration
//

import Foundation

enum AppConstants {
    // MARK: - Flags
    enum Flags {
        // CloudKit sync defaults to ON for all users (gracefully no-ops if iCloud unavailable)
        static var cloudSyncEnabled: Bool {
            get {
                let defaults = UserDefaults.standard
                if defaults.object(forKey: "cloudSyncEnabled") == nil {
                    // Default ON when not explicitly set
                    return true
                }
                return defaults.bool(forKey: "cloudSyncEnabled")
            }
            set { UserDefaults.standard.set(newValue, forKey: "cloudSyncEnabled") }
        }
    }

    // MARK: - Storage Limits
    enum Storage {
        static let maxResults = 100
        static let maxCacheSize = 100
        static let duplicateTimeWindow: TimeInterval = 2.0
    }
    
    // MARK: - App Group Keys
    enum AppGroup {
        static let identifier = "group.com.mitsheth.StreakSync"
        static let latestResultKey = "latestGameResult"
        static let queuedResultsKey = "gameResults"
        static let lastSaveTimestampKey = "lastShareExtensionSave"
        static let processingFlagKey = "isProcessingShare"
    }
    
    // MARK: - Notification Names
    enum Notification {
        static let gameResultReceived = "gameResultReceived"
        static let shareExtensionResultAvailable = "shareExtensionResultAvailable"
        static let gameDataUpdated = "GameDataUpdated"
        static let refreshGameData = "RefreshGameData"
        static let darwinNotificationName = "com.streaksync.app.newResult"
        static let tieredAchievementUnlocked = "TieredAchievementUnlocked"
        // Typed Notification.Name accessors are defined below (see extension)
    }

    // MARK: - Deep Link Keys
    enum DeepLinkKeys {
        static let gameId = "gameId"
        static let name = "name"
        static let achievementId = "achievementId"
    }
    
    // MARK: - Animation Durations
    enum Animation {
        static let standardDuration = 0.3
        static let refreshDelay = 0.5
        static let monitoringInterval: UInt64 = 1_000_000_000 // 1 second in nanoseconds
    }
    
    // MARK: - URL Schemes
    enum URLScheme {
        static let scheme = "streaksync"
        static let shareActivity = "com.streaksync.share"
    }
    
    // MARK: - CloudKit
    enum CloudKitKeys {
        static let recordTypeUserAchievements = "UserAchievements"
        static let fieldVersion = "version"
        static let fieldPayload = "payload"
        static let fieldLastUpdated = "lastUpdated"
        static let fieldSummary = "summary"
        static let recordID = "user_achievements"
    }
}

// MARK: - Typed Notification Names
extension Notification.Name {
    static let appGameResultReceived = Notification.Name(AppConstants.Notification.gameResultReceived)
    static let appShareExtensionResultAvailable = Notification.Name(AppConstants.Notification.shareExtensionResultAvailable)
    static let appGameDataUpdated = Notification.Name(AppConstants.Notification.gameDataUpdated)
    static let appRefreshGameData = Notification.Name(AppConstants.Notification.refreshGameData)
    static let appGameResultAdded = Notification.Name("GameResultAdded")
    static let appNavigateToGame = Notification.Name("NavigateToGame")
    static let appHandleNewGameResult = Notification.Name("HandleNewGameResult")
    static let appTieredAchievementUnlocked = Notification.Name(AppConstants.Notification.tieredAchievementUnlocked)
}
