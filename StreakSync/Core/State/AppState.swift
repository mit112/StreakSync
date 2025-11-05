//
//  AppState.swift
//  StreakSync
//
//  Main app state management with duplicate detection fix
//

/*
 * APPSTATE - CENTRAL DATA STORE AND BUSINESS LOGIC
 * 
 * WHAT THIS FILE DOES:
 * This is the "brain" of the app's data management. It holds all the important data (games, streaks,
 * results, achievements) and provides methods to add, remove, and update that data. Think of it as
 * the "memory" of the app - it remembers everything the user has done and keeps track of their
 * progress across all games.
 * 
 * WHY IT EXISTS:
 * Every app needs a central place to store and manage data. This file serves as the single source
 * of truth for all app data, ensuring that when you add a game result, update a streak, or unlock
 * an achievement, all parts of the app stay in sync. Without this centralized approach, different
 * parts of the app might have different versions of the data.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This is the central data store that the entire app depends on
 * - Manages all game data, streaks, results, and achievements
 * - Handles duplicate detection to prevent the same result from being added twice
 * - Computes streaks and achievement progress automatically
 * - Implements Smart Reminder Engine: analyzes 30-day usage patterns to suggest optimal reminder times
 * - Smart Reminder Algorithm: builds 24h histogram, slides 2-hour window for best coverage
 * - Coordinates with persistence services to save/load data
 * - Manages UI state and error handling
 * - Handles tiered achievements migration from legacy system
 * 
 * WHAT IT REFERENCES:
 * - PersistenceService: For saving and loading data
 * - GameResultParser: For parsing shared game results
 * - SocialService: For sharing achievements and scores
 * - AnalyticsService: For computing statistics
 * - NotificationScheduler: For scheduling reminders
 * - All data models: Game, GameResult, GameStreak, TieredAchievement
 * 
 * WHAT REFERENCES IT:
 * - EVERYTHING: This is the central data store that all views and services use
 * - AppContainer: Creates and manages the AppState instance
 * - All UI views: Access data through AppState
 * - Share Extension: Adds results through AppState
 * - Analytics: Computes statistics from AppState data
 * - Social features: Share data from AppState
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. FILE SIZE REDUCTION:
 *    - This file is very large (800+ lines) - should be split into multiple files
 *    - Consider separating into: AppState+Data.swift, AppState+Streaks.swift, AppState+Achievements.swift
 *    - Move complex business logic to separate service classes
 *    - Create protocols for different responsibilities
 * 
 * 2. RESPONSIBILITY SEPARATION:
 *    - The file handles too many responsibilities - should be split
 *    - Create a StreakManager for streak-related logic
 *    - Create an AchievementManager for achievement logic
 *    - Create a DataManager for persistence operations
 *    - Keep AppState as a coordinator that delegates to these managers
 * 
 * 3. CACHING IMPROVEMENTS:
 *    - The current caching is basic - could be more sophisticated
 *    - Implement proper cache invalidation strategies
 *    - Add memory pressure monitoring
 *    - Consider using NSCache for better memory management
 * 
 * 4. ERROR HANDLING:
 *    - The current error handling is basic - could be more robust
 *    - Add specific error types for different failure scenarios
 *    - Implement retry mechanisms for failed operations
 *    - Add better error recovery strategies
 * 
 * 5. PERFORMANCE OPTIMIZATIONS:
 *    - Some operations could be optimized for large datasets
 *    - Consider lazy loading for expensive computations
 *    - Add background processing for heavy operations
 *    - Implement data pagination for large result sets
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for all business logic
 *    - Test edge cases and error scenarios
 *    - Add integration tests with mock data
 *    - Test thread safety and concurrency
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for all public methods
 *    - Document the data flow and relationships
 *    - Add examples of how to use each method
 *    - Create diagrams showing the data relationships
 * 
 * 8. ACCESSIBILITY IMPROVEMENTS:
 *    - Add accessibility support for data operations
 *    - Implement VoiceOver announcements for important changes
 *    - Add support for accessibility shortcuts
 *    - Consider different accessibility needs
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - @Observable: Makes this class work with SwiftUI's reactive system
 * - @MainActor: Ensures all operations happen on the main thread (required for UI)
 * - @ObservationIgnored: Tells SwiftUI to ignore certain properties for change detection
 * - Private(set): Allows reading but not writing from outside the class
 * - Computed properties: These are calculated on-demand (like favoriteGames)
 * - Caching: Stores frequently accessed data to improve performance
 * - Duplicate detection: Prevents the same data from being added multiple times
 * - Business logic: The rules and calculations that make the app work correctly
 */

