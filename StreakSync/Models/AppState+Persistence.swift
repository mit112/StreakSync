//
//  AppState+Persistence.swift
//  StreakSync
//
//  AppState extension for persistence operations
//

import Foundation
import OSLog

// MARK: - AppState Persistence Extension
extension AppState {
    
    // MARK: - Data Loading
    func loadPersistedData() async {
        logger.info("📥 Starting loadPersistedData...")
        
        setLoading(true)
        defer { setLoading(false) }
        
        // Clear any previous errors before loading
        clearError()
        
        // Load core data from persistence FIRST
        await loadGameResults()
        await loadAchievements()
        await loadStreaks()
        
        logger.info("📥 Core data loaded, now checking App Group...")
        
        // Load any pending data from Share Extension LAST
        // This ensures any updates happen AFTER we've loaded the base data
        await loadFromAppGroup()
        
        isDataLoaded = true
        lastDataLoad = Date()
        
        // Only log success if no errors were set
        if currentError == nil {
            logger.info("Successfully loaded persisted data")
        } else {
            logger.warning("Loaded persisted data with errors")
        }
    }
    
    private func loadGameResults() async {
        logger.info("📖 Loading game results...")
        
        do {
            if let results = persistenceService.load([GameResult].self, forKey: UserDefaultsPersistenceService.Keys.gameResults) {
                // Validate loaded data
                let validResults = results.filter { result in
                    if !result.isValid {
                        logger.warning("Invalid game result found: \(result.gameName) - skipping")
                        return false
                    }
                    return true
                }
                
                setRecentResults(validResults.sorted { $0.date > $1.date })
                logger.debug("Loaded \(validResults.count) valid game results from persistence")
                
                // Build cache after loading
                buildResultsCache()
            } else {
                // No data is not an error for first launch
                logger.info("No game results found - this is normal for first launch")
                setRecentResults([])
            }
        } catch {
            logger.error("❌ Failed to load game results: \(error.localizedDescription)")
            
            // Set error but don't crash - use empty data
            setError(AppError.persistence(.loadFailed(
                dataType: "game results",
                underlying: error
            )))
            
            // Initialize with empty data so app remains functional
            setRecentResults([])
        }
    }
    func saveAllData() async {
        await saveGameResults()
        await saveAchievements()
        await saveStreaks()
    }
    
    internal func saveGameResults() async {
        logger.info("🔄 ATTEMPTING to save \(self.recentResults.count) game results...")
        
        do {
            try persistenceService.save(self.recentResults, forKey: UserDefaultsPersistenceService.Keys.gameResults)
            logger.info("✅ SUCCESSFULLY saved \(self.recentResults.count) game results to persistence")
            
            // VERIFY the save worked by trying to load it back
            if let verification = persistenceService.load([GameResult].self, forKey: UserDefaultsPersistenceService.Keys.gameResults) {
                logger.info("✅ VERIFICATION: Successfully loaded back \(verification.count) results")
            } else {
                logger.error("❌ VERIFICATION FAILED: Could not load back saved results!")
            }
            
        } catch {
            logger.error("❌ FAILED to save game results: \(error.localizedDescription)")
            
            // Report error to user
            if let appError = error as? AppError {
                setError(appError)
            } else {
                setError(AppError.persistence(.saveFailed(
                    dataType: "game results",
                    underlying: error
                )))
            }
        }
    }
    
    func saveAchievements() async {
        logger.debug("🔄 Saving \(self.achievements.count) achievements...")
        do {
            try persistenceService.save(self.achievements, forKey: UserDefaultsPersistenceService.Keys.achievements)
            logger.debug("✅ Saved \(self.achievements.count) achievements to persistence")
        } catch {
            logger.error("❌ Failed to save achievements: \(error.localizedDescription)")
            
            // Report error to user
            if let appError = error as? AppError {
                setError(appError)
            } else {
                setError(AppError.persistence(.saveFailed(
                    dataType: "achievements",
                    underlying: error
                )))
            }
        }
    }
    
    func saveStreaks() async {
        logger.debug("🔄 Saving \(self.streaks.count) streaks...")
        
        // Log what we're actually saving
        for (index, streak) in self.streaks.enumerated() {
            logger.debug("  Streak \(index): \(streak.gameName) - current: \(streak.currentStreak), played: \(streak.totalGamesPlayed)")
        }
        
        do {
            try persistenceService.save(self.streaks, forKey: UserDefaultsPersistenceService.Keys.streaks)
            logger.debug("✅ Saved \(self.streaks.count) streaks to persistence")
        } catch {
            logger.error("❌ Failed to save streaks: \(error.localizedDescription)")
            
            // Report error to user
            if let appError = error as? AppError {
                setError(appError)
            } else {
                setError(AppError.persistence(.saveFailed(
                    dataType: "streaks",
                    underlying: error
                )))
            }
        }
    }
    
