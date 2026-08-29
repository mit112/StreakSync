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
        // Claim the UNUserNotificationCenter delegate here, not from an async `.task`.
        // `NotificationDelegate.init` assigns it, and the first touch used to happen
        // after this method returned — a notification tap that cold-launched the app
        // could be delivered before anyone was listening.
        _ = NotificationDelegate.shared

        // App Check is disabled until enforcement is enabled in Firestore rules.
        // When ready: register debug token in Firebase Console → App Check → Manage debug tokens,
        // then uncomment the line below.
        // AppCheck.setAppCheckProviderFactory(StreakSyncAppCheckProviderFactory())
        
        // Configure Firebase before any other services initialize.
        // This is the officially recommended location per Firebase docs.
        //
        // Load the options explicitly rather than calling the zero-argument
        // `FirebaseApp.configure()`: that variant raises an Objective-C exception when
        // GoogleService-Info.plist is missing or malformed, which aborts the process
        // before anything can report why. GoogleService-Info.plist is gitignored, so any
        // checkout without it — CI in particular — died at launch with an opaque
        // "Early unexpected exit" instead of a diagnosable message.
        if FirebaseApp.app() == nil {
            if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
               let options = FirebaseOptions(contentsOfFile: path) {
                FirebaseApp.configure(options: options)

                let settings = FirestoreSettings()
                settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024))
                Firestore.firestore().settings = settings

                logger.info("Firebase configured in AppDelegate")
            } else {
                // Local-only mode: the app still launches and every offline feature works.
                logger.error("GoogleService-Info.plist missing or unreadable — running without Firebase")
            }
        }

        return true
    }
}
