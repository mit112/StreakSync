//
//  FriendsViewModel.swift
//  StreakSync
//

import Foundation
import OSLog
import UIKit

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var myDisplayName: String = ""
    @Published var friends: [UserProfile] = []
    @Published var leaderboard: [LeaderboardRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    /// Day currently selected by the user (stored at the local calendar's start-of-day). Converted to UTC when querying.
    @Published var selectedDateUTC: Date = Calendar.current.startOfDay(for: Date())
    @Published var selectedGameId: UUID?
    @Published var isPresentingManageFriends: Bool = false
    @Published var isPresentingDatePicker: Bool = false
    @Published var currentGamePage: Int = 0
    @Published var myUserId: String?
    
    // All games with parsers appear on the leaderboard
    var availableGames: [Game] { Game.allAvailableGames }
    
    let socialService: SocialService
    private let defaults = UserDefaults.standard
    private let lastPageKey = "friends_last_game_page"
    
    // Real-time listener handles (nil = not supported, fallback to polling)
    private var scoreListenerHandle: SocialServiceListenerHandle?
    private var friendshipListenerHandle: SocialServiceListenerHandle?
    // Fallback polling timer (only used when listeners are nil, e.g. MockSocialService)
    private var refreshTimer: Timer?
    private var refreshDebounceTask: Task<Void, Never>?
    // NotificationCenter observer tokens for proper cleanup
    private var backgroundObserver: (any NSObjectProtocol)?
    private var foregroundObserver: (any NSObjectProtocol)?
    
    init(socialService: SocialService) {
        self.socialService = socialService
        // Restore persisted UI state
        if let page = defaults.object(forKey: lastPageKey) as? Int,
           page >= 0 && page < Game.allAvailableGames.count {
            self.currentGamePage = page
        }
        self.selectedDateUTC = localStartOfDay(Date())
    }
    
    private var hasSetupListeners = false
    
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
            if !hasSetupListeners {
                setupListeners()
                hasSetupListeners = true
            }
        } catch { errorMessage = error.localizedDescription }
    }
    
    func refresh() async {
        do {
            friends = try await socialService.listFriends()
            let (start, end) = dateRange()
            leaderboard = try await socialService.fetchLeaderboard(startDateUTC: start, endDateUTC: end)
        } catch { errorMessage = error.localizedDescription }
    }
    
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
        } catch { errorMessage = error.localizedDescription }
    }
    
    // MARK: - Helpers
    func dateRange() -> (Date, Date) {
        let cal = Calendar.current
        let day = cal.startOfDay(for: selectedDateUTC)
        #if DEBUG
        debugLog("📅 dateRange selectedLocal=\(selectedDateUTC) dayInt=\(day.utcYYYYMMDD)")
        #endif
        return (day, day)
    }
    
    func persistUIState() {
        defaults.set(currentGamePage, forKey: lastPageKey)
    }

    func handleSelectedDateChange() {
        if normalizeSelectedDateIfNeeded() { return }
        persistUIState()
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
        Task {
            await refresh()
            refreshScoreListenerIfNeeded()
        }
    }
    
    // MARK: - Real-time Updates
    
    /// Sets up Firestore snapshot listeners for scores and friendships.
    /// Falls back to 30s polling if the service doesn't support listeners (e.g. MockSocialService).
    private func setupListeners() {
        tearDownListeners()

        let (start, end) = dateRange()
        let startInt = start.utcYYYYMMDD
        let endInt = end.utcYYYYMMDD

        // Score listener — triggers leaderboard refresh when any friend posts/updates a score
        scoreListenerHandle = socialService.addScoreListener(
            startDateInt: startInt,
            endDateInt: endInt
        ) { [weak self] in
            guard let self else { return }
            Task { await self.refreshLeaderboard() }
        }
        
        // Friendship listener — triggers full reload when friends are added/removed
        friendshipListenerHandle = socialService.addFriendshipListener { [weak self] in
            guard let self else { return }
            Task { await self.refresh() }
        }
        
        // If listeners aren't supported (nil), fall back to polling
        if scoreListenerHandle == nil {
            startPollingFallback()
        }
    }
    
    /// Recreates the score listener when the date range changes (user paged to different day).
    /// Recreates the score listener only when viewing today (past dates won't get new scores).
    func refreshScoreListenerIfNeeded() {
        scoreListenerHandle?.cancel()
        scoreListenerHandle = nil
        
        // Only listen for live score updates on today's date
        let today = localStartOfDay(Date())
        guard isSameLocalDay(selectedDateUTC, today) else { return }

        let (start, end) = dateRange()
        scoreListenerHandle = socialService.addScoreListener(
            startDateInt: start.utcYYYYMMDD,
            endDateInt: end.utcYYYYMMDD
        ) { [weak self] in
            guard let self else { return }
            Task { await self.refreshLeaderboard() }
        }
    }
    
    private func tearDownListeners() {
        scoreListenerHandle?.cancel()
        scoreListenerHandle = nil
        friendshipListenerHandle?.cancel()
        friendshipListenerHandle = nil
        stopPollingFallback()
    }
    
    // MARK: - Polling Fallback (MockSocialService only)
    
    private func startPollingFallback() {
        stopPollingFallback()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshLeaderboard()
            }
        }
        setupLifecycleObservers()
    }
    
    private func stopPollingFallback() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private var hasLifecycleObservers = false
    private func setupLifecycleObservers() {
        guard !hasLifecycleObservers else { return }
        hasLifecycleObservers = true
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.stopPollingFallback()
            }
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.scoreListenerHandle == nil {
                    self.startPollingFallback()
                }
                await self.refreshLeaderboard()
            }
        }
    }
    
    func cleanup() {
        tearDownListeners()
        if let obs = backgroundObserver {
            NotificationCenter.default.removeObserver(obs)
            backgroundObserver = nil
        }
        if let obs = foregroundObserver {
            NotificationCenter.default.removeObserver(obs)
            foregroundObserver = nil
        }
        hasSetupListeners = false
        hasLifecycleObservers = false
    }
    
    // MARK: - Leaderboard projection for selected game
    /// Returns only rows that have **non-zero points** for the given game.
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
        #if DEBUG
        debugLog("📊 rowsForGame \(gid) count=\(rows.count) selectedDate=\(selectedDateUTC)")
        #endif
        return rows
    }
    
    /// Friends who haven't scored for this game in the current date range.
    func friendsWhoHaventPlayed(_ gid: UUID) -> [UserProfile] {
        let playedIds = Set(rowsForSelectedGameID(gid).map { $0.row.userId })
        return friends.filter { !playedIds.contains($0.id) && $0.id != myUserId }
    }
}

// MARK: - Date Helpers
private extension FriendsViewModel {
    func localStartOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
    
    func isSameLocalDay(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }
    
    private static let debugLogger = Logger(subsystem: "com.streaksync.app", category: "FriendsViewModel")
    
    func debugLog(_ message: String) {
        #if DEBUG
        Self.debugLogger.debug("\(message)")
        #endif
    }
}
