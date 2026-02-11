//
//  AppState.swift
//  StreakSync
//
//  Central data store — properties, initialization, computed state, and core APIs.
//  Business logic is split into focused extensions:
//    +DuplicateDetection  — isDuplicateResult, buildResultsCache
//    +ResultAddition      — addGameResult, social publishing
//    +GameLogic           — streak updates, calculateUpdatedStreak
//    +Reminders           — streak risk detection, smart reminder engine
//    +Persistence         — save/load, normalization, refresh
//    +TieredAchievements  — achievement checking, persistence, recompute
//    +Import              — rebuildStreaksFromResults, Connections fix, saveAllData
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

    @ObservationIgnored
    internal var _tieredAchievements: [TieredAchievement]?
    @ObservationIgnored
    internal var _uniqueGamesEver: Set<UUID>?

    // MARK: - Core Data (Persisted)
    var games: [Game] = []
    var streaks: [GameStreak] = []
    var achievements: [Achievement] = []
    var recentResults: [GameResult] = []

    // MARK: - UI State (Not Persisted)
    var selectedGame: Game?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var currentError: AppError?
    var showingAddCustomGame = false

    /// When true, the app is running in Guest Mode.
    var isGuestMode: Bool = false

    // MARK: - Navigation State
    var isNavigatingFromNotification = false

    // MARK: - Social & Analytics
    var socialService: SocialService?
    var analyticsService: AnalyticsService?

    // MARK: - Persistence State
    internal var isDataLoaded = false
    internal var lastDataLoad: Date?

    // MARK: - Performance Cache
    private var _totalActiveStreaks: Int?
    private var _longestCurrentStreak: Int?
    private var _todaysResults: [GameResult]?

    // MARK: - Lightweight Metrics (since launch)
    internal var loadCountSinceLaunch: Int = 0
    internal var tieredAchievementSavesSinceLaunch: Int = 0
    internal var lastReminderScheduleAt: Date?
    internal var lastAtRiskGamesSignature: String?

    // MARK: - Duplicate Prevention Cache
    internal var gameResultsCache: [UUID: Set<String>] = [:]

    // MARK: - Initialization
    init(persistenceService: PersistenceServiceProtocol = UserDefaultsPersistenceService()) {
        self.persistenceService = persistenceService
        self.appGroupPersistence = AppGroupPersistenceService(appGroupID: "group.com.mitsheth.StreakSync")

        setupInitialData()
        setupDayChangeListener()

        logger.info("AppState initialized with persistence support")
    }

    // MARK: - Initial Setup

    private func setupInitialData() {
        self.games = Game.allAvailableGames
        self.streaks = games.map { GameStreak.empty(for: $0) }
        logger.debug("Initial data setup complete")
    }

    private func setupDayChangeListener() {
        NotificationCenter.default.addObserver(
            forName: .dayDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleDayChange()
            }
        }
        logger.debug("Day change listener setup complete")
    }

    private func handleDayChange() {
        logger.info("📅 Day changed - refreshing UI data")
        invalidateCache()

        Task {
            await rebuildStreaksFromResults()
            await checkAllAchievements()
            await checkAndScheduleStreakReminders()
            logger.info("✅ UI refreshed for new day")
        }
    }

    // MARK: - Game Refresh (for new games)

    func refreshGames() {
        logger.info("🔄 Refreshing games from catalog...")
        let newGames = Game.allAvailableGames

        for newGame in newGames {
            if !self.games.contains(where: { $0.id == newGame.id }) {
                self.games.append(newGame)
                self.streaks.append(GameStreak.empty(for: newGame))
                logger.info("✅ Added new game: \(newGame.displayName)")
            }
        }

        logger.info("✅ Games refresh complete. Total games: \(self.games.count)")
    }

    // MARK: - Convenience Accessors

    func getStreak(for game: Game) -> GameStreak? {
        streaks.first { $0.gameId == game.id }
    }

    var favoriteGames: [Game] {
        games.filter { GameCatalog.shared.isFavorite($0.id) }
    }

    var favoriteGameIds: Set<UUID> {
        GameCatalog.shared.favoriteGameIDs
    }

    internal func createDefaultAchievements() -> [Achievement] {
        [.firstGame(), .weekWarrior(), .dedication(), .multitasker()]
    }

    // MARK: - Computed Properties

    var totalActiveStreaks: Int {
        if let cached = _totalActiveStreaks { return cached }
        let count = streaks.filter(\.isActive).count
        _totalActiveStreaks = count
        return count
    }

    var longestCurrentStreak: Int {
        if let cached = _longestCurrentStreak { return cached }
        let longest = streaks.map(\.currentStreak).max() ?? 0
        _longestCurrentStreak = longest
        return longest
    }

    var todaysResults: [GameResult] {
        if let cached = _todaysResults { return cached }
        let today = Calendar.current.startOfDay(for: Date())
        let results = recentResults.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        _todaysResults = results
        return results
    }

    // MARK: - Cache Management

    internal func invalidateCache() {
        _totalActiveStreaks = nil
        _longestCurrentStreak = nil
        _todaysResults = nil
        analyticsService?.clearCache()
    }

    // MARK: - Deletion & Recompute APIs

    /// Removes a specific game result and recomputes dependent state
    func removeGameResult(_ resultId: UUID) {
        let beforeCount = recentResults.count
        recentResults.removeAll { $0.id == resultId }
        guard recentResults.count != beforeCount else { return }

        buildResultsCache()

        Task { @MainActor in
            await rebuildStreaksFromResults()
            await normalizeStreaksForMissedDays()
            recalculateAllTieredAchievementProgress()

            await saveGameResults()
            await saveStreaks()
            await saveTieredAchievements()

            invalidateCache()
            NotificationCenter.default.post(name: .appGameDataUpdated, object: nil)
            logger.info("🗑️ Removed game result and recomputed dependent state")
        }
    }

    /// Convenience method to delete a game result by passing the result object
    func deleteGameResult(_ result: GameResult) {
        removeGameResult(result.id)
    }

    /// Check all achievements for all recent results (used during day changes)
    func checkAllAchievements() async {
        logger.info("🔍 Checking all achievements for day change")
        for result in recentResults {
            checkAchievements(for: result)
        }
        logger.info("✅ Completed checking all achievements")
    }

    // MARK: - Grouped Results for Pips

    func getGroupedResults(for game: Game) -> [GroupedGameResult] {
        guard game.name.lowercased() == "pips" else { return [] }

        let pipsResults = recentResults.filter { $0.gameId == game.id }
        logger.debug("🔍 getGroupedResults: Found \(pipsResults.count) Pips results")

        let groupedByPuzzle = Dictionary(grouping: pipsResults) { $0.parsedData["puzzleNumber"] ?? "unknown" }
        logger.debug("🔍 getGroupedResults: Grouped into \(groupedByPuzzle.count) puzzles")

        var groupedResults: [GroupedGameResult] = []

        for (puzzleNumber, results) in groupedByPuzzle {
            guard puzzleNumber != "unknown", !results.isEmpty else { continue }

            let sortedResults = results.sorted { $0.date > $1.date }

            logger.debug("🔍 Puzzle #\(puzzleNumber): \(sortedResults.count) results")
            for result in sortedResults {
                logger.debug("   - \(result.parsedData["difficulty"] ?? "?") - \(result.parsedData["time"] ?? "?")")
            }

            groupedResults.append(GroupedGameResult(
                gameId: game.id,
                gameName: game.name,
                puzzleNumber: puzzleNumber,
                date: sortedResults.first?.date ?? Date(),
                results: sortedResults
            ))
        }

        groupedResults.sort { $0.date > $1.date }
        logger.debug("🔍 getGroupedResults: Returning \(groupedResults.count) grouped results")
        return groupedResults
    }

    // MARK: - State Management

    func setLoading(_ loading: Bool) {
        isLoading = loading
        if loading { errorMessage = nil }
    }

    func setError(_ message: String) {
        errorMessage = message
        currentError = mapStringToAppError(message)
        isLoading = false
        logger.error("App error: \(message)")
    }

    func setError(_ error: AppError) {
        currentError = error
        errorMessage = error.errorDescription
        isLoading = false
        logger.error("App error: \(error.localizedDescription)")
    }

    func clearError() {
        errorMessage = nil
        currentError = nil
    }

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

    /// Atomically replace an existing result with the same id or append it if missing,
    /// then keep `recentResults` sorted with newest first.
    internal func replaceOrAppendResult(_ result: GameResult) {
        if let index = recentResults.firstIndex(where: { $0.id == result.id }) {
            recentResults[index] = result
        } else {
            recentResults.append(result)
        }
        recentResults.sort { $0.date > $1.date }
    }

    // MARK: - Guest Mode Helpers

    /// Clears visible state for Guest Mode without touching persistence.
    func clearForGuestMode() {
        logger.info("🧑‍🤝‍🧑 Clearing visible state for Guest Mode")
        recentResults = []
        streaks = games.map { GameStreak.empty(for: $0) }
        _tieredAchievements = AchievementFactory.createDefaultAchievements()
        gameResultsCache.removeAll()
        invalidateCache()
    }

    /// Restores state from a guest-mode snapshot.
    func restoreFromSnapshot(
        results: [GameResult],
        streaks: [GameStreak],
        achievements: [TieredAchievement]
    ) {
        logger.info("🧑‍🤝‍🧑 Restoring host state from Guest Mode snapshot")
        recentResults = results
        self.streaks = streaks
        _tieredAchievements = achievements
        buildResultsCache()
        invalidateCache()

        Task {
            await saveGameResults()
            await saveStreaks()
            await saveTieredAchievements()
        }
    }
}

// MARK: - GameResult iOS Extensions
extension GameResult {
    /// iOS-specific validation including date normalization
    var isValidForIOS: Bool {
        guard isValid else { return false }

        let now = Date()
        let calendar = Calendar.current

        if let hourFromNow = calendar.date(byAdding: .hour, value: 1, to: now),
           date > hourFromNow {
            return false
        }

        if let yearAgo = calendar.date(byAdding: .year, value: -1, to: now),
           date < yearAgo {
            return false
        }

        return true
    }
}
