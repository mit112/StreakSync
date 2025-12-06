//
//  FriendsViewModel.swift
//  StreakSync
//

/*
 * FRIENDSVIEWMODEL - SOCIAL FEATURES AND LEADERBOARD COORDINATOR
 * 
 * WHAT THIS FILE DOES:
 * This file manages all the social features of the app, including friends, leaderboards, and
 * competitive elements. It's like the "social coordinator" that handles friend requests, displays
 * leaderboards, and manages real-time updates when friends play games. Think of it as the
 * "community manager" that makes the app more engaging by allowing users to compete with friends
 * and see how they're doing compared to others.
 * 
 * WHY IT EXISTS:
 * Social features make apps more engaging and encourage users to keep playing. This view model
 * handles the complex logic of managing friends, fetching leaderboard data, and providing
 * real-time updates. It also manages the transition between local storage (when CloudKit is
 * disabled) and cloud-based social features, ensuring the app works regardless of the user's
 * preferences or network conditions.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This enables the social and competitive features that drive engagement
 * - Manages friend relationships
 * - Handles leaderboard data and ranking systems
 * - Provides real-time updates for competitive elements
 * - Supports both local and cloud-based social features
 * - Manages UI state for social interactions
 * - Handles error states and loading indicators
 * 
 * WHAT IT REFERENCES:
 * - SocialService: The core service for social features
 * - CloudKitSocialService: Handles both local and cloud social features
 * - UserProfile: Friend information and profiles
 * - LeaderboardRow: Leaderboard data and rankings
 * - Game: Available games for leaderboards
 * - LeaderboardRange: Time ranges for leaderboards (today, week, month)
 * 
 * WHAT REFERENCES IT:
 * - FriendsView: The main social features screen
 * - FriendManagementView: For managing friends
 * - Leaderboard components: Display leaderboard data
 * - AppContainer: Creates and manages the FriendsViewModel
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. STATE MANAGEMENT IMPROVEMENTS:
 *    - The current state management is complex - could be simplified
 *    - Consider using a state machine for complex loading states
 *    - Add support for optimistic updates for better user experience
 *    - Implement proper state validation and error recovery
 * 
 * 2. REAL-TIME FEATURES:
 *    - The current real-time implementation is basic - could be enhanced
 *    - Add support for push notifications for friend activities
 *    - Implement WebSocket connections for instant updates
 *    - Add support for live leaderboard updates
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current refresh logic could be optimized
 *    - Consider implementing smart refresh strategies
 *    - Add caching for leaderboard data
 *    - Implement background refresh for better user experience
 * 
 * 4. USER EXPERIENCE IMPROVEMENTS:
 *    - The current error handling could be more user-friendly
 *    - Add better loading states and progress indicators
 *    - Implement smart defaults based on user behavior
 *    - Add support for offline mode
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for all social logic
 *    - Test friend management and leaderboard functionality
 *    - Add integration tests with mock social services
 *    - Test error handling and edge cases
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for social features
 *    - Document the leaderboard scoring system
 *    - Add examples of how to use social features
 *    - Create social feature flow diagrams
 * 
 * 7. SECURITY IMPROVEMENTS:
 *    - Add validation for user input
 *    - Implement rate limiting for social operations
 *    - Add audit logging for social interactions
 *    - Consider adding privacy controls for social features
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new social features
 *    - Add support for different leaderboard types
 *    - Implement social feature plugins
 *    - Add support for custom social integrations
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Social features: Features that allow users to interact with each other
 * - Leaderboards: Rankings that show how users compare to each other
 * - Real-time updates: Information that updates automatically without user action
 * - Friend discovery: Automatic discovery of friends via contacts
 * - State management: Keeping track of what the UI should show
 * - Async/await: Handling operations that take time to complete
 * - Error handling: What to do when something goes wrong
 * - Loading states: Showing users when data is being processed
 * - Debouncing: Preventing too many rapid updates or requests
 * - Hybrid services: Services that can work in different modes (local vs cloud)
 */

