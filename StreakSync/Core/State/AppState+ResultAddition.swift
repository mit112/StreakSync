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

        // Capture state BEFORE insert for first-share celebration detection
        let celebrationFlagSeen = UserDefaults.standard.bool(forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration)
        let shouldFireCelebration = ShareDiscoveryGate.shouldFireCelebration(
            preInsertCount: self.recentResults.count,
            hasSeen: celebrationFlagSeen,
            isGuest: self.isGuestMode
        )

        // Add result
        self.recentResults.insert(result, at: 0)

        // Update unique games ever cache (monotonic, host mode only)
        if !isGuestMode {
            var set = self.uniqueGamesEver
            let inserted = set.insert(result.gameId).inserted
            if inserted {
                self.uniqueGamesEver = set
            }
        }

        // Update duplicate-prevention cache
        updateResultsCache(for: result)

        // Record the day in the monotonic lifetime set, which outlives result pruning
        recordActiveDays(from: [result])

        // Update streak SYNCHRONOUSLY (host mode only)
        if !isGuestMode {
            updateStreak(for: result)
        }

        // Check for new achievements (tiered-only, host mode only)
        if !isGuestMode {
            checkAchievements()
        }

        // Invalidate UI cache
        invalidateCache()

        // Post notifications synchronously to prevent race conditions
        postResultAddedNotifications(for: result)

        // First-share celebration — fires exactly once on the 0→1 transition (host mode)
        if shouldFireCelebration {
            UserDefaults.standard.set(true, forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration)
            NotificationCenter.default.post(
                name: .appFirstShareCelebrationRequested,
                object: nil,
                userInfo: ["gameName": result.gameName]
            )
        }

        // Capture logger for async tasks
        let logger = self.logger

        // A result dated anything other than today can't be handled by the incremental
        // `updateStreak` above: that path only starts or extends a streak from the newest
        // play. A backdated result therefore starts a phantom "active" streak for a game
        // last played days ago (and publishes it to the leaderboard), while a result that
        // genuinely fills a gap never extends the streak it completes. Both need a rebuild.
        let needsFullRecompute = !isGuestMode && !Calendar.current.isDateInToday(result.date)

        // Save data asynchronously
        Task {
            await saveGameResults()
            await saveStreaks()

            // Prune oldest results if over limit (keeps UserDefaults manageable)
            var didPrune = false
            if !self.isGuestMode && self.recentResults.count > AppConstants.Storage.maxResults {
                let before = self.recentResults.count
                self.recentResults = GameResultSyncMerge.pruneToCap(
                    self.recentResults, limit: AppConstants.Storage.maxResults
                )
                self.buildResultsCache()
                await self.saveGameResults()
                didPrune = true
 self.logger.info("Pruned \(before - self.recentResults.count) oldest results (limit: \(AppConstants.Storage.maxResults))")
            }

            // Pruning drops results that streaks and achievements were derived from, so both
            // must be recomputed against what actually remains.
            if needsFullRecompute || didPrune {
                await self.reconcileAfterResultSetChanged()
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

    // MARK: - Social Retraction

    /// Removes a previously published score from friends' leaderboards (best-effort).
    internal func retractScoreFromSocial(date: Date, gameId: UUID) {
        guard !isGuestMode else { return }
        // Clear the throttle so an immediately following republish is never suppressed.
        lastScorePublishByGame[gameId] = nil

        let logger = self.logger
        Task { [weak self] in
            guard let self, let social = self.socialService else { return }
            do {
                try await social.deleteDailyScore(dateUTC: date, gameId: gameId)
            } catch {
 logger.error("Score retraction failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Social Publishing

    internal func publishScoreToSocial(_ result: GameResult) {
        // Throttle duplicate publishes of the SAME payload. Keying on game alone meant a
        // correction saved within 5s of the original share was silently dropped, leaving the
        // wrong score on the leaderboard permanently — so the signature must be part of it.
        let signature = "\(result.date.utcYYYYMMDD)|\(result.score.map(String.init) ?? "-")|\(result.completed)"
        if let last = lastScorePublishByGame[result.gameId],
           last.signature == signature,
           Date().timeIntervalSince(last.date) < 5.0 {
 logger.debug("Throttled duplicate score publish for \(result.gameName) (< 5s since identical publish)")
            return
        }
        lastScorePublishByGame[result.gameId] = (date: Date(), signature: signature)
        
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
