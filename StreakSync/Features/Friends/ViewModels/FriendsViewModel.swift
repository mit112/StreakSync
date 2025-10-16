//
//  FriendsViewModel.swift
//  StreakSync
//

import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var myDisplayName: String = ""
    @Published var myFriendCode: String = ""
    @Published var friendCodeToAdd: String = ""
    @Published var friends: [UserProfile] = []
    @Published var leaderboard: [LeaderboardRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedDateUTC: Date = Date()
    @Published var selectedGameId: UUID? = nil
    @Published var isPresentingAddFriend: Bool = false
    @Published var isPresentingManageFriends: Bool = false
    @Published var isPresentingDatePicker: Bool = false
    @Published var currentGamePage: Int = 0
    @Published var range: LeaderboardRange = .today
    @Published var serviceStatus: ServiceStatus = .local
    @Published var isRealTimeEnabled: Bool = false
    @Published var myUserId: String? = nil
    
    // Rank deltas keyed by userId when comparing today vs yesterday
    @Published var rankDeltas: [String: Int] = [:]
    
    // Only show games that are actually displayed on the homepage
    var availableGames: [Game] { Game.popularGames }
    
    let socialService: SocialService
    private let defaults = UserDefaults.standard
    private let lastDateKey = "friends_last_selected_date"
    private let lastPageKey = "friends_last_game_page"
    private let lastRangeKey = "friends_last_range"
    
    // Real-time refresh timer
    private var refreshTimer: Timer?
    private var refreshDebounceTask: Task<Void, Never>?
    
    init(socialService: SocialService) {
        self.socialService = socialService
        // Restore persisted UI state
        if let saved = defaults.object(forKey: lastDateKey) as? Date { self.selectedDateUTC = saved }
        if let page = defaults.object(forKey: lastPageKey) as? Int { self.currentGamePage = page }
        if let raw = defaults.string(forKey: lastRangeKey), let r = LeaderboardRange(rawValue: raw) { self.range = r }
        // Check status
        if let hybridService = socialService as? HybridSocialService {
            self.serviceStatus = hybridService.serviceStatus
            self.isRealTimeEnabled = hybridService.isRealTimeEnabled
        }
    }
    
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let me = try await socialService.ensureProfile(displayName: nil)
            myDisplayName = me.displayName
            myUserId = me.id
            myFriendCode = try await socialService.generateFriendCode()
            friends = try await socialService.listFriends()
            let (start, end) = dateRange()
            leaderboard = try await socialService.fetchLeaderboard(startDateUTC: start, endDateUTC: end)
            if range == .today { await computeRankDeltasForToday() }
            if let hybridService = socialService as? HybridSocialService {
                await hybridService.setupRealTimeSubscriptions()
                self.serviceStatus = hybridService.serviceStatus
                self.isRealTimeEnabled = hybridService.isRealTimeEnabled
                if hybridService.isRealTimeEnabled { startPeriodicRefresh() }
            }
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
            if range == .today { await computeRankDeltasForToday() }
        } catch { errorMessage = error.localizedDescription }
    }
    
    func addFriend() async {
        let code = friendCodeToAdd
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await socialService.addFriend(using: code)
            friendCodeToAdd = ""
            friends = try await socialService.listFriends()
        } catch { errorMessage = error.localizedDescription }
    }
    
    // MARK: - Helpers
    func dateRange() -> (Date, Date) {
        let cal = Calendar(identifier: .gregorian)
        let startDay = cal.startOfDay(for: selectedDateUTC)
        switch range {
        case .today:
            return (startDay, startDay)
        case .sevenDays:
            let end = startDay
            let start = cal.date(byAdding: .day, value: -6, to: end) ?? end
            return (start, end)
        }
    }
    
    func persistUIState() {
        defaults.set(selectedDateUTC, forKey: lastDateKey)
        defaults.set(currentGamePage, forKey: lastPageKey)
        defaults.set(range.rawValue, forKey: lastRangeKey)
    }
    
    // MARK: - Date Paging
    func canIncrementDay(_ delta: Int) -> Bool {
        let cal = Calendar(identifier: .gregorian)
        let newDate = cal.date(byAdding: .day, value: delta, to: selectedDateUTC) ?? selectedDateUTC
        let newStart = cal.startOfDay(for: newDate)
        let todayStart = cal.startOfDay(for: Date())
        return newStart <= todayStart
    }

    func incrementDay(_ delta: Int) {
        guard canIncrementDay(delta) else { return }
        let cal = Calendar(identifier: .gregorian)
        selectedDateUTC = cal.date(byAdding: .day, value: delta, to: selectedDateUTC) ?? selectedDateUTC
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
    deinit {
        // Note: refreshTimer cleanup happens via stopPeriodicRefresh()
        // Cannot access mutable state in deinit under strict concurrency
    }
    
    // MARK: - Leaderboard projection for selected game
    func rowsForSelectedGameID(_ gid: UUID) -> [(row: LeaderboardRow, points: Int)] {
        leaderboard.map { row in
            let p = row.perGameBreakdown[gid] ?? 0
            return (row, p)
        }.sorted { a, b in
            if a.points == b.points { return a.row.displayName < b.row.displayName }
            return a.points > b.points
        }
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
}

// MARK: - Leaderboard Range
enum LeaderboardRange: String, CaseIterable { case today, sevenDays }


