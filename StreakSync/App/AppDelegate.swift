//
//  AppDelegate.swift
//  StreakSync
//
//  Handles app-level lifecycle events (Firebase configuration).
//

import FirebaseAppCheck
import FirebaseCore
import FirebaseFirestore
import OSLog
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AppDelegate")
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
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
        
        return true
    }
}
