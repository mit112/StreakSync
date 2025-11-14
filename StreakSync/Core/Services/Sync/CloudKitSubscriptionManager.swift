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
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            return
        }
        if notification.subscriptionID == "achievements_zone_sub" {
            await container.achievementSyncService.syncIfEnabled()
            return
        }
        if let zoneNote = notification as? CKRecordZoneNotification,
           let zoneID = zoneNote.recordZoneID {
            // If future: handle per-leaderboard subscriptions by zone ID or subscription ID
            if zoneID == CloudKitZones.achievementsZoneID {
                await container.achievementSyncService.syncIfEnabled()
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


