//
//  AppState+Persistence.swift (REFACTORED)
//  StreakSync
//
//  Simplified persistence using coordinator pattern
//

import Foundation
import OSLog

// MARK: - AppState Persistence Extension
extension AppState {
    
    // MARK: - Dependencies
    // Removed stored/computed coordinator to avoid sending non-Sendable self across actors.
    
    // In your existing AppState implementation, update the loadPersistedData method:

    func loadPersistedData() async {
        // In Guest Mode we never reload host data from persistence; the guest
        // session operates purely in memory and is managed by GuestSessionManager.
        if isGuestMode {
            logger.info("🧑‍🤝‍🧑 Guest Mode active – skipping loadPersistedData()")
            return
        }
        // Debounce/guard: avoid overlapping or rapid back-to-back loads
        if isLoading {
            logger.debug("⏭️ Skipping loadPersistedData - already loading")
            return
        }
        if let last = lastDataLoad, Date().timeIntervalSince(last) < 1.0 {
            logger.debug("⏭️ Skipping loadPersistedData - called too soon")
            return
        }
        self.loadCountSinceLaunch += 1
        logger.debug("📈 loadPersistedData invoked (count since launch: \(self.loadCountSinceLaunch))")
        
        setLoading(true)
        defer { setLoading(false) }
        
        logger.info("🔄 Loading persisted data...")
        
        // Migrate notification settings to simplified system
        migrateNotificationSettings()
        
        // Use parallel loading for better performance
        await loadAllData()
        
        // Fix existing Connections results with updated completion logic
        await fixExistingConnectionsResults()
        
        // Normalize streaks based on last played date
        await normalizeStreaksForMissedDays()
        
        // Always recompute tiered achievements from current data
        if _tieredAchievements == nil {
            _tieredAchievements = AchievementFactory.createDefaultAchievements()
        }
        recalculateAllTieredAchievementProgress()
        
        // Mark data as loaded
        isDataLoaded = true
        lastDataLoad = Date()
        
        // Share Extension ingestion is handled by AppGroupBridge (event-driven); no direct sync here
        
        logger.info("✅ Data loading complete with tiered achievements")
    }
    
    
    // MARK: - Parallel Data Loading
    private func loadAllData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadGameResults() }
            group.addTask { await self.loadStreaks() }
        }
    }
    
    private func loadGameResults() async {
        logger.debug("Loading game results...")
        
        if let results = persistenceService.load(
            [GameResult].self,
            forKey: UserDefaultsPersistenceService.Keys.gameResults
        ) {
            let validResults = results.filter { $0.isValid }
            setRecentResults(validResults.sorted { $0.date > $1.date })
            buildResultsCache()
            logger.debug("Loaded \(validResults.count) game results")
        } else {
            setRecentResults([])
        }
    }
    
    private func loadStreaks() async {
        logger.debug("Loading streaks...")
        
        if let persisted = persistenceService.load(
            [GameStreak].self,
            forKey: UserDefaultsPersistenceService.Keys.streaks
        ) {
            let validStreaks = persisted.filter { streak in
                streak.currentStreak >= 0 &&
                streak.totalGamesPlayed >= streak.totalGamesCompleted
            }
            setStreaks(ensureStreaksForAllGames(validStreaks))
        } else {
            let emptyStreaks = games.map { GameStreak.empty(for: $0) }
            setStreaks(emptyStreaks)
            await saveStreaks()
        }
    }

    // MARK: - Streak Normalization
    /// Resets streaks that are no longer active (missed a full day)
    /// FIXED: Only reset streaks if they were actually broken by missing a day,
    /// not just because time has passed since the last play
    @MainActor
    func normalizeStreaksForMissedDays(referenceDate: Date = Date()) async {
        let calendar = Calendar.current
        
        // Pre-index: build a set of days with completed results per game (O(n) once)
        var completedDaysByGame: [UUID: Set<Date>] = [:]
        for result in recentResults where result.completed {
            let day = calendar.startOfDay(for: result.date)
            completedDaysByGame[result.gameId, default: []].insert(day)
        }
        
        var updated: [GameStreak] = []
        var didChange = false
        
        for streak in streaks {
            guard streak.currentStreak > 0, let lastPlayed = streak.lastPlayedDate else {
                updated.append(streak)
                continue
            }
            
            let completedDays = completedDaysByGame[streak.gameId] ?? []
            let shouldBreak = hasGapInStreak(
                completedDays: completedDays,
                lastPlayedDate: lastPlayed,
                referenceDate: referenceDate,
                calendar: calendar
            )
            
            if shouldBreak {
                let reset = GameStreak(
                    id: streak.id,
                    gameId: streak.gameId,
                    gameName: streak.gameName,
                    currentStreak: 0,
                    maxStreak: streak.maxStreak,
                    totalGamesPlayed: streak.totalGamesPlayed,
                    totalGamesCompleted: streak.totalGamesCompleted,
                    lastPlayedDate: streak.lastPlayedDate,
                    streakStartDate: nil
                )
                updated.append(reset)
                didChange = true
                logger.info("🔥 Breaking streak for \(streak.gameName) - missed day detected")
            } else {
                updated.append(streak)
            }
        }
        
        if didChange {
            setStreaks(updated)
            await saveStreaks()
            invalidateCache()
            logger.info("🔥 Normalized streaks for missed days (some streaks reset)")
        }
    }
    
    /// O(days) check using pre-indexed set of completed days.
    private func hasGapInStreak(
        completedDays: Set<Date>,
        lastPlayedDate: Date,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        let startOfLastPlayed = calendar.startOfDay(for: lastPlayedDate)
        let startOfReference = calendar.startOfDay(for: referenceDate)
        guard completedDays.isEmpty == false else { return false }
        
        var currentDate = startOfLastPlayed
        while currentDate < startOfReference {
            if !completedDays.contains(currentDate) {
                return true
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        return false
    }
    
    // MARK: - Share Extension Sync
    private func syncFromShareExtension() async {
        // Ignore share extension ingestion while Guest Mode is active – host
        // data is hidden and guest sessions should not mutate it.
        if isGuestMode {
            logger.info("🧑‍🤝‍🧑 Guest Mode active – ignoring Share Extension sync")
            return
        }
        do {
            // Create the coordinator locally to avoid capturing self into a stored property
            let coordinator = AppGroupSyncCoordinator()
            let pendingResults = try await coordinator.loadPendingResults()
            
            for result in pendingResults {
                // addGameResult already handles everything
                addGameResult(result)
            }
            
            if !pendingResults.isEmpty {
                logger.info("✅ Processed \(pendingResults.count) results from Share Extension")
                
                // Force UI refresh
                invalidateCache()
                
                // Post update notification
                NotificationCenter.default.post(
                    name: .appGameDataUpdated,
                    object: nil
                )
            }
        } catch {
            logger.error("Share Extension sync failed: \(error)")
            // Non-critical - don't show error to user
        }
    }
    
    // MARK: - Share Extension Listener
    private func setupShareExtensionListener() {
        shareExtensionObserver = NotificationCenter.default.addObserver(
            forName: .init(AppConstants.Notification.shareExtensionResultAvailable),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                logger.info("📱 Received Share Extension notification")
                await self.syncFromShareExtension()
                
                // Tell AppGroupBridge we handled it
                AppGroupBridge.shared.clearLatestResult()
            }
        }
    }
    
    
    func saveGameResults() async {
        // In Guest Mode we never persist results to disk – the guest session
        // lives only in memory and is managed by GuestSessionManager.
        if isGuestMode {
            logger.debug("🧑‍🤝‍🧑 Guest Mode active – skipping saveGameResults()")
            return
        }
        do {
            try persistenceService.save(
                self.recentResults,
                forKey: UserDefaultsPersistenceService.Keys.gameResults
            )
            logger.debug("Saved \(self.recentResults.count) game results")
        } catch {
            handleSaveError(error, dataType: "game results")
        }
    }
    
    func saveStreaks() async {
        // In Guest Mode we never persist streaks – host streaks are preserved
        // in memory and restored when Guest Mode exits.
        if isGuestMode {
            logger.debug("🧑‍🤝‍🧑 Guest Mode active – skipping saveStreaks()")
            return
        }
        do {
            try persistenceService.save(
                self.streaks,
                forKey: UserDefaultsPersistenceService.Keys.streaks
            )
        } catch {
            handleSaveError(error, dataType: "streaks")
        }
    }
    
    // MARK: - Helper Methods
    private func handleSaveError(_ error: Error, dataType: String) {
        if let appError = error as? AppError {
            setError(appError)
        } else {
            setError(AppError.persistence(.saveFailed(
                dataType: dataType,
                underlying: error
            )))
        }
    }
    
    internal func ensureStreaksForAllGames(_ streaks: [GameStreak]) -> [GameStreak] {
        var result = streaks
        
        for game in games {
            if !result.contains(where: { $0.gameId == game.id }) {
                result.append(GameStreak.empty(for: game))
            }
        }
        
        return result
    }
    
    // MARK: - Data Management
    func clearAllData() async {
        setRecentResults([])
        // Clear tiered achievements to defaults and save
        _tieredAchievements = AchievementFactory.createDefaultAchievements()
        await saveTieredAchievements()
        setStreaks(games.map { GameStreak.empty(for: $0) })
        gameResultsCache.removeAll()
        
        persistenceService.clearAll()
        invalidateCache()
        
        logger.info("🗑️ Cleared all app data")
    }
    
    func refreshData() async {
        guard !isLoading else { return }
        if isGuestMode {
            logger.info("🧑‍🤝‍🧑 Guest Mode active – skipping refreshData()")
            return
        }
        
        // Refresh games first to pick up any new games
        refreshGames()
        
        // Reload persisted data
        await loadPersistedData()
        
        // Self-heal streaks from the authoritative source of truth (recentResults)
        // and then normalize them up to "today" so gaps correctly break streaks.
        await rebuildStreaksFromResults()
        await normalizeStreaksForMissedDays()
    }
    
    /// Lightweight data refresh for notification navigation - skips expensive operations
    func refreshDataForNotification() async {
        guard !isLoading else { return }
        if isGuestMode {
            logger.info("🧑‍🤝‍🧑 Guest Mode active – skipping refreshDataForNotification()")
            return
        }
        
        logger.info("🚀 Lightweight data refresh for notification navigation")
        
        // Only load essential data, skip expensive operations
        await loadGameResults()
        await loadStreaks()
        
        // Skip tiered achievements recomputation and other expensive operations
        logger.info("✅ Lightweight data refresh complete")
    }
}
