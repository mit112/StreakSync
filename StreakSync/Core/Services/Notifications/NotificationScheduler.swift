//
//  NotificationScheduler.swift
//  StreakSync
//
//  Simple daily notification scheduling system
//

/*
 * NOTIFICATIONSCHEDULER - SMART REMINDER AND NOTIFICATION SYSTEM
 * 
 * WHAT THIS FILE DOES:
 * This file is the "reminder system" of the app. It schedules notifications to remind users
 * to play their games and maintain their streaks. Think of it as a "smart alarm clock" that
 * learns when users typically play games and sends reminders at the optimal times. It also
 * handles achievement notifications and other important app events, making sure users don't
 * miss out on their progress or lose their streaks.
 * 
 * WHY IT EXISTS:
 * Users need gentle reminders to maintain their gaming streaks, especially when life gets busy.
 * This scheduler uses smart algorithms to determine the best times to send reminders based on
 * the user's playing patterns. It also celebrates achievements and provides quick actions
 * directly from notifications, making the app more engaging and helpful.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This helps users maintain their streaks and stay engaged
 * - Schedules smart reminders based on user behavior patterns
 * - Handles achievement notifications and celebrations
 * - Provides quick actions directly from notifications
 * - Manages notification permissions and user preferences
 * - Integrates with the smart reminder engine for optimal timing
 * - Supports different notification types and categories
 * 
 * WHAT IT REFERENCES:
 * - UserNotifications: iOS framework for local and push notifications
 * - UNUserNotificationCenter: The system notification center
 * - NotificationCategory: Different types of notifications
 * - NotificationAction: Quick actions users can take from notifications
 * - AppState: Access to user data and playing patterns
 * - Smart reminder algorithms: For determining optimal notification times
 * 
 * WHAT REFERENCES IT:
 * - AppContainer: Creates and manages the NotificationScheduler
 * - AppState: Uses this to schedule notifications when needed
 * - Settings: Users can configure notification preferences
 * - Achievement system: Triggers notifications when achievements are unlocked
 * - Smart reminder engine: Provides optimal timing for notifications
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. NOTIFICATION STRATEGY IMPROVEMENTS:
 *    - The current scheduling is basic - could be more sophisticated
 *    - Consider using machine learning for better timing predictions
 *    - Add support for different reminder frequencies and patterns
 *    - Implement smart notification grouping to avoid spam
 * 
 * 2. USER EXPERIENCE IMPROVEMENTS:
 *    - The current notifications could be more personalized
 *    - Add support for custom notification messages
 *    - Implement notification preferences and customization
 *    - Add support for different notification styles and sounds
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current scheduling could be more efficient
 *    - Consider batching notification requests
 *    - Add support for notification queuing and prioritization
 *    - Implement smart notification cleanup and management
 * 
 * 4. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for notification logic
 *    - Test different notification scenarios and edge cases
 *    - Add integration tests with the notification system
 *    - Test notification permissions and error handling
 * 
 * 5. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for notification types
 *    - Document the scheduling algorithms and timing logic
 *    - Add examples of how to use different notification features
 *    - Create notification flow diagrams
 * 
 * 6. ACCESSIBILITY IMPROVEMENTS:
 *    - Add support for accessibility features in notifications
 *    - Implement VoiceOver-friendly notification content
 *    - Add support for different accessibility needs
 *    - Consider adding haptic feedback for notifications
 * 
 * 7. ANALYTICS INTEGRATION:
 *    - Add analytics for notification effectiveness
 *    - Track user engagement with notification actions
 *    - Monitor notification delivery and interaction rates
 *    - Add A/B testing support for notification content
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new notification types
 *    - Add support for custom notification actions
 *    - Implement notification templates and themes
 *    - Add support for third-party notification integrations
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Notifications: Messages that appear on the user's device
 * - Scheduling: Setting up notifications to appear at specific times
 * - UserNotifications: Apple's framework for handling notifications
 * - Notification categories: Different types of notifications with different actions
 * - Notification actions: Quick actions users can take directly from notifications
 * - Smart algorithms: Computer programs that learn and adapt to user behavior
 * - Permissions: User consent required for sending notifications
 * - Local notifications: Notifications sent by the app itself (not from a server)
 * - Push notifications: Notifications sent from a server to the user's device
 * - Notification center: The system component that manages all notifications
 */

import Foundation
import UserNotifications
import OSLog

// MARK: - Notification Categories
enum NotificationCategory: String, CaseIterable {
    case streakReminder = "STREAK_REMINDER"
    case achievementUnlocked = "ACHIEVEMENT_UNLOCKED"
    case resultImported = "RESULT_IMPORTED"
    
    var identifier: String { rawValue }
}

