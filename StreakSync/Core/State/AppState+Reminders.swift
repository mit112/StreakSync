//
//  AppState+Reminders.swift
//  StreakSync
//
//  Streak reminder scheduling extracted from AppState
//

import Foundation

extension AppState {
    // MARK: - Streak Risk Detection & Reminders

    func checkAndScheduleStreakReminders() async {
        // Check if reminders are enabled globally
        let remindersEnabled = UserDefaults.standard.bool(forKey: AppConstants.NotificationSettings.remindersEnabled)
        guard remindersEnabled else {
            await NotificationScheduler.shared.cancelAllStreakReminders()
            logger.info("Streak reminders disabled - cancelled all notifications")
            return
        }

        // Get user's preferred time
        let preferredHour = UserDefaults.standard.object(forKey: AppConstants.NotificationSettings.reminderHour) as? Int ?? 19
        let preferredMinute = UserDefaults.standard.object(forKey: AppConstants.NotificationSettings.reminderMinute) as? Int ?? 0

        // Respect an active snooze: keep the daily reminder suppressed until it elapses.
        // The daily was already cancelled at snooze time; resume only once the window passes.
        if let snoozedUntil = UserDefaults.standard.object(forKey: AppConstants.NotificationSettings.snoozedUntil) as? Date {
            if snoozedUntil > Date() {
                logger.info("Reminder snoozed until \(snoozedUntil) - skipping daily reminder scheduling")
                return
            }
            UserDefaults.standard.removeObject(forKey: AppConstants.NotificationSettings.snoozedUntil)
        }

        // Find all games at risk (active streaks, not played today)
        let gamesAtRisk = getGamesAtRisk()

        // Debounce/coalesce: if the set of at-risk games AND the preferred time haven't
        // changed and we scheduled recently, skip. Including hour/minute ensures a reminder-
        // time change in Settings within the debounce window isn't silently dropped.
        let signature = "\(preferredHour):\(preferredMinute)|"
            + gamesAtRisk.map(\.id.uuidString).sorted().joined(separator: "|")
        let now = Date()
        if let lastSig = lastAtRiskGamesSignature,
           lastSig == signature,
           let lastAt = lastReminderScheduleAt,
           now.timeIntervalSince(lastAt) < 300 { // 5 minutes
            logger.debug("Skipping reminder reschedule (unchanged within debounce window)")
            return
        }

        logger.info("Found \(gamesAtRisk.count) games at risk: \(gamesAtRisk.map { $0.name }.joined(separator: ", "))")

        if gamesAtRisk.isEmpty {
            await NotificationScheduler.shared.cancelDailyStreakReminder()
            logger.debug("No games at risk - cancelled daily reminder")
        } else {
            await NotificationScheduler.shared.scheduleDailyStreakReminder(
                games: gamesAtRisk,
                hour: preferredHour,
                minute: preferredMinute
            )
            logger.info("Scheduled daily reminder at \(preferredHour):\(String(format: "%02d", preferredMinute)) for \(gamesAtRisk.count) games")
        }

        lastAtRiskGamesSignature = signature
        lastReminderScheduleAt = now
    }

    func getGamesAtRisk() -> [Game] {
        let calendar = Calendar.current
        let now = Date()

        var atRiskGames: [Game] = []

        for game in games {
            // Check if game has active streak
            guard let streak = streaks.first(where: { $0.gameId == game.id }),
                  streak.currentStreak > 0 else {
                continue
            }

            // Check if user played today
            let hasPlayedToday = recentResults.contains { result in
                result.gameId == game.id &&
                calendar.isDate(result.date, inSameDayAs: now) &&
                result.completed
            }

            if !hasPlayedToday {
                atRiskGames.append(game)
            }
        }

        return atRiskGames
    }

    // MARK: - Migration Helper

    func migrateNotificationSettings() async {
        let migrationKey = AppConstants.NotificationSettings.migrationCompleted

        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            return
        }

        // Clean up all old notification requests
        await NotificationScheduler.shared.cancelAllNotifications()

        // Set default values for new system
        UserDefaults.standard.set(true, forKey: AppConstants.NotificationSettings.remindersEnabled)

        // Use smart default time based on user's play patterns
        let smartTime = calculateSmartDefaultTime()
        UserDefaults.standard.set(smartTime.hour, forKey: AppConstants.NotificationSettings.reminderHour)
        UserDefaults.standard.set(smartTime.minute, forKey: AppConstants.NotificationSettings.reminderMinute)

        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: migrationKey)

        logger.info("""
            Migrated to simplified notification system with smart default time: \
            \(smartTime.hour):\(String(format: "%02d", smartTime.minute))
            """)
    }

    /// Calculate smart default time based on user's typical play patterns
    internal func calculateSmartDefaultTime() -> (hour: Int, minute: Int) {
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now

        let recentResults = self.recentResults.filter { result in
            result.date >= thirtyDaysAgo && result.completed
        }

        guard !recentResults.isEmpty else {
            return (hour: 19, minute: 0)
        }

        let playHours = recentResults.map { result in
            calendar.component(.hour, from: result.date)
        }

        let hourCounts = Dictionary(grouping: playHours, by: { $0 })
        let mostCommonHour = hourCounts.max(by: { $0.value.count < $1.value.count })?.key ?? 19

        let reminderHour = max(6, mostCommonHour - 2)

        logger.info("Smart default time: Most common play hour: \(mostCommonHour), Setting reminder for: \(reminderHour):00")

        return (hour: reminderHour, minute: 0)
    }
}