import Foundation
import SwiftUI
import OSLog

// MARK: - App State
@Observable
@MainActor
final class AppState {
    internal let logger = Logger(subsystem: "com.streaksync.app", category: "AppState")
    internal let persistenceService: PersistenceServiceProtocol
    internal let appGroupPersistence: AppGroupPersistenceService
    // Add this as a new property alongside existing achievements
    @ObservationIgnored
    internal var _tieredAchievements: [TieredAchievement]?
    // Add to AppState:
    func getStreak(for game: Game) -> GameStreak? {
        streaks.first { $0.gameId == game.id }
    }
    
    // MARK: - Core Data (Persisted)
    var games: [Game] = []
    var streaks: [GameStreak] = []
    // Legacy achievements removed in favor of tiered achievements
    var achievements: [Achievement] = []
    var recentResults: [GameResult] = []
    
    // MARK: - UI State (Not Persisted)
    var selectedGame: Game?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var currentError: AppError?  // This will be observable with @Observable
    var showingAddCustomGame = false
    
    // MARK: - Navigation State
    var isNavigatingFromNotification = false

    // MARK: - Social
    var socialService: SocialService?
    
    // MARK: - Analytics
    var analyticsService: AnalyticsService?
    
    // MARK: - Favorite Games Management
    var favoriteGames: [Game] {
        var favorites: [Game] = []
        for game in games {
            // Check if game is in favorites using GameCatalog
            if GameCatalog.shared.isFavorite(game.id) {
                favorites.append(game)
            }
        }
        return favorites
    }
    
    // MARK: - Persistence State
    internal var isDataLoaded = false
    internal var lastDataLoad: Date?
    
    // MARK: - Performance Cache
    private var _totalActiveStreaks: Int?
    private var _longestCurrentStreak: Int?
    private var _todaysResults: [GameResult]?
    
    // MARK: - Duplicate Prevention Cache
    internal var gameResultsCache: [UUID: Set<String>] = [:] // gameId -> Set of puzzle numbers
    
    // MARK: - Initialization
    init(persistenceService: PersistenceServiceProtocol = UserDefaultsPersistenceService()) {
        self.persistenceService = persistenceService
        self.appGroupPersistence = AppGroupPersistenceService(appGroupID: "group.com.mitsheth.StreakSync")
        
        setupInitialData()
        setupDayChangeListener()
        
        // Defer data loading to app bootstrap to avoid double-loading
        
        logger.info("AppState initialized with persistence support")
    }
    
    // MARK: - Initial Setup
    private func setupInitialData() {
        self.games = Game.allAvailableGames
        var newStreaks: [GameStreak] = []
        for game in self.games {
            newStreaks.append(GameStreak.empty(for: game))
        }
        self.streaks = newStreaks
        // Legacy achievements initialization removed
        
        logger.debug("Initial data setup complete")
    }
    
    // MARK: - Game Refresh (for new games)
    func refreshGames() {
        logger.info("🔄 Refreshing games from catalog...")
        let newGames = Game.allAvailableGames
        
        // Add new games that don't exist yet
        for newGame in newGames {
            if !self.games.contains(where: { $0.id == newGame.id }) {
                self.games.append(newGame)
                self.streaks.append(GameStreak.empty(for: newGame))
                logger.info("✅ Added new game: \(newGame.displayName)")
            }
        }
        
        logger.info("✅ Games refresh complete. Total games: \(self.games.count)")
    }
    
