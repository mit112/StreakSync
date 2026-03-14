//
//  NotificationScheduler.swift
//  StreakSync
//
//  Simple daily notification scheduling system
//

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
final class NotificationScheduler {
    static let shared = NotificationScheduler()
    
    // MARK: - Properties
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.streaksync.app", category: "NotificationScheduler")

    // MARK: - Initialization
    private init() {}
    
    // MARK: - Setup
    func registerCategories() async {
 logger.info("Registering notification categories")
        
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
                identifier: NotificationAction.snooze3Days.identifier,
                title: "Snooze 3 Days",
                options: []
            ),
            UNNotificationAction(
                identifier: NotificationAction.markPlayed.identifier,
                title: "Dismiss",
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
 logger.info("Notification categories registered")
    }
    
    // MARK: - Shared Content Builder
    
    /// Builds notification content for streak reminder notifications.
    /// Used by daily reminders, snooze reminders, and digest previews.
    /// Internal for @testable import in unit tests.
    func buildStreakReminderContent(games: [Game]) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        
        if games.count == 1 {
            let game = games[0]
            content.title = "Streak Reminder"
            content.body = "Don't lose your \(game.displayName) streak"
            content.userInfo = ["gameId": game.id.uuidString, "type": "daily_streak_reminder"]
        } else if games.count <= 3 && games.count > 0 {
            let gameNames = games.map { $0.displayName }.joined(separator: ", ")
            content.title = "Streak Reminders"
            content.body = "Don't lose your streaks in \(gameNames)"
            content.userInfo = ["type": "daily_streak_reminder"]
        } else if games.count > 3 {
            let firstTwo = games.prefix(2).map { $0.displayName }.joined(separator: ", ")
            let remaining = games.count - 2
            content.title = "Streak Reminders"
            content.body = "Don't lose your streaks in \(firstTwo), and \(remaining) other game\(remaining > 1 ? "s" : "")"
            content.userInfo = ["type": "daily_streak_reminder"]
        } else {
            content.title = "Streak Reminder"
            content.body = "No streaks at risk today."
            content.userInfo = ["type": "daily_streak_reminder"]
        }
        
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streakReminder.identifier
        return content
    }
    
    // MARK: - Permission Check
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - Daily Streak Reminder
    func scheduleDailyStreakReminder(games: [Game], hour: Int, minute: Int) async {
        guard await checkPermissionStatus() == .authorized else {
 logger.warning("Cannot schedule reminder: notifications not authorized")
            return
        }
        
        // Cancel any existing daily reminder first
        await cancelDailyStreakReminder()
        
        let content = buildStreakReminderContent(games: games)
        
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
 logger.info("Scheduled daily streak reminder at \(hour):\(String(format: "%02d", minute)) for \(games.count) games")
        } catch {
 logger.error("Failed to schedule daily streak reminder: \(error.localizedDescription)")
        }
    }
    
    // MARK: - One-off Snooze Reminder
    /// Resolves a concrete local date for a one-off reminder with DST-safe behavior.
    /// Internal for unit tests.
    func resolveOneOffReminderDate(
        daysFromNow: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = Date()
    ) -> Date? {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        guard let targetDay = calendar.date(byAdding: .day, value: daysFromNow, to: now) else { return nil }

        let startOfTargetDay = calendar.startOfDay(for: targetDay)
        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: startOfTargetDay,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    /// Builds calendar components for one-off reminders from a DST-safe resolved date.
    /// Internal for unit tests.
    func makeOneOffReminderDateComponents(
        daysFromNow: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = Date()
    ) -> DateComponents? {
        guard let date = resolveOneOffReminderDate(
            daysFromNow: daysFromNow,
            hour: hour,
            minute: minute,
            calendar: calendar,
            now: now
        ) else {
            return nil
        }
        return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .timeZone], from: date)
    }

    func scheduleOneOffSnoozeReminder(games: [Game], daysFromNow: Int, hour: Int, minute: Int) async {
        guard await checkPermissionStatus() == .authorized else {
 logger.warning("Cannot schedule snooze: notifications not authorized")
            return
        }
        
        let content = buildStreakReminderContent(games: games)
        
        // Compute the specific date (daysFromNow) at user's preferred hour/minute.
        // Uses DST-safe resolution for nonexistent/repeated local times.
        let calendar = Calendar.autoupdatingCurrent
        guard let components = makeOneOffReminderDateComponents(
            daysFromNow: daysFromNow,
            hour: hour,
            minute: minute,
            calendar: calendar
        ) else {
 logger.error("Failed to resolve one-off snooze reminder date components")
            return
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "one_off_snooze_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
 logger.info("Scheduled one-off snooze reminder for +\(daysFromNow)d at \(hour):\(String(format: "%02d", minute)) (\(games.count) games)")
        } catch {
 logger.error("Failed to schedule one-off snooze reminder: \(error.localizedDescription)")
        }
    }
    
    func cancelDailyStreakReminder() async {
        center.removePendingNotificationRequests(withIdentifiers: ["daily_streak_reminder"])
 logger.info("Cancelled daily streak reminder")
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
 logger.info("Cancelled \(streakReminderIds.count) legacy streak reminders")
        }
    }

    // MARK: - Cancellation
    
    func cancelAllNotifications() async {
        center.removeAllPendingNotificationRequests()
 logger.info("Cancelled all pending notifications")
    }
    
    
    
    // MARK: - Settings Management
    
    /// Clean up all existing notifications before applying new settings
    /// This prevents accumulation of old notifications when settings change
    func cleanupAndRescheduleNotifications() async {
 logger.info("Cleaning up streak reminders before rescheduling...")
        
        let pendingRequests = await center.pendingNotificationRequests()
        let idsToRemove = pendingRequests.compactMap { request in
            if request.identifier == "daily_streak_reminder" { return request.identifier }
            if request.identifier.hasPrefix("one_off_snooze_") { return request.identifier }
            return nil
        }
        
        if !idsToRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
 logger.info("Removed \(idsToRemove.count) streak reminder notifications before rescheduling")
        } else {
 logger.info("ℹ No streak-related notifications to clean up")
        }
    }
    
    /// Debug method to log current notification state
    func logCurrentNotificationState() async {
        let pendingRequests = await center.pendingNotificationRequests()
 logger.info("Current notification state: \(pendingRequests.count) pending notifications")
        
        for request in pendingRequests {
            let triggerDescription: String
            if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
                triggerDescription = "Calendar: \(calendarTrigger.dateComponents)"
            } else if let intervalTrigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                triggerDescription = "Interval: \(intervalTrigger.timeInterval)s"
            } else {
                triggerDescription = "Unknown trigger type"
            }
            
 logger.info("\(request.identifier): \(request.content.title) - \(triggerDescription)")
        }
    }
    
    // MARK: - Test Methods
    #if DEBUG
    func scheduleTestDailyReminder(games: [Game]) async {
        guard await checkPermissionStatus() == .authorized else { return }
        
        let content = UNMutableNotificationContent()
        
        if games.count == 1 {
            content.title = "🧪 Test Streak Reminder"
            content.body = "Don't lose your \(games[0].displayName) streak"
        } else {
            let names = games.map { $0.displayName }.joined(separator: ", ")
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
 logger.info("Scheduled test daily reminder for \(games.count) games")
        } catch {
 logger.error("Failed to schedule test reminder: \(error.localizedDescription)")
        }
    }
    
    #endif
    
}

