//
//  AppDelegate.swift
//  StreakSync
//
//  Handles remote notification registration and CloudKit subscription pushes.
//

import UIKit
import OSLog
import CloudKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    weak var container: AppContainer?
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AppDelegate")
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register for remote notifications (required for silent CloudKit pushes)
        UIApplication.shared.registerForRemoteNotifications()
        logger.info("📬 Requested remote notification registration")
        return true
    }
    
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        guard let container = container else {
            logger.warning("⚠️ CKShare accepted before container initialization")
            return
        }
        Task { @MainActor in
            do {
                try await container.leaderboardSyncService.acceptShare(metadata: cloudKitShareMetadata)
                logger.info("✅ Accepted CloudKit share")
                if let rootRecord = cloudKitShareMetadata.rootRecord,
                   let gid = parseGroupId(from: rootRecord.recordID.recordName) {
                    LeaderboardGroupStore.setSelectedGroup(id: gid, title: nil)
                    logger.info("📌 Set active leaderboard group: \(gid.uuidString, privacy: .public)")
                }
            } catch {
                logger.error("❌ Failed to accept CloudKit share: \(error.localizedDescription)")
            }
        }
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        logger.info("✅ Registered for remote notifications")
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let container = container else {
            logger.warning("⚠️ Received remote notification before container initialization")
            completionHandler(.noData)
            return
        }
        
        Task { @MainActor in
            await CloudKitSubscriptionManager.handleRemoteNotification(userInfo, container: container)
            completionHandler(.newData)
        }
    }
    
    private func parseGroupId(from recordName: String) -> UUID? {
        guard recordName.hasPrefix("group_") else { return nil }
        let uuidString = String(recordName.dropFirst("group_".count))
        return UUID(uuidString: uuidString)
    }
}