    private func setupDayChangeListener() {
        // Listen for day change notifications
        NotificationCenter.default.addObserver(
            forName: .dayDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Already on main queue and self is @MainActor, no need for Task wrapper
            self?.handleDayChange()
        }
        
        logger.debug("Day change listener setup complete")
    }
    
    private func handleDayChange() {
        logger.info("📅 Day changed - refreshing UI data")
        
        // Invalidate caches that depend on dates
        invalidateCache()
        
        // Rebuild streaks to ensure they reflect the new day
        Task {
            await rebuildStreaksFromResults()
            
            // Check for new achievements that might be unlocked
            await checkAllAchievements()
            
            // Update smart reminders periodically (every 2 days)
            await updateSmartRemindersIfNeeded()
            
            logger.info("✅ UI refreshed for new day")
        }
    }
    
    internal func createDefaultAchievements() -> [Achievement] {
        [
            .firstGame(),
            .weekWarrior(),
            .dedication(),
            .multitasker()
        ]
    }
    
    // MARK: - Computed Properties
    var totalActiveStreaks: Int {
        if let cached = _totalActiveStreaks { return cached }
        var count = 0
        for streak in streaks {
            if streak.isActive {
                count += 1
            }
        }
        _totalActiveStreaks = count
        return count
    }
    
    var longestCurrentStreak: Int {
        if let cached = _longestCurrentStreak { return cached }
        var longest = 0
        for streak in streaks {
            if streak.currentStreak > longest {
                longest = streak.currentStreak
            }
        }
        _longestCurrentStreak = longest
        return longest
    }
    
    var todaysResults: [GameResult] {
        if let cached = _todaysResults { return cached }
        let today = Calendar.current.startOfDay(for: Date())
        var results: [GameResult] = []
        for result in recentResults {
            if Calendar.current.isDate(result.date, inSameDayAs: today) {
                results.append(result)
            }
        }
        _todaysResults = results
        return results
    }
    
    // Legacy unlockedAchievements removed
    
    // MARK: - Cache Management
    internal func invalidateCache() {
        _totalActiveStreaks = nil
        _longestCurrentStreak = nil
        _todaysResults = nil
        
        // Also clear analytics cache when data changes
        analyticsService?.clearCache()
    }
    
