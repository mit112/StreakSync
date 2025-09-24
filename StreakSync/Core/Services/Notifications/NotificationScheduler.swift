//
//  NotificationScheduler.swift
//  StreakSync
//
//  Smart notification scheduling with frequency caps and quiet hours
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
final class NotificationScheduler: ObservableObject {
    static let shared = NotificationScheduler()
    
    // MARK: - Properties
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.streaksync.app", category: "NotificationScheduler")
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Settings Keys
    private enum SettingsKeys {
        static let quietHoursEnabled = "notificationQuietHoursEnabled"
        static let quietHoursStart = "notificationQuietHoursStart"
        static let quietHoursEnd = "notificationQuietHoursEnd"
        static let enableDigest = "enableNotificationDigest"
        static let lastNotificationDate = "lastNotificationDate"
        static let dailyNotificationCount = "dailyNotificationCount"
    }
    
    // MARK: - Default Settings
    private let defaultQuietHoursStart = 21 // 9 PM
    private let defaultQuietHoursEnd = 9    // 9 AM
    
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
    
    // MARK: - Streak Reminders
    func scheduleImmediateStreakReminder(for game: Game, in seconds: Int = 3) async {
        guard await checkPermissionStatus() == .authorized else {
            logger.warning("⚠️ Cannot schedule reminder: notifications not authorized")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "\(game.name) Streak Reminder"
        content.body = "Keep your streak alive! Play now to maintain your progress."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streakReminder.identifier
        content.userInfo = [
            "gameId": game.id.uuidString,
            "gameName": game.name,
            "type": "streak_reminder"
        ]
        
        // Schedule for immediate delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: "immediate_streak_\(game.id.uuidString)_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            logger.info("✅ Scheduled immediate streak reminder for \(game.name) in \(seconds) seconds")
        } catch {
            logger.error("❌ Failed to schedule immediate streak reminder: \(error.localizedDescription)")
        }
    }
    
