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
    // MARK: - Storage Limits
    enum Storage {
        static let maxResults = 500
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
        static let darwinNotificationName = "com.streaksync.app.newResult"
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
    
}

// MARK: - Typed Notification Names
extension Notification.Name {
    static let appGameDataUpdated = Notification.Name(AppConstants.Notification.gameDataUpdated)
    static let appNavigateToGame = Notification.Name("NavigateToGame")
    static let appHandleNewGameResult = Notification.Name("HandleNewGameResult")
}
