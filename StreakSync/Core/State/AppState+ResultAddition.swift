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
            logger.info("Skipping duplicate result: \(result.gameName) - \(result.displayScore)")
            return false
        }

        // In Guest Mode, enforce a simple upper bound on in-memory guest
        // results to avoid unbounded memory growth.
        if isGuestMode && recentResults.count >= 100 {
            logger.warning("🧑‍🤝‍🧑 Guest Mode result limit reached (100) – rejecting additional guest results")
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
            logger.info("✅ SAVED ALL: Game result, streaks, and tiered achievements for \(result.gameName)")
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
            logger.warning("⚠️ GUEST MODE - Score NOT published")
        }

        return true
    }

    // MARK: - Notification Posting

    private func postResultAddedNotifications(for result: GameResult) {
        logger.info("📢 Posting notifications for new result: \(result.gameName) - \(result.displayScore)")

        NotificationCenter.default.post(
            name: .appGameResultAdded,
            object: nil
        )

        NotificationCenter.default.post(
            name: .appGameDataUpdated,
            object: nil
        )

        if self.games.first(where: { $0.id == result.gameId }) != nil {
            NotificationCenter.default.post(
                name: .appRefreshGameData,
                object: nil
            )
        }

        logger.info("✅ All notifications posted successfully")
    }

    // MARK: - Social Publishing

    private func publishScoreToSocial(_ result: GameResult) {
        let logger = self.logger
        logger.info("🎯 Publishing score - isGuestMode: \(self.isGuestMode)")
        logger.info("🎯 socialService exists: \(self.socialService != nil)")

        Task { [weak self] in
            guard let self else {
                logger.error("❌ CRITICAL: self is nil in publish task")
                return
            }
            guard let social = self.socialService else {
                logger.error("❌ CRITICAL: socialService is nil!")
                return
            }
            let userId = "local_user"
            let dateInt = result.date.utcYYYYMMDD
            logger.info("📅 Score dateInt: \(dateInt), date: \(result.date)")
            logger.info("📅 Score details: game=\(result.gameName), score=\(result.score?.description ?? "nil"), completed=\(result.completed), maxAttempts=\(result.maxAttempts)")
            let compositeId = "\(userId)|\(dateInt)|\(result.gameId.uuidString)"
            let score = DailyGameScore(
                id: compositeId,
                userId: userId,
                dateInt: dateInt,
                gameId: result.gameId,
                gameName: result.gameName,
                score: result.score,
                maxAttempts: result.maxAttempts,
                completed: result.completed
            )
            do {
                try await social.publishDailyScores(dateUTC: result.date, scores: [score])
                logger.info("✅ Score published successfully")
            } catch {
                logger.error("❌ PUBLISH FAILED: \(error.localizedDescription)")
            }
        }
    }
}