    func scheduleStreakReminder(for game: Game, at preferredTime: Date) async {
        guard await checkPermissionStatus() == .authorized else {
            logger.warning("⚠️ Cannot schedule reminder: notifications not authorized")
            return
        }
        
        
        let content = UNMutableNotificationContent()
        content.title = "\(game.name) Streak Reminder"
        content.body = "Keep your streak alive! Play now to maintain your progress."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streakReminder.identifier
        content.userInfo = [
            "gameId": game.id.uuidString,
            "gameName": game.name,
            "type": "streak_reminder"
        ]
        
        // Schedule for preferred time, respecting quiet hours
        let scheduledTime = adjustedDeliveryDate(for: preferredTime)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.hour, .minute], from: scheduledTime),
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "streak_\(game.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            logger.info("✅ Scheduled streak reminder for \(game.name) at \(scheduledTime)")
        } catch {
            logger.error("❌ Failed to schedule streak reminder: \(error.localizedDescription)")
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
    
    /// Schedule a one-time end-of-day reminder (9 PM local time) for a game
    func scheduleEndOfDayStreakReminder(for game: Game, now: Date = Date()) async {
        guard await checkPermissionStatus() == .authorized else {
            logger.warning("⚠️ Cannot schedule EOD reminder: notifications not authorized")
            return
        }
        
        // Build content
        let content = UNMutableNotificationContent()
        content.title = "Don't lose your \(game.name) streak"
        content.body = "The day is almost over. Play now to keep your streak alive."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streakReminder.identifier
        content.userInfo = [
            "gameId": game.id.uuidString,
            "gameName": game.name,
            "type": "streak_reminder_eod"
        ]
        
        // Determine 9 PM today, or if past 9 PM, schedule in 5 minutes
        let calendar = Calendar.current
        let ninePMToday = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now) ?? now
        let triggerDate: Date
        if now < ninePMToday {
            triggerDate = ninePMToday
        } else {
            triggerDate = now.addingTimeInterval(5 * 60)
        }
        
        // Do NOT apply quiet hours to EOD reminders; they intentionally happen late
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // Use a deterministic identifier per day so we can replace if needed
        let dayKey = calendar.startOfDay(for: now).timeIntervalSince1970
        let identifier = "eod_streak_\(game.id.uuidString)_\(Int(dayKey))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            // Remove previous EOD reminder for today before adding
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            try await center.add(request)
            logger.info("✅ Scheduled EOD streak reminder for \(game.name) at \(triggerDate)")
        } catch {
            logger.error("❌ Failed to schedule EOD streak reminder: \(error.localizedDescription)")
        }
    }
    
    /// Cancel today's end-of-day reminder for a game, if any
    func cancelTodayEndOfDayStreakReminder(for gameId: UUID, now: Date = Date()) {
        let dayKey = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)
        let identifier = "eod_streak_\(gameId.uuidString)_\(dayKey)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        logger.info("🗑️ Cancelled today's EOD reminder for game \(gameId)")
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
    func cancelStreakReminder(for gameId: UUID) async {
        center.removePendingNotificationRequests(withIdentifiers: ["streak_\(gameId.uuidString)"])
        logger.info("🗑️ Cancelled streak reminder for game \(gameId)")
    }
    
    func cancelAllNotifications() async {
        center.removeAllPendingNotificationRequests()
        logger.info("🗑️ Cancelled all pending notifications")
    }
    
    // MARK: - Settings Management
    func setQuietHours(enabled: Bool, start: Int, end: Int) {
        userDefaults.set(enabled, forKey: SettingsKeys.quietHoursEnabled)
        userDefaults.set(start, forKey: SettingsKeys.quietHoursStart)
        userDefaults.set(end, forKey: SettingsKeys.quietHoursEnd)
        logger.info("🔇 Set quiet hours: \(enabled ? "enabled" : "disabled") \(enabled ? "\(start):00 - \(end):00" : "")")
    }
    
    func setDigestEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: SettingsKeys.enableDigest)
        logger.info("📧 Set digest enabled: \(enabled)")
    }
    
    // MARK: - Private Helpers
    private func setupDefaultSettings() {
        if userDefaults.object(forKey: SettingsKeys.quietHoursEnabled) == nil {
            userDefaults.set(false, forKey: SettingsKeys.quietHoursEnabled)
        }
        if userDefaults.object(forKey: SettingsKeys.quietHoursStart) == nil {
            userDefaults.set(defaultQuietHoursStart, forKey: SettingsKeys.quietHoursStart)
        }
        if userDefaults.object(forKey: SettingsKeys.quietHoursEnd) == nil {
            userDefaults.set(defaultQuietHoursEnd, forKey: SettingsKeys.quietHoursEnd)
        }
        if userDefaults.object(forKey: SettingsKeys.enableDigest) == nil {
            userDefaults.set(false, forKey: SettingsKeys.enableDigest)
        }
    }
    
    
    func adjustedDeliveryDate(for date: Date) -> Date {
        let quietHoursEnabled = userDefaults.bool(forKey: SettingsKeys.quietHoursEnabled)
        
        // If quiet hours are disabled, return the original date
        guard quietHoursEnabled else { return date }
        
        let quietStart = userDefaults.integer(forKey: SettingsKeys.quietHoursStart)
        let quietEnd = userDefaults.integer(forKey: SettingsKeys.quietHoursEnd)
        
        let hour = Calendar.current.component(.hour, from: date)
        
        // If time falls within quiet hours, move to end of quiet period
        if hour >= quietStart || hour < quietEnd {
            var adjustedDate = date
            if hour >= quietStart {
                // Move to next day at end of quiet period
                adjustedDate = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
            }
            adjustedDate = Calendar.current.date(bySettingHour: quietEnd, minute: 0, second: 0, of: adjustedDate) ?? date
            return adjustedDate
        }
        
        return date
    }
}
