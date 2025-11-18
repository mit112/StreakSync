//
//  CloudKitSubscriptionManager.swift
//  StreakSync
//
//  Helpers for handling CloudKit subscription notifications.
//

import Foundation
#if canImport(CloudKit)
import CloudKit
#endif
import OSLog

enum CloudKitSubscriptionManager {
    #if canImport(CloudKit)
    private static let logger = Logger(subsystem: "com.streaksync.app", category: "CloudKitSubscription")
    static func handleRemoteNotification(_ userInfo: [AnyHashable: Any],
                                         container: AppContainer) async {
        // Ignore CloudKit pushes while Guest Mode is active; guest sessions are
        // local-only and should not trigger background sync.
        let isGuest = await MainActor.run { container.appState.isGuestMode }
        if isGuest {
            logger.info("🧑‍🤝‍🧑 Guest Mode active – ignoring CloudKit remote notification")
            return
        }
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            return
        }
        
        // Subscription-based routing
        if notification.subscriptionID == "achievements_zone_sub" {
            await container.achievementSyncService.syncIfEnabled()
            return
        }
        
        if notification.subscriptionID == "user-data-zone-changes" {
            logger.info("📡 Received UserDataZone subscription push")
            await container.userDataSyncService.syncIfNeeded()
            await container.appState.rebuildStreaksFromResults()
            // Normalize streaks after rebuild to check for gaps up to today
            await container.appState.normalizeStreaksForMissedDays()
            return
        }
        
        if let zoneNote = notification as? CKRecordZoneNotification,
           let zoneID = zoneNote.recordZoneID {
            // If future: handle per-leaderboard subscriptions by zone ID or subscription ID
            if zoneID == CloudKitZones.achievementsZoneID {
                await container.achievementSyncService.syncIfEnabled()
                return
            }
            if zoneID == CloudKitZones.userDataZoneID {
                logger.info("📡 Received UserDataZone zone push")
                await container.userDataSyncService.syncIfNeeded()
                await container.appState.rebuildStreaksFromResults()
                // Normalize streaks after rebuild to check for gaps up to today
                await container.appState.normalizeStreaksForMissedDays()
                return
            }
            if zoneID.zoneName.hasPrefix("leaderboard_") {
                logger.info("📡 Received leaderboard zone push: \(zoneID.zoneName, privacy: .public)")
                // Future: trigger targeted leaderboard refresh for this group
                return
            }
        }
    }
    #endif
}