    // MARK: - Duplicate Detection
    internal func isDuplicateResult(_ result: GameResult) -> Bool {
        let puzzleNumber = result.parsedData["puzzleNumber"] ?? ""
        
        // Clean puzzle number (remove commas and spaces)
        let cleanPuzzleNumber = puzzleNumber
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        logger.info("🔍 Checking duplicate for \(result.gameName) puzzle: \(cleanPuzzleNumber)")
        logger.info("📊 Current results count: \(self.recentResults.count)")
        logger.info("🆔 Result ID: \(result.id)")
        logger.info("📅 Result date: \(result.date)")
        
        // Log existing results for debugging
        for existingResult in self.recentResults.prefix(5) {
            let existingPuzzle = existingResult.parsedData["puzzleNumber"] ?? "unknown"
            logger.debug("  Existing: \(existingResult.gameName) #\(existingPuzzle) on \(existingResult.date)")
        }
        
        // Build cache if needed - ensure it's always up to date
        if self.gameResultsCache.isEmpty {
            logger.info("🔄 Building results cache (was empty)")
            buildResultsCache()
        } else {
            // Double-check that the cache is current
            let expectedCacheSize = self.recentResults.filter { result in
                let puzzleNumber = result.parsedData["puzzleNumber"] ?? ""
                let cleanPuzzleNumber = puzzleNumber
                    .replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: " ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return !cleanPuzzleNumber.isEmpty && cleanPuzzleNumber != "unknown"
            }.count
            
            let actualCacheSize = self.gameResultsCache.values.flatMap { $0 }.count
            if expectedCacheSize != actualCacheSize {
                logger.info("🔄 Rebuilding results cache (size mismatch: expected \(expectedCacheSize), actual \(actualCacheSize))")
                buildResultsCache()
            }
        }
        
        // Method 1: Check exact ID match
        if self.recentResults.contains(where: { $0.id == result.id }) {
            logger.info("❌ Duplicate detected: Exact ID match")
            return true
        }
        
        // Method 2: Check puzzle number for games that have them
        if !cleanPuzzleNumber.isEmpty && cleanPuzzleNumber != "unknown" {
            // Special handling for Pips - check puzzle number + difficulty combination
            if result.gameName.lowercased() == "pips" {
                let difficulty = result.parsedData["difficulty"] ?? ""
                let puzzleDifficultyKey = "\(cleanPuzzleNumber)-\(difficulty)"
                
                if let cachedPuzzles = self.gameResultsCache[result.gameId],
                   cachedPuzzles.contains(puzzleDifficultyKey) {
                    logger.info("❌ Duplicate detected: Puzzle #\(cleanPuzzleNumber) \(difficulty) already exists for \(result.gameName)")
                    return true
                }
            } else {
                // Standard puzzle number check for other games
                if let cachedPuzzles = self.gameResultsCache[result.gameId],
                   cachedPuzzles.contains(cleanPuzzleNumber) {
                    logger.info("❌ Duplicate detected: Puzzle #\(cleanPuzzleNumber) already exists for \(result.gameName)")
                    return true
                }
            }
        }
        
        // Method 3: For games without puzzle numbers, check same day
        if cleanPuzzleNumber.isEmpty || cleanPuzzleNumber == "unknown" {
            let calendar = Calendar.current
            let resultDay = calendar.startOfDay(for: result.date)
            
            let existingOnSameDay = self.recentResults.first { existingResult in
                guard existingResult.gameId == result.gameId else { return false }
                
                let existingDay = calendar.startOfDay(for: existingResult.date)
                return existingDay == resultDay
            }
            
            if existingOnSameDay != nil {
                logger.info("❌ Same-day duplicate detected for \(result.gameName)")
                return true
            }
        }
        
        logger.info("✅ No duplicate found - result is unique")
        return false
    }
    
    internal func buildResultsCache() {
        self.gameResultsCache.removeAll()
        
        for result in self.recentResults {
            let puzzleNumber = result.parsedData["puzzleNumber"] ?? ""
            let cleanPuzzleNumber = puzzleNumber
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: " ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !cleanPuzzleNumber.isEmpty && cleanPuzzleNumber != "unknown" {
                if self.gameResultsCache[result.gameId] == nil {
                    self.gameResultsCache[result.gameId] = Set<String>()
                }
                
                // Special handling for Pips - store puzzle number + difficulty combination
                if result.gameName.lowercased() == "pips" {
                    let difficulty = result.parsedData["difficulty"] ?? ""
                    let puzzleDifficultyKey = "\(cleanPuzzleNumber)-\(difficulty)"
                    self.gameResultsCache[result.gameId]?.insert(puzzleDifficultyKey)
                } else {
                    // Standard puzzle number for other games
                    self.gameResultsCache[result.gameId]?.insert(cleanPuzzleNumber)
                }
            }
        }
        
