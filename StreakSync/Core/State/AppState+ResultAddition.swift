//
//  AppState+ResultAddition.swift
//  StreakSync
//
//  Game result insertion logic and social publishing extracted from AppState
//

import Foundation

extension AppState {

    // MARK: - Result Addition

    /// Adds a game result, returning whether it was actually added (false if invalid/duplicate).
    /// This is the single authoritative method for result insertion — all callers should use this.
    @discardableResult
    func addGameResult(_ result: GameResult) -> Bool {
        guard result.isValid else {
 logger.warning("Attempted to add invalid game result")
            return false
        }

        // Enhanced duplicate check
        guard !isDuplicateResult(result) else {
 logger.debug("Skipping duplicate result: \(result.gameName) - \(result.displayScore)")
            return false
        }

        // In Guest Mode, enforce a simple upper bound on in-memory guest
        // results to avoid unbounded memory growth.
        if isGuestMode && recentResults.count >= 100 {
 logger.warning("Guest Mode result limit reached (100) – rejecting additional guest results")
            return false
        }

        // Add result
        self.recentResults.insert(result, at: 0)

        // Update unique games ever cache (monotonic)
        do {
            var set = self.uniqueGamesEver
            let inserted = set.insert(result.gameId).inserted
            if inserted {
                self.uniqueGamesEver = set
            }
        }

        // Update duplicate-prevention cache
        updateResultsCache(for: result)

        // Update streak SYNCHRONOUSLY (host mode only)
        if !isGuestMode {
            updateStreak(for: result)
        }

        // Check for new achievements (tiered-only, host mode only)
        if !isGuestMode {
            checkAchievements(for: result)
        }

        // Invalidate UI cache
        invalidateCache()

        // Post notifications synchronously to prevent race conditions
        postResultAddedNotifications(for: result)

        // Capture logger for async tasks
        let logger = self.logger

        // Save data asynchronously
        Task {
            await saveGameResults()
            await saveStreaks()
            
            // Prune oldest results if over limit (keeps UserDefaults manageable)
            if !self.isGuestMode && self.recentResults.count > AppConstants.Storage.maxResults {
                let overflow = self.recentResults.count - AppConstants.Storage.maxResults
                self.recentResults.removeLast(overflow)
                self.buildResultsCache()
                await self.saveGameResults()
 self.logger.info("Pruned \(overflow) oldest results (limit: \(AppConstants.Storage.maxResults))")
            }
        }

 logger.info("Added game result for \(result.gameName)")

        // Check for streak risk and schedule reminders (host mode only)
        if !isGuestMode {
            Task {
                await checkAndScheduleStreakReminders()
            }
        }

        // Publish to social service (best-effort, non-blocking; host mode only)
        if !isGuestMode {
            publishScoreToSocial(result)
        } else {
 logger.warning("GUEST MODE - Score NOT published")
        }

        return true
    }

    // MARK: - Notification Posting

    private func postResultAddedNotifications(for result: GameResult) {
        // Single notification for all data changes — views observe this one event
        NotificationCenter.default.post(name: .appGameDataUpdated, object: nil)
    }

    // MARK: - Social Publishing

    private func publishScoreToSocial(_ result: GameResult) {
        // Throttle: skip if same game was published within 5 seconds
        if let lastPublish = lastScorePublishByGame[result.gameId],
           Date().timeIntervalSince(lastPublish) < 5.0 {
 logger.debug("Throttled score publish for \(result.gameName) (< 5s since last)")
            return
        }
        lastScorePublishByGame[result.gameId] = Date()
        
        let logger = self.logger

        Task { [weak self] in
            guard let self else { return }
            guard let social = self.socialService else {
 logger.warning("socialService is nil — score not published")
                return
            }
            guard let userId = social.currentUserId else {
 logger.warning("No authenticated user — score not published")
                return
            }
            let dateInt = result.date.utcYYYYMMDD
            // Look up current streak for this game
            let streak = self.streaks.first(where: { $0.gameId == result.gameId })
            let compositeId = "\(userId)|\(dateInt)|\(result.gameId.uuidString)"
            let score = DailyGameScore(
                id: compositeId,
                userId: userId,
                dateInt: dateInt,
                gameId: result.gameId,
                gameName: result.gameName,
                score: result.score,
                maxAttempts: result.maxAttempts,
                completed: result.completed,
                currentStreak: streak?.currentStreak
            )
            do {
                try await social.publishDailyScores(dateUTC: result.date, scores: [score])
 logger.info("Score published for \(result.gameName)")
            } catch {
 logger.error("Score publish failed: \(error.localizedDescription)")
            }
        }
    }
}