import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    private let flags = BetaFeatureFlags.shared
    @Published var myDisplayName: String = ""
    @Published var friends: [UserProfile] = []
    @Published var leaderboard: [LeaderboardRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    /// Day currently selected by the user (stored at the local calendar's start-of-day). Converted to UTC when querying.
    @Published var selectedDateUTC: Date = Calendar.current.startOfDay(for: Date())
    @Published var selectedGameId: UUID? = nil
    @Published var isPresentingManageFriends: Bool = false
    @Published var isPresentingDatePicker: Bool = false
    @Published var currentGamePage: Int = 0
    @Published var range: LeaderboardRange = .today
    @Published var myUserId: String? = nil
    
    // Rank deltas keyed by userId when comparing today vs yesterday
    @Published var rankDeltas: [String: Int] = [:]
    @Published var circles: [SocialCircle] = []
    @Published var selectedCircleId: UUID? = nil
    @Published var recentReactions: [Reaction] = []
    
    // Only show games that are actually displayed on the homepage
    var availableGames: [Game] { Game.popularGames }
    
    let socialService: SocialService
    private let circleManager: CircleManaging?
    private let activityFeedService: ActivityFeedService
    private let defaults = UserDefaults.standard
    private let lastDateKey = "friends_last_selected_date"
    private let lastPageKey = "friends_last_game_page"
    private let lastRangeKey = "friends_last_range"
    
    // Real-time refresh timer
    private var refreshTimer: Timer?
    private var refreshDebounceTask: Task<Void, Never>?
    
    init(socialService: SocialService, activityFeedService: ActivityFeedService = .shared) {
        self.socialService = socialService
        self.circleManager = socialService as? CircleManaging
        self.activityFeedService = activityFeedService
        // Restore persisted UI state
        if let page = defaults.object(forKey: lastPageKey) as? Int { self.currentGamePage = page }
        if let raw = defaults.string(forKey: lastRangeKey), let r = LeaderboardRange(rawValue: raw) { self.range = r }
        let todayLocal = localStartOfDay(Date())
        if let saved = defaults.object(forKey: lastDateKey) as? Date {
            let savedLocal = localStartOfDay(saved)
            if isSameLocalDay(savedLocal, todayLocal) {
                self.selectedDateUTC = todayLocal
            } else {
                switch self.range {
                case .today:
                    self.selectedDateUTC = todayLocal
                case .sevenDays:
                    self.selectedDateUTC = min(savedLocal, todayLocal)
                }
            }
        } else {
            self.selectedDateUTC = todayLocal
        }
        if flags.multipleCircles {
            self.selectedCircleId = circleManager?.activeCircleId
        } else {
            self.selectedCircleId = nil
            self.circles = []
        }
        if flags.reactions {
            self.recentReactions = activityFeedService.reactions
        } else {
            self.recentReactions = []
        }
    }
    
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let me = try await socialService.ensureProfile(displayName: nil)
            myDisplayName = me.displayName
            myUserId = me.id
            friends = try await socialService.listFriends()
            let (start, end) = dateRange()
            leaderboard = try await socialService.fetchLeaderboard(startDateUTC: start, endDateUTC: end)
            // Normalize myUserId to match whatever identifier the leaderboard rows use.
            // In hybrid/local mode scores may be stored under a different userId (e.g. CloudKit record name),
            // so if we don't find a row matching `me.id` but there is exactly one row, assume it's us.
            if let currentId = myUserId,
               !leaderboard.contains(where: { $0.userId == currentId }),
               leaderboard.count == 1 {
                myUserId = leaderboard.first?.userId
            }
            if range == .today && flags.rankDeltas { await computeRankDeltasForToday() }
            if flags.multipleCircles { await refreshCircles() }
            if flags.reactions { recentReactions = activityFeedService.reactions }
            startPeriodicRefresh()
        } catch { errorMessage = error.localizedDescription }
    }
    
    func refresh() async { await load() }
    
    // Debounced refresh to avoid rapid reloads on quick UI changes
    func requestRefreshDebounced(delayMs: UInt64 = 180) {
        refreshDebounceTask?.cancel()
        refreshDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }
    
    func refreshLeaderboard() async {
        do {
            let (start, end) = dateRange()
            leaderboard = try await socialService.fetchLeaderboard(startDateUTC: start, endDateUTC: end)
            if range == .today && flags.rankDeltas { await computeRankDeltasForToday() }
            if flags.multipleCircles { await refreshCircles() }
        } catch { errorMessage = error.localizedDescription }
    }
    
    func selectCircle(_ circle: SocialCircle?) async {
        guard flags.multipleCircles else { return }
        guard let circleManager else { return }
        await circleManager.selectCircle(id: circle?.id)
        selectedCircleId = circle?.id
        await refresh()
    }
    
    func selectAllFriends() async {
        guard flags.multipleCircles else { return }
        guard let circleManager else { return }
        await circleManager.selectCircle(id: nil)
        selectedCircleId = nil
        await refresh()
    }
    
    func recordReaction(for row: LeaderboardRow, game: Game, type: ReactionType) {
        guard flags.reactions else { return }
        let reaction = Reaction(
            id: UUID(),
            targetUserId: row.userId,
            targetGameId: game.id,
            senderName: myDisplayName.isEmpty ? "You" : myDisplayName,
            date: Date(),
            type: type
        )
        activityFeedService.record(reaction)
        recentReactions = activityFeedService.reactions
    }
    
    // MARK: - Helpers
    private func refreshCircles() async {
        guard flags.multipleCircles else { return }
        guard let circleManager else { return }
        do {
            let latest = try await circleManager.listCircles()
            self.circles = latest
            self.selectedCircleId = circleManager.activeCircleId
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    func dateRange() -> (Date, Date) {
        // Interpret selectedDateUTC as a *local* calendar day, then let services
        // convert to UTC day buckets via `utcYYYYMMDD` for storage/comparison.
        let cal = Calendar.current
        let endLocal = cal.startOfDay(for: selectedDateUTC)
        switch range {
        case .today:
            if flags.debugInfo {
                debugLog("📅 dateRange (today) selectedLocal=\(selectedDateUTC) endInt=\(endLocal.utcYYYYMMDD)")
            }
            return (endLocal, endLocal)
        case .sevenDays:
            let start = cal.date(byAdding: .day, value: -6, to: endLocal) ?? endLocal
            if flags.debugInfo {
                debugLog("📅 dateRange (7d) startInt=\(start.utcYYYYMMDD) endInt=\(endLocal.utcYYYYMMDD)")
            }
            return (start, endLocal)
        }
    }
    
    func persistUIState() {
        defaults.set(selectedDateUTC, forKey: lastDateKey)
        defaults.set(currentGamePage, forKey: lastPageKey)
        defaults.set(range.rawValue, forKey: lastRangeKey)
    }
    
    func handleSelectedDateChange() {
        if normalizeSelectedDateIfNeeded() { return }
        persistUIState()
    }
    
    func handleRangeSelectionChange() async {
        _ = normalizeSelectedDateIfNeeded()
        persistUIState()
        await refresh()
    }
    
    @discardableResult
    private func normalizeSelectedDateIfNeeded() -> Bool {
        let normalized = localStartOfDay(selectedDateUTC)
        let today = localStartOfDay(Date())
        let clamped = normalized > today ? today : normalized
        if clamped != selectedDateUTC {
            selectedDateUTC = clamped
            return true
        }
        return false
    }
    
    /// Updates selectedDateUTC to today's date in UTC when range changes to "today"
    // MARK: - Date Paging
    func canIncrementDay(_ delta: Int) -> Bool {
        let cal = Calendar.current
        let newDate = cal.date(byAdding: .day, value: delta, to: selectedDateUTC) ?? selectedDateUTC
        let normalized = localStartOfDay(newDate)
        let today = localStartOfDay(Date())
        return normalized <= today
    }

    func incrementDay(_ delta: Int) {
        guard canIncrementDay(delta) else { return }
        let cal = Calendar.current
        let newDate = cal.date(byAdding: .day, value: delta, to: selectedDateUTC) ?? selectedDateUTC
        selectedDateUTC = localStartOfDay(newDate)
        Task { await refresh() }
    }
    
    // MARK: - Real-time Updates
    private func startPeriodicRefresh() {
        stopPeriodicRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshLeaderboard()
            }
        }
    }
    private func stopPeriodicRefresh() { refreshTimer?.invalidate(); refreshTimer = nil }
    
    // MARK: - Leaderboard projection for selected game
    /// Returns only rows that have **non-zero points** for the given game.
    /// This avoids showing generic/static rows for games a user hasn't played.
    func rowsForSelectedGameID(_ gid: UUID) -> [(row: LeaderboardRow, points: Int)] {
        let rows = leaderboard
            .compactMap { row -> (row: LeaderboardRow, points: Int)? in
                let p = row.perGameBreakdown[gid] ?? 0
                guard p > 0 else { return nil }
                return (row, p)
            }
            .sorted { a, b in
                if a.points == b.points { return a.row.displayName < b.row.displayName }
                return a.points > b.points
            }
        if flags.debugInfo {
            debugLog("📊 rowsForGame \(gid) count=\(rows.count) selectedDate=\(selectedDateUTC)")
        }
        return rows
    }
    
    func myRankForSelectedGame() -> (rank: Int, points: Int, game: Game)? {
        guard let gid = selectedGameId else { return nil }
        let rows = rowsForSelectedGameID(gid)
        guard let uid = myUserId, let idx = rows.firstIndex(where: { $0.row.userId == uid }) else { return nil }
        return (rank: idx + 1, points: rows[idx].points, game: Game.allAvailableGames.first(where: { $0.id == gid }) ?? Game.wordle)
    }
    
    // MARK: - Rank delta (Today only)
    private func computeRankDeltasForToday() async {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: selectedDateUTC)
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today) else { return }
        do {
            let yesterdayRows = try await socialService.fetchLeaderboard(startDateUTC: yesterday, endDateUTC: yesterday)
            let todayRows = leaderboard
            let yesterdayRanks: [String: Int] = Dictionary(uniqueKeysWithValues: yesterdayRows.enumerated().map { ($0.element.userId, $0.offset + 1) })
            let todayRanks: [String: Int] = Dictionary(uniqueKeysWithValues: todayRows.enumerated().map { ($0.element.userId, $0.offset + 1) })
            var deltas: [String: Int] = [:]
            for (userId, todayRank) in todayRanks {
                let yesterdayRank = yesterdayRanks[userId]
                guard let y = yesterdayRank else { continue }
                deltas[userId] = y - todayRank // positive means improved
            }
            self.rankDeltas = deltas
        } catch {
            // best-effort
        }
    }

    // MARK: - UI helpers
    var shouldShowCircleSelector: Bool {
        flags.multipleCircles && circles.count > 1
    }

    var shouldShowReactions: Bool {
        flags.reactions
    }

    var shouldShowActivityFeed: Bool {
        flags.activityFeed
    }

    var shouldShowRankDeltas: Bool {
        flags.rankDeltas
    }

    var isMinimalBeta: Bool {
        flags.isMinimalBeta
    }
    
    // MARK: - Debug Function
    func debugLeaderboardIssue() async {
        print("🔍 === LEADERBOARD DEBUG ===")
        
        // 1. Check storage
        if let scoresData = UserDefaults.standard.data(forKey: "social_mock_scores"),
           let scores = try? JSONDecoder().decode([DailyGameScore].self, from: scoresData) {
            print("📦 Raw storage has \(scores.count) scores")
            
            let today = Date().utcYYYYMMDD
            let todayScores = scores.filter { $0.dateInt == today }
            print("📅 Today's scores (\(today)): \(todayScores.count)")
            
            for score in todayScores {
                print("  - Game: \(score.gameName)")
                print("    userId: \(score.userId)")
                print("    dateInt: \(score.dateInt)")
                print("    completed: \(score.completed)")
                print("    score: \(score.score?.description ?? "nil")")
            }
        } else {
            print("❌ No scores in storage!")
        }
        
        // 2. Check profile
        let profile = try? await socialService.myProfile()
        print("👤 My profile ID: \(profile?.id ?? "nil")")
        print("👤 My display name: \(profile?.displayName ?? "nil")")
        
        // 3. Check fetch
        let today = Calendar.current.startOfDay(for: Date())
        print("📅 Fetching leaderboard for: \(today) → \(today.utcYYYYMMDD)")
        let rows = try? await socialService.fetchLeaderboard(
            startDateUTC: today,
            endDateUTC: today
        )
        print("📊 Fetched \(rows?.count ?? 0) rows")
        if let rows = rows {
            for row in rows {
                print("  - \(row.displayName) (userId=\(row.userId)): \(row.totalPoints) pts")
                for (gameId, points) in row.perGameBreakdown {
                    if let game = Game.allAvailableGames.first(where: { $0.id == gameId }) {
                        print("    → \(game.displayName): \(points) pts")
                    }
                }
            }
        }
        
        // 4. Check date range
        let (start, end) = dateRange()
        print("📅 Current date range:")
        print("  - selectedDateUTC: \(selectedDateUTC)")
        print("  - range: \(range)")
        print("  - start: \(start) → \(start.utcYYYYMMDD)")
        print("  - end: \(end) → \(end.utcYYYYMMDD)")
        
        print("🔍 === END DEBUG ===")
    }
}

// MARK: - Leaderboard Range
/// Leaderboard ranges:
/// - `.today`: single-day leaderboard controlled by `selectedDateUTC`
/// - `.sevenDays`: rolling seven-day window ending at `selectedDateUTC`
enum LeaderboardRange: String, CaseIterable { case today, sevenDays }

// MARK: - Date Helpers
private extension FriendsViewModel {
    var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return cal
    }
    
    func utcStartOfDay(_ date: Date) -> Date {
        utcCalendar.startOfDay(for: date)
    }
    
    func localStartOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
    
    func isSameLocalDay(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }
    
    func debugLog(_ message: String) {
        guard flags.debugInfo else { return }
        print("👀 [FriendsViewModel] \(message)")
    }
}