    private func loadAchievements() async {
        logger.info("📖 Loading achievements...")
        
        do {
            if let persistedAchievements = persistenceService.load([Achievement].self, forKey: UserDefaultsPersistenceService.Keys.achievements) {
                // Validate achievements data
                var hasCorruption = false
                let validAchievements = persistedAchievements.filter { achievement in
                    // Check for data corruption
                    if achievement.title.isEmpty || achievement.id == UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
                        logger.warning("Corrupt achievement found: \(achievement.id) - skipping")
                        hasCorruption = true
                        return false
                    }
                    return true
                }
                
                if hasCorruption {
                    logger.warning("Some achievements were corrupted and skipped")
                    // Don't set error for partial corruption - we recovered
                }
                
                // Merge with default achievements, preserving unlock status
                setAchievements(mergeAchievements(persisted: validAchievements, defaults: createDefaultAchievements()))
                logger.debug("Loaded \(validAchievements.count) achievements from persistence")
            } else {
                // No persisted achievements - use defaults
                logger.info("No persisted achievements - using defaults")
                setAchievements(createDefaultAchievements())
                await saveAchievements()
            }
        } catch {
            logger.error("❌ Failed to load achievements: \(error.localizedDescription)")
            
            // Report error but continue with defaults
            setError(AppError.persistence(.loadFailed(
                dataType: "achievements",
                underlying: error
            )))
            
            // Use default achievements so app remains functional
            setAchievements(createDefaultAchievements())
            
            // Try to save defaults for next time
            Task {
                await saveAchievements()
            }
        }
    }
    
    private func loadStreaks() async {
        logger.info("📖 Loading streaks...")
        
        do {
            if let persistedStreaks = persistenceService.load([GameStreak].self, forKey: UserDefaultsPersistenceService.Keys.streaks) {
                // Validate streak data
                let validStreaks = persistedStreaks.filter { streak in
                    // Check for impossible values
                    if streak.currentStreak < 0 || streak.totalGamesPlayed < streak.totalGamesCompleted {
                        logger.warning("Invalid streak data for \(streak.gameName) - resetting")
                        return false
                    }
                    return true
                }
                
                if validStreaks.count < persistedStreaks.count {
                    logger.warning("Some streaks had invalid data and were reset")
                }
                
                // Ensure we have streaks for all games
                var finalStreaks = validStreaks
                for game in games {
                    if !finalStreaks.contains(where: { $0.gameId == game.id }) {
                        logger.info("Creating missing streak for \(game.name)")
                        finalStreaks.append(GameStreak.empty(for: game))
                    }
                }
                
                setStreaks(finalStreaks)
                logger.debug("Loaded \(finalStreaks.count) streaks from persistence")
            } else {
                // No persisted streaks - create empty streaks for all games
                logger.info("No persisted streaks - creating defaults")
                setStreaks(games.map { GameStreak.empty(for: $0) })
                await saveStreaks()
            }
        } catch {
            logger.error("❌ Failed to load streaks: \(error.localizedDescription)")
            
            // Don't show error for streaks - just recreate them
            // Streaks can be rebuilt from game results
            logger.info("Recreating streaks from scratch")
            setStreaks(games.map { GameStreak.empty(for: $0) })
            
            // Rebuild streaks from existing game results if any
            if !recentResults.isEmpty {
                logger.info("Rebuilding streaks from \(self.recentResults.count) game results")
                await rebuildStreaksFromResults()
            }
            
            await saveStreaks()
        }
    }
    
    private func mergeAchievements(persisted: [Achievement], defaults: [Achievement]) -> [Achievement] {
        var result = defaults
        
        // Update defaults with persisted unlock status
        for persistedAchievement in persisted {
            if let index = result.firstIndex(where: { $0.id == persistedAchievement.id }) {
                result[index] = persistedAchievement
            }
        }
        
        return result
    }
    
    // MARK: - Share Extension Integration
    private func loadFromAppGroup() async {
        logger.info("📥 Checking App Group for Share Extension data...")
        
        do {
            // Check if we can access the app group
            guard appGroupPersistence != nil else {
                throw AppError.sync(.appGroupCommunicationFailed)
            }
            
            // Load latest game result from Share Extension
            if let latestResult = appGroupPersistence.load(GameResult.self, forKey: "latestGameResult") {
                logger.info("Found new game result from Share Extension: \(latestResult.gameName)")
                logger.info("Puzzle number: \(latestResult.parsedData["puzzleNumber"] ?? "unknown")")
                
                // Check for duplicates before adding
                if !isDuplicateResult(latestResult) {
                    // Process the result
                    processShareExtensionResult(latestResult)
                    
                    // Clear the App Group data after processing
                    appGroupPersistence.remove(forKey: "latestGameResult")
                    logger.info("Processed and cleared Share Extension result")
                } else {
                    logger.info("Skipping duplicate result from Share Extension")
                    // Still clear it to prevent reprocessing
                    appGroupPersistence.remove(forKey: "latestGameResult")
                }
            }
            
            // Load additional results from App Group history if needed
            if let appGroupResults = appGroupPersistence.load([GameResult].self, forKey: "gameResults") {
                logger.info("Found \(appGroupResults.count) results in App Group history")
                
                var addedCount = 0
                var failedCount = 0
                
                for result in appGroupResults {
                    do {
                        // Validate each result
                        guard result.isValid else {
                            throw AppError.parsing(.malformedGameData(
                                game: result.gameName,
                                reason: "Invalid result data"
                            ))
                        }
                        
                        // Only add if we don't already have this result
                        if !recentResults.contains(where: { $0.id == result.id }) && !isDuplicateResult(result) {
                            processShareExtensionResult(result)
                            addedCount += 1
                        }
                    } catch {
                        failedCount += 1
                        logger.error("Failed to process App Group result: \(error)")
                    }
                }
                
                if addedCount > 0 {
                    logger.info("Added \(addedCount) results from App Group history")
                    await saveAllData()
                }
                
                if failedCount > 0 {
                    logger.warning("\(failedCount) App Group results failed to process")
                }
                
                // Clear processed history
                appGroupPersistence.remove(forKey: "gameResults")
            }
            
        } catch let error as AppError {
            logger.error("❌ App Group communication error: \(error.localizedDescription)")
            
            // Only set error if it's a real communication failure
            if case .sync(.appGroupCommunicationFailed) = error {
                setError(error)
            }
            // Other errors are logged but don't stop the app
            
        } catch {
            logger.error("❌ Unexpected App Group error: \(error.localizedDescription)")
            setError(AppError.sync(.appGroupCommunicationFailed))
        }
    }
    
    // Helper method to process Share Extension results
    private func processShareExtensionResult(_ result: GameResult) {
        // Use a temporary array to modify
        var updatedResults = self.recentResults
        updatedResults.insert(result, at: 0)
        setRecentResults(updatedResults)
        updateStreak(for: result)
        checkAchievements(for: result)
        invalidateCache()
        
        logger.info("Processed Share Extension result: \(result.gameName) - \(result.displayScore)")
    }
    
    // Helper method to rebuild streaks from results
    private func rebuildStreaksFromResults() async {
        logger.info("🔄 Rebuilding streaks from game results...")
        
        // Group results by game
        let resultsByGame = Dictionary(grouping: recentResults) { $0.gameId }
        
        for (gameId, gameResults) in resultsByGame {
            guard let streakIndex = streaks.firstIndex(where: { $0.gameId == gameId }) else { continue }
            
            // Sort results chronologically
            let sortedResults = gameResults.sorted { $0.date < $1.date }
            
            // Rebuild streak by replaying all results
            var rebuiltStreak = streaks[streakIndex]
            for result in sortedResults {
                rebuiltStreak = calculateUpdatedStreak(current: rebuiltStreak, with: result)
            }
            
            // Update the streak
            var updatedStreaks = self.streaks
            updatedStreaks[streakIndex] = rebuiltStreak
            setStreaks(updatedStreaks)
            
            logger.info("Rebuilt streak for game \(gameId): \(rebuiltStreak.currentStreak) days")
        }
    }
    
    // MARK: - Data Management
    func clearAllData() async {
        setRecentResults([])
        setAchievements(createDefaultAchievements())
        setStreaks(games.map { GameStreak.empty(for: $0) })
        gameResultsCache.removeAll()
        
        persistenceService.clearAll()
        invalidateCache()
        
        logger.info("Cleared all app data and caches")
    }
    
    // MARK: - Debug Methods
    #if DEBUG
    func addTestData() async {
        logger.info("🧪 STARTING test data addition...")
        
        let testResult = GameResult(
            gameId: Game.wordle.id,
            gameName: "wordle",
            date: Date(),
            score: 3,
            maxAttempts: 6,
            completed: true,
            sharedText: "Wordle 1,234 3/6\n\n⬛🟨⬛🟨⬛\n🟨⬛🟨⬛⬛\n🟩🟩🟩🟩🟩",
            parsedData: ["puzzleNumber": "1234", "source": "test"]
        )
        
        logger.info("🧪 Test result created: \(testResult.gameName) - \(testResult.displayScore)")
        
        // Add the result
        addGameResult(testResult)
        
        // Wait a moment for async save
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Force immediate verification
        await verifyPersistence()
        
        logger.info("🧪 Test data addition complete!")
    }
    
    func cleanupDuplicates() async {
        logger.info("🧹 CLEANING UP duplicate results...")
        
        var uniqueResults: [GameResult] = []
        var seenPuzzles: [UUID: Set<String>] = [:] // gameId -> Set of puzzle numbers
        var seenDates: [UUID: Set<Date>] = [:] // gameId -> Set of dates (for games without puzzle numbers)
        let calendar = Calendar.current
        
        for result in self.recentResults.sorted(by: { $0.date > $1.date }) {
            let puzzleNumber = result.parsedData["puzzleNumber"] ?? ""
            let cleanPuzzleNumber = puzzleNumber
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: " ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            var isDuplicate = false
            
            if !cleanPuzzleNumber.isEmpty && cleanPuzzleNumber != "unknown" {
                // Check puzzle number
                if seenPuzzles[result.gameId] == nil {
                    seenPuzzles[result.gameId] = Set<String>()
                }
                
                if seenPuzzles[result.gameId]!.contains(cleanPuzzleNumber) {
                    isDuplicate = true
                    logger.info("Removing duplicate: \(result.gameName) puzzle #\(cleanPuzzleNumber)")
                } else {
                    seenPuzzles[result.gameId]!.insert(cleanPuzzleNumber)
                }
            } else {
                // Check by date for games without puzzle numbers
                let resultDay = calendar.startOfDay(for: result.date)
                
                if seenDates[result.gameId] == nil {
                    seenDates[result.gameId] = Set<Date>()
                }
                
                if seenDates[result.gameId]!.contains(resultDay) {
                    isDuplicate = true
                    logger.info("Removing duplicate: \(result.gameName) on \(result.date.formatted())")
                } else {
                    seenDates[result.gameId]!.insert(resultDay)
                }
            }
            
            if !isDuplicate {
                uniqueResults.append(result)
            }
        }
        
        // Update with clean data
        setRecentResults(uniqueResults.sorted { $0.date > $1.date })
        
        // Rebuild cache
        buildResultsCache()
        
        // Recalculate streaks from clean data
        await recalculateAllStreaks()
        
        // Save clean data
        await saveAllData()
        
        logger.info("✅ Cleanup complete: \(uniqueResults.count) unique results remaining")
    }
    
    private func recalculateAllStreaks() async {
        logger.info("🔄 Recalculating all streaks from clean data...")
        
        // Reset all streaks to zero
        var updatedStreaks = self.streaks
        for i in 0..<updatedStreaks.count {
            let game = self.games[i]
            updatedStreaks[i] = GameStreak.empty(for: game)
        }
        setStreaks(updatedStreaks)
        
        // Process results in chronological order (oldest first)
        let chronologicalResults = self.recentResults.sorted { $0.date < $1.date }
        
        for result in chronologicalResults {
            updateStreak(for: result)
        }
        
        logger.info("✅ Streak recalculation complete")
    }
    
    func verifyPersistence() async {
        logger.info("🔍 VERIFYING persistence...")
        
        // Check what's actually in UserDefaults
        let userDefaults = UserDefaults.standard
        let keys = ["streaksync_game_results", "streaksync_achievements", "streaksync_streaks"]
        
        for key in keys {
            if let data = userDefaults.data(forKey: key) {
                logger.info("✅ Found data for key: \(key) - \(data.count) bytes")
                
                if key == "streaksync_game_results" {
                    // Try to decode it
                    do {
                        let results = try JSONDecoder().decode([GameResult].self, from: data)
                        logger.info("✅ Successfully decoded \(results.count) game results")
                        for result in results.prefix(3) {
                            logger.info("  - \(result.gameName): \(result.displayScore) on \(result.date.formatted())")
                        }
                    } catch {
                        logger.error("❌ Failed to decode results: \(error)")
                        
                        // Report decode error to user
                        setError(AppError.persistence(.decodingFailed(underlying: error)))
                    }
                }
            } else {
                logger.info("❌ No data found for key: \(key)")
            }
        }
        
        // Also check current app state
        logger.info("📊 Current AppState:")
        logger.info("  - recentResults count: \(self.recentResults.count)")
        logger.info("  - achievements count: \(self.achievements.count)")
        logger.info("  - streaks count: \(self.streaks.count)")
    }
    
    func printCurrentData() {
        logger.info("📊 Current AppState Data:")
        logger.info("  Game Results: \(self.recentResults.count)")
        logger.info("  Active Streaks: \(self.totalActiveStreaks)")
        logger.info("  Unlocked Achievements: \(self.unlockedAchievements.count)")
        
        for result in self.recentResults.prefix(5) {
            let puzzleInfo = result.parsedData["puzzleNumber"] ?? "no-puzzle"
            logger.info("  - \(result.gameName) #\(puzzleInfo): \(result.displayScore) on \(result.date.formatted())")
        }
    }
    
    func forceSave() async {
        logger.info("🔄 FORCING manual save of all data...")
        await saveAllData()
        await verifyPersistence()
    }
    #endif
}
