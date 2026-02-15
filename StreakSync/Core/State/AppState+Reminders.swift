//
//  AppState+Reminders.swift
//  StreakSync
//
//  Streak reminder scheduling and smart reminder engine extracted from AppState
//

import Foundation

extension AppState {

    // MARK: - Streak Risk Detection & Reminders

    func checkAndScheduleStreakReminders() async {
        // Check if reminders are enabled globally
        let remindersEnabled = UserDefaults.standard.bool(forKey: "streakRemindersEnabled")
        guard remindersEnabled else {
            await NotificationScheduler.shared.cancelAllStreakReminders()
 logger.info("Streak reminders disabled - cancelled all notifications")
            return
        }

        // Get user's preferred time
        let preferredHour = UserDefaults.standard.object(forKey: "streakReminderHour") as? Int ?? 19
        let preferredMinute = UserDefaults.standard.object(forKey: "streakReminderMinute") as? Int ?? 0

        // Find all games at risk (active streaks, not played today)
        let gamesAtRisk = getGamesAtRisk()

        // Debounce/coalesce: if the set of at-risk games hasn't changed and we scheduled recently, skip
        let signature = gamesAtRisk.map(\.id.uuidString).sorted().joined(separator: "|")
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

    func migrateNotificationSettings() {
        let migrationKey = "notificationSystemMigrated_v2"

        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            return
        }

        // Clean up all old notification requests
        Task {
            await NotificationScheduler.shared.cancelAllNotifications()
        }

        // Set default values for new system
        UserDefaults.standard.set(true, forKey: "streakRemindersEnabled")

        // Use smart default time based on user's play patterns
        let smartTime = calculateSmartDefaultTime()
        UserDefaults.standard.set(smartTime.hour, forKey: "streakReminderHour")
        UserDefaults.standard.set(smartTime.minute, forKey: "streakReminderMinute")

        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: migrationKey)

 logger.info("Migrated to simplified notification system with smart default time: \(smartTime.hour):\(String(format: "%02d", smartTime.minute))")
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

    // MARK: - Smart Reminder Engine

    /// Computes a smart reminder suggestion based on the last N days of play and returns a best reminder time
    func computeSmartReminderSuggestion(lastDays: Int = 30) -> (hour: Int, minute: Int, windowStart: Int, windowEnd: Int, coverage: Int) {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -lastDays, to: now) ?? now
        let recent = self.recentResults.filter { $0.date >= start && $0.completed }
        guard !recent.isEmpty else { return (19, 0, 19, 21, 0) }
        var hourCounts = Array(repeating: 0, count: 24)
        for result in recent {
            let h = calendar.component(.hour, from: result.date)
            hourCounts[h] += 1
        }
        let total = hourCounts.reduce(0, +)
        var bestStart = 19
        var bestCount = -1
        for h in 0..<24 {
            let c = hourCounts[h] + hourCounts[(h + 1) % 24]
            if c > bestCount { bestCount = c; bestStart = h }
        }
        let windowStart = bestStart
        let windowEnd = (bestStart + 1) % 24
        let coverage = max(0, min(100, Int((Double(bestCount) / Double(max(1, total))) * 100.0 + 0.5)))
        var hour = (windowStart - 1 + 24) % 24
        var minute = 30
        if hour < 6 { hour = 6; minute = 0 }
        if hour > 22 { hour = 22; minute = 0 }
        return (hour, minute, windowStart, windowEnd, coverage)
    }

    /// Updates smart reminders if enabled and last computation was over 2 days ago
    func updateSmartRemindersIfNeeded() async {
        let defaults = UserDefaults.standard
        let smartOn = defaults.bool(forKey: "smartRemindersEnabled")
        guard smartOn else { return }
        let last = defaults.object(forKey: "smartRemindersLastComputed") as? Date
        let twoDays: TimeInterval = 60 * 60 * 24 * 2
        if let last, Date().timeIntervalSince(last) < twoDays { return }
        await applySmartReminderNow()
    }

    /// Computes and applies smart reminder immediately (and schedules notifications)
    func applySmartReminderNow() async {
        let suggestion = computeSmartReminderSuggestion()
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "streakRemindersEnabled")
        defaults.set(true, forKey: "smartRemindersEnabled")
        defaults.set(Date(), forKey: "smartRemindersLastComputed")
        defaults.set(suggestion.hour, forKey: "streakReminderHour")
        defaults.set(suggestion.minute, forKey: "streakReminderMinute")
        defaults.set(suggestion.windowStart, forKey: "smartReminderWindowStartHour")
        defaults.set(suggestion.windowEnd, forKey: "smartReminderWindowEndHour")
        defaults.set(suggestion.coverage, forKey: "smartReminderCoveragePercent")
        await checkAndScheduleStreakReminders()
 logger.info("Applied smart reminder: \(suggestion.hour):\(String(format: "%02d", suggestion.minute)) window \(suggestion.windowStart)-\(suggestion.windowEnd) coverage \(suggestion.coverage)%")
    }
}
