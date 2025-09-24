//
//  AppState.swift
//  StreakSync
//
//  Main app state management with duplicate detection fix
//

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
    
    // MARK: - Favorite Games Management
    var favoriteGames: [Game] {
        games.filter { game in
            // Check if game is in favorites using GameCatalog
            GameCatalog.shared.isFavorite(game.id)
        }
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
        
        // Defer data loading to app bootstrap to avoid double-loading
        
        logger.info("AppState initialized with persistence support")
    }
    
    // MARK: - Initial Setup
    private func setupInitialData() {
        self.games = Game.allAvailableGames
        self.streaks = self.games.map { GameStreak.empty(for: $0) }
        self.achievements = createDefaultAchievements()
        
        logger.debug("Initial data setup complete")
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
        let count = streaks.lazy.filter(\.isActive).count
        _totalActiveStreaks = count
        return count
    }
    
    var longestCurrentStreak: Int {
        if let cached = _longestCurrentStreak { return cached }
        let longest = streaks.lazy.map(\.currentStreak).max() ?? 0
        _longestCurrentStreak = longest
        return longest
    }
    
    var todaysResults: [GameResult] {
        if let cached = _todaysResults { return cached }
        let today = Calendar.current.startOfDay(for: Date())
        let results: [GameResult] = recentResults.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        _todaysResults = results
        return results
    }
    
    var unlockedAchievements: [Achievement] {
        achievements.filter(\.isUnlocked)
    }
    
    // MARK: - Cache Management
    internal func invalidateCache() {
        _totalActiveStreaks = nil
        _longestCurrentStreak = nil
        _todaysResults = nil
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
        
        // Build cache if needed
        if self.gameResultsCache.isEmpty {
            buildResultsCache()
        }
        
        // Method 1: Check exact ID match
        if self.recentResults.contains(where: { $0.id == result.id }) {
            logger.info("❌ Duplicate detected: Exact ID match")
            return true
        }
        
        // Method 2: Check puzzle number for games that have them
        if !cleanPuzzleNumber.isEmpty && cleanPuzzleNumber != "unknown" {
            // Check cache first
            if let cachedPuzzles = self.gameResultsCache[result.gameId],
               cachedPuzzles.contains(cleanPuzzleNumber) {
                logger.info("❌ Duplicate detected: Puzzle #\(cleanPuzzleNumber) already exists for \(result.gameName)")
                return true
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
                self.gameResultsCache[result.gameId]?.insert(cleanPuzzleNumber)
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
            self.gameResultsCache[result.gameId]?.insert(cleanPuzzleNumber)
        }
        
        // Update streak SYNCHRONOUSLY
        updateStreak(for: result)
        
        // Check for new achievements
        checkAchievements(for: result)
        
        // Limit results to prevent memory issues
        if self.recentResults.count > 100 {
            self.recentResults = Array(self.recentResults.prefix(100))
            // Rebuild cache after trimming
            buildResultsCache()
        }
        
        // Invalidate UI cache
        invalidateCache()
        
        // CRITICAL: Post multiple notifications to ensure UI updates
        DispatchQueue.main.async {
            // Post general update notification
            NotificationCenter.default.post(
                name: NSNotification.Name("GameResultAdded"),
                object: result
            )
            
            // Post game-specific update
            NotificationCenter.default.post(
                name: NSNotification.Name("GameDataUpdated"),
                object: nil
            )
            
            // Post refresh notification for the specific game
            if let game = self.games.first(where: { $0.id == result.gameId }) {
                NotificationCenter.default.post(
                    name: Notification.Name("RefreshGameData"),
                    object: game
                )
            }
        }
        
        // CRITICAL: Save all data including updated streaks
        Task {
            await saveGameResults()
            await saveStreaks()  // Save the updated streaks
            await saveAchievements()
            logger.info("✅ SAVED ALL: Game result, streaks, and achievements for \(result.gameName)")
        }
        
        logger.info("Added game result for \(result.gameName)")
        
        // Check for streak risk and schedule reminders
        Task {
            await checkAndScheduleStreakReminders()
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
    

    func unlockAchievement(_ achievement: Achievement) {
        guard let index = achievements.firstIndex(where: { $0.id == achievement.id }),
              !achievements[index].isUnlocked else { return }
        
        let unlockedAchievement = Achievement(
            id: achievement.id,
            title: achievement.title,
            description: achievement.description,
            iconSystemName: achievement.iconSystemName,
            requirement: achievement.requirement,
            unlockedDate: Date(),
            gameSpecific: achievement.gameSpecific
        )
        
        achievements[index] = unlockedAchievement
        
        Task {
            await saveAchievements()
        }
        
        logger.info("Achievement unlocked: \(achievement.title)")
    }
    
    // MARK: - Streak Risk Detection
    func checkAndScheduleStreakReminders() async {
        let calendar = Calendar.current
        let now = Date()
        
        // Check global notification settings
        let streakMaintenanceEnabled = UserDefaults.standard.object(forKey: "streakMaintenanceEnabled") as? Bool ?? true
        
        logger.info("🔍 Checking streak reminders for \(self.games.count) games...")
        logger.info("🔧 Global settings: streakMaintenance=\(streakMaintenanceEnabled)")
        
        for game in games {
            logger.info("🎮 Checking game: \(game.name)")
            
            guard let streak = streaks.first(where: { $0.gameId == game.id }) else { 
                logger.info("  ⏭️ No streak found for \(game.name)")
                continue 
            }
            
            logger.info("  📊 Streak: \(streak.currentStreak) days")
            
            // Skip if streak is 0 (no active streak)
            guard streak.currentStreak > 0 else { 
                logger.info("  ⏭️ No active streak for \(game.name)")
                continue 
            }
            
            // Maintain Streaks toggle controls end-of-day reminders only (no favorites filter)
            
            // End-of-day streak protection (Maintain Streaks): after 9 PM if not played today
            if streakMaintenanceEnabled {
                let hasPlayedTodayForGame = recentResults.contains { result in
                    result.gameId == game.id &&
                    calendar.isDate(result.date, inSameDayAs: now) &&
                    result.completed
                }
                // Only for games with streak count == 1
                if streak.currentStreak == 1 && !hasPlayedTodayForGame {
                    await NotificationScheduler.shared.scheduleEndOfDayStreakReminder(for: game, now: now)
                    logger.info("  ✅ Scheduled EOD reminder for \(game.name) (Maintain Streaks, streak=1)")
                } else {
                    NotificationScheduler.shared.cancelTodayEndOfDayStreakReminder(for: game.id, now: now)
                    logger.info("  🗑️ Cancelled EOD reminder for \(game.name) - already played or streak != 1")
                }
            }
            
            // Get user's custom reminder settings for this game (per-game reminders)
            let reminderSettings = getGameReminderSettings(for: game.id)
            logger.info("  ⚙️ Reminder settings: enabled=\(reminderSettings.isEnabled), time=\(reminderSettings.preferredHour):\(String(format: "%02d", reminderSettings.preferredMinute))")
            
            guard reminderSettings.isEnabled else { 
                logger.info("  ⏭️ Reminders disabled for \(game.name)")
                continue 
            }
            
            // Check if user has played today
            let hasPlayedToday = recentResults.contains { result in
                result.gameId == game.id && 
                calendar.isDate(result.date, inSameDayAs: now) &&
                result.completed
            }
            
            logger.info("  🎯 Played today: \(hasPlayedToday)")
            
            // For testing: if user set a time in the near future (within 2 hours), schedule it regardless
            let preferredTime = calendar.date(
                bySettingHour: reminderSettings.preferredHour, 
                minute: reminderSettings.preferredMinute, 
                second: 0, 
                of: now
            ) ?? now
            
            let timeUntilPreferred = preferredTime.timeIntervalSince(now) / 3600 // hours
            let isNearFuture = timeUntilPreferred > 0 && timeUntilPreferred <= 2 // within 2 hours
            
            logger.info("  ⏰ Time until preferred: \(String(format: "%.1f", timeUntilPreferred)) hours")
            logger.info("  🧪 Is near future: \(isNearFuture)")
            
            // Schedule if: (not played today AND 20+ hours since last play) OR (near future for testing)
            // For testing: also schedule if user has a very recent last play (within 1 hour) and near future time
            let hasRecentPlay = streak.lastPlayedDate != nil && now.timeIntervalSince(streak.lastPlayedDate!) / 3600 <= 1
            
            let shouldSchedule = (!hasPlayedToday && 
                                (streak.lastPlayedDate == nil || 
                                 now.timeIntervalSince(streak.lastPlayedDate!) / 3600 >= 20)) || 
                               isNearFuture ||
                               (hasRecentPlay && isNearFuture)
            
            logger.info("  🧪 Has recent play (within 1 hour): \(hasRecentPlay)")
            logger.info("  🧪 Should schedule: \(shouldSchedule)")
            
            if shouldSchedule {
                // If the preferred time has already passed today, schedule for tomorrow
                let finalTime = preferredTime > now ? preferredTime : calendar.date(byAdding: .day, value: 1, to: preferredTime) ?? preferredTime
                
                await NotificationScheduler.shared.scheduleStreakReminder(for: game, at: finalTime)
                logger.info("  ✅ Scheduled streak reminder for \(game.name) at \(finalTime) (user's preferred time: \(reminderSettings.preferredHour):\(String(format: "%02d", reminderSettings.preferredMinute)))")
            } else {
                if hasPlayedToday {
                    logger.info("  ⏭️ Already played today for \(game.name)")
                } else if let lastPlayed = streak.lastPlayedDate {
                    let hoursSinceLastPlay = now.timeIntervalSince(lastPlayed) / 3600
                    logger.info("  ⏭️ Not enough time passed for \(game.name) (need 20+ hours, got \(String(format: "%.1f", hoursSinceLastPlay)))")
                } else {
                    logger.info("  ⏭️ No last played date for \(game.name)")
                }
            }
        }
        
        logger.info("✅ Streak reminder check completed")
    }
    
    // MARK: - Game Reminder Settings Helper
    private func getGameReminderSettings(for gameId: UUID) -> GameReminderSettings {
        let key = "gameReminder_\(gameId.uuidString)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(GameReminderSettings.self, from: data) else {
            return GameReminderSettings() // Default settings
        }
        return settings
    }
    
    // MARK: - Notification Logic Helper
    private func shouldNotifyForGame(game: Game, isFavorite: Bool, streakMaintenanceEnabled: Bool, favoriteGamesEnabled: Bool) -> Bool {
        // If both toggles are off, no notifications
        if !streakMaintenanceEnabled && !favoriteGamesEnabled {
            return false
        }
        
        // If only streak maintenance is enabled, notify for all games with streaks
        if streakMaintenanceEnabled && !favoriteGamesEnabled {
            return true
        }
        
        // If only favorite games is enabled, notify only for favorites
        if !streakMaintenanceEnabled && favoriteGamesEnabled {
            return isFavorite
        }
        
        // If both are enabled, notify for all games (favorites get priority but all games get notifications)
        return true
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