        logger.debug("Built results cache with \(self.gameResultsCache.count) games")
    }
    
    func addGameResult(_ result: GameResult) {
        guard result.isValid else {
            logger.warning("Attempted to add invalid game result")
            return
        }
        
        // Enhanced duplicate check
        guard !isDuplicateResult(result) else {
            logger.info("Skipping duplicate result: \(result.gameName) - \(result.displayScore)")
            return
        }
        
        // Add result
        self.recentResults.insert(result, at: 0)
        
        // Update cache
        let puzzleNumber = result.parsedData["puzzleNumber"] ?? ""
        let cleanPuzzleNumber = puzzleNumber
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !cleanPuzzleNumber.isEmpty && cleanPuzzleNumber != "unknown" {
            if self.gameResultsCache[result.gameId] == nil {
                self.gameResultsCache[result.gameId] = Set<String>()
            }
            
            // Special handling for Pips - store puzzle number + difficulty combination
            if result.gameName.lowercased() == "pips" {
                let difficulty = result.parsedData["difficulty"] ?? ""
                let puzzleDifficultyKey = "\(cleanPuzzleNumber)-\(difficulty)"
                self.gameResultsCache[result.gameId]?.insert(puzzleDifficultyKey)
            } else {
                // Standard puzzle number for other games
                self.gameResultsCache[result.gameId]?.insert(cleanPuzzleNumber)
            }
        }
        
        // Update streak SYNCHRONOUSLY
        updateStreak(for: result)
        
        // Check for new achievements (tiered-only)
        checkAchievements(for: result)
        
        // Limit results to prevent memory issues
        if self.recentResults.count > 100 {
            self.recentResults = Array(self.recentResults.prefix(100))
            // Rebuild cache after trimming
            buildResultsCache()
        }
        
        // Invalidate UI cache
        invalidateCache()
        
        // CRITICAL: Post notifications SYNCHRONOUSLY to prevent race conditions
        logger.info("📢 Posting notifications for new result: \(result.gameName) - \(result.displayScore)")
        
        // Post general update notification (no object to avoid Sendable issues)
        NotificationCenter.default.post(
            name: NSNotification.Name("GameResultAdded"),
            object: nil
        )
        
        // Post game-specific update
        NotificationCenter.default.post(
            name: NSNotification.Name("GameDataUpdated"),
            object: nil
        )
        
        // Post refresh notification for the specific game (no object to avoid Sendable issues)
        if self.games.first(where: { $0.id == result.gameId }) != nil {
            NotificationCenter.default.post(
                name: Notification.Name("RefreshGameData"),
                object: nil
            )
        }
        
        logger.info("✅ All notifications posted successfully")
        
        // CRITICAL: Save all data including updated streaks
        Task {
            await saveGameResults()
            await saveStreaks()  // Save the updated streaks
            await saveTieredAchievements()
            logger.info("✅ SAVED ALL: Game result, streaks, and tiered achievements for \(result.gameName)")
        }
        
        logger.info("Added game result for \(result.gameName)")
        
        // Check for streak risk and schedule reminders
        Task {
            await checkAndScheduleStreakReminders()
        }

        // Publish to social service (best-effort, non-blocking)
        Task { [weak self] in
            guard let self else { return }
            guard let social = self.socialService else { return }
            // Build one DailyGameScore for this result
            let userId = "local_user" // MockSocialService will map to real on publish
            let dateInt = result.date.utcYYYYMMDD
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
            try? await social.publishDailyScores(dateUTC: result.date, scores: [score])
        }
    }
    
    // MARK: - Deletion & Recompute APIs
    /// Removes a specific game result and recomputes dependent state (streaks and achievements)
    func removeGameResult(_ resultId: UUID) {
        let beforeCount = recentResults.count
        recentResults.removeAll { $0.id == resultId }
        guard recentResults.count != beforeCount else { return }
        
        // Rebuild cache
        buildResultsCache()
        
        // Rebuild streaks from remaining results
        Task { @MainActor in
            await rebuildStreaksFromResults()
            // Normalize after rebuild to ensure any now-missed days break streaks
            await normalizeStreaksForMissedDays()
            // Recompute tiered achievements from remaining results
            recalculateAllTieredAchievementProgress()
            
            // Persist
            await saveGameResults()
            await saveStreaks()
            await saveTieredAchievements()
            
            // Notify UI
            invalidateCache()
            NotificationCenter.default.post(name: NSNotification.Name("GameDataUpdated"), object: nil)
            logger.info("🗑️ Removed game result and recomputed dependent state")
        }
    }
    
    // MARK: - Grouped Results for Pips
    func getGroupedResults(for game: Game) -> [GroupedGameResult] {
        guard game.name.lowercased() == "pips" else {
            // For non-Pips games, return empty array (they use regular results)
            return []
        }
        
        // Group results by puzzle number
        var pipsResults: [GameResult] = []
        for result in recentResults {
            if result.gameId == game.id {
                pipsResults.append(result)
            }
        }
        logger.debug("🔍 getGroupedResults: Found \(pipsResults.count) Pips results")
        
        let groupedByPuzzle = Dictionary(grouping: pipsResults) { result in
            result.parsedData["puzzleNumber"] ?? "unknown"
        }
        
        logger.debug("🔍 getGroupedResults: Grouped into \(groupedByPuzzle.count) puzzles")
        
        // Convert to GroupedGameResult objects
        var groupedResults: [GroupedGameResult] = []
        
        for (puzzleNumber, results) in groupedByPuzzle {
            guard puzzleNumber != "unknown", !results.isEmpty else { continue }
            
            // Sort results by date (most recent first)
            let sortedResults = results.sorted { (result1: GameResult, result2: GameResult) in
                result1.date > result2.date
            }
            
            logger.debug("🔍 Puzzle #\(puzzleNumber): \(sortedResults.count) results")
            for result in sortedResults {
                logger.debug("   - \(result.parsedData["difficulty"] ?? "?") - \(result.parsedData["time"] ?? "?")")
            }
            
            let groupedResult = GroupedGameResult(
                gameId: game.id,
                gameName: game.name,
                puzzleNumber: puzzleNumber,
                date: sortedResults.first?.date ?? Date(),
                results: sortedResults
            )
            groupedResults.append(groupedResult)
        }
        
        // Sort by date, most recent first
        groupedResults.sort { (result1: GroupedGameResult, result2: GroupedGameResult) in
            result1.date > result2.date
        }
        
        logger.debug("🔍 getGroupedResults: Returning \(groupedResults.count) grouped results")
        return groupedResults
    }
    
    /// Convenience method to delete a game result by passing the result object
    func deleteGameResult(_ result: GameResult) {
        removeGameResult(result.id)
    }
    
    /// Check all achievements for all recent results (used during day changes)
    func checkAllAchievements() async {
        logger.info("🔍 Checking all achievements for day change")
        
        // Check achievements for each recent result (tiered-only)
        for result in recentResults {
            checkAchievements(for: result)
        }
        
        logger.info("✅ Completed checking all achievements")
    }

    // Legacy unlockAchievement removed (tiered achievements use notifications)
    
    // MARK: - Streak Risk Detection
    func checkAndScheduleStreakReminders() async {
        // Check if reminders are enabled globally
        let remindersEnabled = UserDefaults.standard.bool(forKey: "streakRemindersEnabled")
        guard remindersEnabled else {
            await NotificationScheduler.shared.cancelAllStreakReminders()
            logger.info("⏭️ Streak reminders disabled - cancelled all notifications")
            return
        }
        
        // Get user's preferred time
        let preferredHour = UserDefaults.standard.object(forKey: "streakReminderHour") as? Int ?? 19
        let preferredMinute = UserDefaults.standard.object(forKey: "streakReminderMinute") as? Int ?? 0
        
        // Find all games at risk (active streaks, not played today)
        let gamesAtRisk = getGamesAtRisk()
        
        logger.info("🔍 Found \(gamesAtRisk.count) games at risk: \(gamesAtRisk.map { $0.name }.joined(separator: ", "))")
        
        if gamesAtRisk.isEmpty {
            await NotificationScheduler.shared.cancelDailyStreakReminder()
            logger.info("✅ No games at risk - cancelled daily reminder")
        } else {
            await NotificationScheduler.shared.scheduleDailyStreakReminder(
                games: gamesAtRisk,
                hour: preferredHour,
                minute: preferredMinute
            )
            logger.info("✅ Scheduled daily reminder at \(preferredHour):\(String(format: "%02d", preferredMinute)) for \(gamesAtRisk.count) games")
        }
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
        
        logger.info("✅ Migrated to simplified notification system with smart default time: \(smartTime.hour):\(String(format: "%02d", smartTime.minute))")
    }
    
    /// Calculate smart default time based on user's typical play patterns
    private func calculateSmartDefaultTime() -> (hour: Int, minute: Int) {
        // Analyze recent game results to find typical play times
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        
        // Get recent results from the last 30 days
        let recentResults = self.recentResults.filter { result in
            result.date >= thirtyDaysAgo && result.completed
        }
        
        guard !recentResults.isEmpty else {
            // No recent data, use default 7 PM
            return (hour: 19, minute: 0)
        }
        
        // Extract hours from recent play times
        let playHours = recentResults.map { result in
            calendar.component(.hour, from: result.date)
        }
        
        // Calculate most common play hour
        let hourCounts = Dictionary(grouping: playHours, by: { $0 })
        let mostCommonHour = hourCounts.max(by: { $0.value.count < $1.value.count })?.key ?? 19
        
        // Set reminder for 2 hours before typical play time
        // This gives users a heads up before they usually play
        let reminderHour = max(6, mostCommonHour - 2) // Don't go earlier than 6 AM
        
        logger.info("📊 Smart default time: Most common play hour: \(mostCommonHour), Setting reminder for: \(reminderHour):00")
        
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
        let windowEnd = (bestStart + 2) % 24
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
        logger.info("🔔 Applied smart reminder: \(suggestion.hour):\(String(format: "%02d", suggestion.minute)) window \(suggestion.windowStart)-\(suggestion.windowEnd) coverage \(suggestion.coverage)%")
    }
    
    // MARK: - State Management
    func setLoading(_ loading: Bool) {
        isLoading = loading
        if loading {
            errorMessage = nil
        }
    }
    
    func setError(_ message: String) {
        errorMessage = message
        currentError = mapStringToAppError(message)
        isLoading = false
        
        
        logger.error("App error: \(message)")
    }

    func setError(_ error: AppError) {
        currentError = error  // Update here
        errorMessage = error.errorDescription
        isLoading = false
        logger.error("App error: \(error.localizedDescription)")
    }

    func clearError() {
        errorMessage = nil
        currentError = nil  // Update here
    }

    // Add helper method for mapping
    private func mapStringToAppError(_ message: String) -> AppError? {
        switch message {
        case let msg where msg.contains("Failed to save"):
            return .persistence(.saveFailed(dataType: "data", underlying: nil))
        case let msg where msg.contains("Failed to load"):
            return .persistence(.loadFailed(dataType: "data", underlying: nil))
        case let msg where msg.contains("Network"):
            return .sync(.syncTimeout)
        default:
            return .ui(.stateInconsistency(description: message))
        }
    }
    
    
    // MARK: - Internal Setters for Extensions
    internal func setRecentResults(_ results: [GameResult]) {
        self.recentResults = results
    }
    
    internal func setAchievements(_ achievements: [Achievement]) {
        self.achievements = achievements
    }
    
    internal func setStreaks(_ streaks: [GameStreak]) {
        self.streaks = streaks
    }
    
    
    
    
}

// MARK: - GameResult iOS Extensions
extension GameResult {
    /// iOS-specific validation including date normalization
    var isValidForIOS: Bool {
        guard isValid else { return false }
        
        // Ensure date is not in the future (iOS clock inconsistencies)
        let now = Date()
        let calendar = Calendar.current
        
        // Allow up to 1 hour in the future to account for timezone differences
        if let hourFromNow = calendar.date(byAdding: .hour, value: 1, to: now),
           date > hourFromNow {
            return false
        }
        
        // Ensure date is not too far in the past (reasonable limit)
        if let yearAgo = calendar.date(byAdding: .year, value: -1, to: now),
           date < yearAgo {
            return false
        }
        
        return true
    }
}

