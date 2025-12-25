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
        // Note: Firebase is configured in AppContainer.init() which runs before this
        // due to SwiftUI's @StateObject initialization order
        
        // Register for remote notifications (required for silent CloudKit pushes)
        UIApplication.shared.registerForRemoteNotifications()
        logger.info("📬 Requested remote notification registration")
        return true
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
}