// MARK: - Notification Actions
enum NotificationAction: String, CaseIterable {
    case openGame = "OPEN_GAME"
    case snooze1Day = "SNOOZE_1_DAY"
    case snooze3Days = "SNOOZE_3_DAYS"
    case markPlayed = "MARK_PLAYED"
    case viewAchievement = "VIEW_ACHIEVEMENT"
    
    var identifier: String { rawValue }
}

// MARK: - Notification Scheduler
@MainActor
final class NotificationScheduler: ObservableObject {
    static let shared = NotificationScheduler()
    
    // MARK: - Properties
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.streaksync.app", category: "NotificationScheduler")
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Settings Keys
    private enum SettingsKeys {
        static let lastNotificationDate = "lastNotificationDate"
        static let dailyNotificationCount = "dailyNotificationCount"
    }
    
    // MARK: - Initialization
    private init() {
        setupDefaultSettings()
    }
    
    // MARK: - Setup
    func registerCategories() async {
        logger.info("📋 Registering notification categories")
        
        var categories: Set<UNNotificationCategory> = []
        
        // Streak Reminder Category
        let streakActions = [
            UNNotificationAction(
                identifier: NotificationAction.openGame.identifier,
                title: "Play Now",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: NotificationAction.snooze1Day.identifier,
                title: "Remind Tomorrow",
                options: []
            ),
            UNNotificationAction(
                identifier: NotificationAction.markPlayed.identifier,
                title: "Already Played",
                options: []
            )
        ]
        
        let streakCategory = UNNotificationCategory(
            identifier: NotificationCategory.streakReminder.identifier,
            actions: streakActions,
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        categories.insert(streakCategory)
        
        // Achievement Category
        let achievementActions = [
            UNNotificationAction(
                identifier: NotificationAction.viewAchievement.identifier,
                title: "View Achievement",
                options: [.foreground]
            )
        ]
        
        let achievementCategory = UNNotificationCategory(
            identifier: NotificationCategory.achievementUnlocked.identifier,
            actions: achievementActions,
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        categories.insert(achievementCategory)
        
        // Result Imported Category
        let resultCategory = UNNotificationCategory(
            identifier: NotificationCategory.resultImported.identifier,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        categories.insert(resultCategory)
        
        center.setNotificationCategories(categories)
        logger.info("✅ Notification categories registered")
    }
    
    // MARK: - Permission Check
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - Daily Streak Reminder
    func scheduleDailyStreakReminder(games: [Game], hour: Int, minute: Int) async {
        guard await checkPermissionStatus() == .authorized else {
            logger.warning("⚠️ Cannot schedule reminder: notifications not authorized")
            return
        }
        
        // Cancel any existing daily reminder first
        await cancelDailyStreakReminder()
        
        let content = UNMutableNotificationContent()
        
        // Create notification content based on number of games
        if games.count == 1 {
            let game = games[0]
            content.title = "Streak Reminder"
            content.body = "Don't lose your \(game.name) streak"
            content.userInfo = [
                "gameId": game.id.uuidString,
                "type": "daily_streak_reminder"
            ]
        } else if games.count <= 3 {
            let gameNames = games.map { $0.name }.joined(separator: ", ")
            content.title = "Streak Reminders"
            content.body = "Don't lose your streaks in \(gameNames)"
            content.userInfo = ["type": "daily_streak_reminder"]
        } else {
            let firstTwo = games.prefix(2).map { $0.name }.joined(separator: ", ")
            let remaining = games.count - 2
            content.title = "Streak Reminders"
            content.body = "Don't lose your streaks in \(firstTwo), and \(remaining) other game\(remaining > 1 ? "s" : "")"
            content.userInfo = ["type": "daily_streak_reminder"]
        }
        
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streakReminder.identifier
        
        // Schedule for user's preferred time
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "daily_streak_reminder",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            logger.info("✅ Scheduled daily streak reminder at \(hour):\(String(format: "%02d", minute)) for \(games.count) games")
        } catch {
            logger.error("❌ Failed to schedule daily streak reminder: \(error.localizedDescription)")
        }
    }
    
    func cancelDailyStreakReminder() async {
        center.removePendingNotificationRequests(withIdentifiers: ["daily_streak_reminder"])
        logger.info("🗑️ Cancelled daily streak reminder")
    }
    
    func cancelAllStreakReminders() async {
        // Cancel the daily reminder
        await cancelDailyStreakReminder()
        
        // Cancel any legacy per-game reminders
        let pendingRequests = await center.pendingNotificationRequests()
        let streakReminderIds = pendingRequests.compactMap { request in
            if request.identifier.contains("streak") {
                return request.identifier
            }
            return nil
        }
        
        if !streakReminderIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: streakReminderIds)
            logger.info("🗑️ Cancelled \(streakReminderIds.count) legacy streak reminders")
        }
    }
    
    
    // MARK: - Digest Preview (Debug/Testing)
    func scheduleDigestPreview(for games: [Game]) async {
        guard await checkPermissionStatus() == .authorized else { return }
        
        let topGames = games.prefix(4)
        let names = topGames.map { $0.name }
        let body: String
        if names.isEmpty {
            body = "No streaks at risk today."
        } else if names.count == 1 {
            body = "Don't lose your streak in \(names[0])."
        } else {
            let list = names.dropLast().joined(separator: ", ")
            body = "Don't lose your streaks in \(list) and \(names.last!)."
        }
        
        let content = UNMutableNotificationContent()
        content.title = "📧 Daily Streak Digest"
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streakReminder.identifier
        content.userInfo = [
            "type": "digest_preview",
            "gameCount": games.count
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "digest_preview_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            logger.info("✅ Scheduled digest preview with \(games.count) games")
        } catch {
            logger.error("❌ Failed to schedule digest preview: \(error.localizedDescription)")
        }
    }
    
    
    // MARK: - Achievement Notifications
    func scheduleAchievementNotification(for unlock: AchievementUnlock) async {
        guard await checkPermissionStatus() == .authorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🎉 Achievement Unlocked!"
        content.body = "\(unlock.achievement.displayName) - \(unlock.tier.displayName)"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.achievementUnlocked.identifier
        content.userInfo = [
            "achievementId": unlock.achievement.id.uuidString,
            "tierId": unlock.tier.id.uuidString,
            "type": "achievement"
        ]
        
        // Immediate notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "achievement_\(unlock.achievement.id.uuidString)_\(unlock.tier.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            logger.info("✅ Scheduled achievement notification for \(unlock.achievement.displayName)")
        } catch {
            logger.error("❌ Failed to schedule achievement notification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Result Import Notifications
    func scheduleResultImportedNotification(for game: Game) async {
        guard await checkPermissionStatus() == .authorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Result Imported"
        content.body = "Your \(game.name) result has been added to your streak!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.resultImported.identifier
        content.userInfo = [
            "gameId": game.id.uuidString,
            "type": "result_imported"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "result_imported_\(game.id.uuidString)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            logger.info("✅ Scheduled result imported notification for \(game.name)")
        } catch {
            logger.error("❌ Failed to schedule result imported notification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cancellation
    
    func cancelAllNotifications() async {
        center.removeAllPendingNotificationRequests()
        logger.info("🗑️ Cancelled all pending notifications")
    }
    
    
    
    // MARK: - Settings Management
    
    /// Clean up all existing notifications before applying new settings
    /// This prevents accumulation of old notifications when settings change
    func cleanupAndRescheduleNotifications() async {
        logger.info("🧹 Cleaning up all existing notifications before rescheduling...")
        
        // Get all pending requests to log what we're cleaning up
        let pendingRequests = await center.pendingNotificationRequests()
        logger.info("📋 Found \(pendingRequests.count) pending notifications to clean up")
        
        // Log details of what we're cleaning up for debugging
        for request in pendingRequests {
            logger.info("  🗑️ Removing: \(request.identifier) - \(request.content.title)")
        }
        
        // Cancel all pending notifications
        center.removeAllPendingNotificationRequests()
        
        logger.info("✅ Cleaned up all existing notifications")
    }
    
    /// Debug method to log current notification state
    func logCurrentNotificationState() async {
        let pendingRequests = await center.pendingNotificationRequests()
        logger.info("📊 Current notification state: \(pendingRequests.count) pending notifications")
        
        for request in pendingRequests {
            let triggerDescription: String
            if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
                triggerDescription = "Calendar: \(calendarTrigger.dateComponents)"
            } else if let intervalTrigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                triggerDescription = "Interval: \(intervalTrigger.timeInterval)s"
            } else {
                triggerDescription = "Unknown trigger type"
            }
            
            logger.info("  📋 \(request.identifier): \(request.content.title) - \(triggerDescription)")
        }
    }
    
    // MARK: - Private Helpers
    private func setupDefaultSettings() {
        // No default settings needed for simplified system
        // Settings are managed by AppState migration
    }
    
    // MARK: - Test Methods
    #if DEBUG
    func scheduleTestDailyReminder(games: [Game]) async {
        guard await checkPermissionStatus() == .authorized else { return }
        
        let content = UNMutableNotificationContent()
        
        if games.count == 1 {
            content.title = "🧪 Test Streak Reminder"
            content.body = "Don't lose your \(games[0].name) streak"
        } else {
            let names = games.map { $0.name }.joined(separator: ", ")
            content.title = "🧪 Test Streak Reminders"
            content.body = "Don't lose your streaks in \(names)"
        }
        
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streakReminder.identifier
        content.userInfo = ["type": "daily_streak_reminder_test"]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_daily_reminder_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            logger.info("✅ Scheduled test daily reminder for \(games.count) games")
        } catch {
            logger.error("❌ Failed to schedule test reminder: \(error.localizedDescription)")
        }
    }
    
    #endif
    
}

