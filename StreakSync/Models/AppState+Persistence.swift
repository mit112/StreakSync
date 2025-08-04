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
    private var syncCoordinator: AppGroupSyncCoordinator {
        // Create on demand - lightweight object
        AppGroupSyncCoordinator()
    }
    
    // In your existing AppState implementation, update the loadPersistedData method:

    func loadPersistedData() async {
        setLoading(true)
        defer { setLoading(false) }
        
        logger.info("🔄 Loading persisted data...")
        
        // Load game results
        await loadGameResults()
        
        // Load legacy achievements
        await loadAchievements()
        
        // NEW: Load tiered achievements
        await loadTieredAchievements()
        
        // Load streaks
        await loadStreaks()
        
        // NEW: Initialize tiered achievements if first time
        if _tieredAchievements == nil {
            _tieredAchievements = AchievementFactory.createDefaultAchievements()
            recalculateAllTieredAchievementProgress()
            await saveTieredAchievements()
        }
        
        // Mark data as loaded
        isDataLoaded = true
        lastDataLoad = Date()
        
        // Sync from share extension
        await syncFromShareExtension()
        
        // Setup listener
        setupShareExtensionListener()
        
        logger.info("✅ Data loading complete with tiered achievements")
    }
    
    
    // MARK: - Parallel Data Loading
    private func loadAllData() async {
        async let results = loadGameResults()
        async let achievements = loadAchievements()
        async let streaks = loadStreaks()
        
        // Wait for all to complete
        _ = await (results, achievements, streaks)
    }
    
    // MARK: - Individual Loaders (Focused)
    private func loadGameResults() async {
        logger.info("Loading game results...")
        
        if let results = persistenceService.load(
            [GameResult].self,
            forKey: UserDefaultsPersistenceService.Keys.gameResults
        ) {
            let validResults = results.filter(\.isValid)
            setRecentResults(validResults.sorted { $0.date > $1.date })
            buildResultsCache()
            logger.debug("Loaded \(validResults.count) game results")
        } else {
            setRecentResults([])
        }
    }
    
    private func loadAchievements() async {
        logger.info("Loading achievements...")
        
        if let persisted = persistenceService.load(
            [Achievement].self,
            forKey: UserDefaultsPersistenceService.Keys.achievements
        ) {
            let merged = mergeAchievements(persisted: persisted, defaults: createDefaultAchievements())
            setAchievements(merged)
        } else {
            let defaults = createDefaultAchievements()
            setAchievements(defaults)
            await saveAchievements()
        }
    }
    
    private func loadStreaks() async {
        logger.info("Loading streaks...")
        
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
    
    // MARK: - Share Extension Sync
    private func syncFromShareExtension() async {
        do {
            let pendingResults = try await syncCoordinator.loadPendingResults()
            
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
                    name: Notification.Name(AppConstants.Notification.gameDataUpdated),
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
        NotificationCenter.default.addObserver(
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
    
    // MARK: - Saving Methods (Unchanged)
//    func saveAllData() async {
//        await withTaskGroup(of: Void.self) { group in
//            group.addTask { await self.saveGameResults() }
//            group.addTask { await self.saveAchievements() }
//            group.addTask { await self.saveStreaks() }
//        }
//    }

    
    func saveGameResults() async {
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
    
    func saveAchievements() async {
        do {
            try persistenceService.save(
                self.achievements,
                forKey: UserDefaultsPersistenceService.Keys.achievements
            )
        } catch {
            handleSaveError(error, dataType: "achievements")
        }
    }
    
    func saveStreaks() async {
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
    
    private func ensureStreaksForAllGames(_ streaks: [GameStreak]) -> [GameStreak] {
        var result = streaks
        
        for game in games {
            if !result.contains(where: { $0.gameId == game.id }) {
                result.append(GameStreak.empty(for: game))
            }
        }
        
        return result
    }
    
    private func mergeAchievements(persisted: [Achievement], defaults: [Achievement]) -> [Achievement] {
        var result = defaults
        
        for persistedAchievement in persisted {
            if let index = result.firstIndex(where: { $0.id == persistedAchievement.id }) {
                result[index] = persistedAchievement
            }
        }
        
        return result
    }
    
    // MARK: - Data Management
    func clearAllData() async {
        setRecentResults([])
        setAchievements(createDefaultAchievements())
        setStreaks(games.map { GameStreak.empty(for: $0) })
        gameResultsCache.removeAll()
        
        persistenceService.clearAll()
        invalidateCache()
        
        logger.info("🗑️ Cleared all app data")
    }
    
    func refreshData() async {
        guard !isLoading else { return }
        await loadPersistedData()
    }
}
