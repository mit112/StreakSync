//
//  AppDelegate.swift
//  StreakSync
//
//  Handles remote notification registration.
//

import UIKit
import OSLog
import GoogleSignIn
import FirebaseCore
import FirebaseFirestore
import FirebaseAppCheck

final class AppDelegate: NSObject, UIApplicationDelegate {
    weak var container: AppContainer?
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AppDelegate")
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // App Check is disabled until enforcement is enabled in Firestore rules.
        // When ready: register debug token in Firebase Console → App Check → Manage debug tokens,
        // then uncomment the line below.
        // AppCheck.setAppCheckProviderFactory(StreakSyncAppCheckProviderFactory())
        
        // Configure Firebase before any other services initialize.
        // This is the officially recommended location per Firebase docs.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            
            let settings = FirestoreSettings()
            settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024))
            Firestore.firestore().settings = settings
            
 logger.info("Firebase configured in AppDelegate")
        }
        
        // Register for remote notifications
        UIApplication.shared.registerForRemoteNotifications()
 logger.info("Requested remote notification registration")
        return true
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
 logger.info("Registered for remote notifications")
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
 logger.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Firebase handles sync via Firestore listeners
        completionHandler(.noData)
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        return false
    }
}


