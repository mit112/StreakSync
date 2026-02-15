//
//  MockSocialService.swift
//  StreakSync
//
//  Zero-cost local implementation backed by UserDefaults.
//

import Foundation
import OSLog

@MainActor
final class MockSocialService: SocialService {
    private let defaults: UserDefaults
    private let userKey = "social_mock_user_profile"
    private let scoresKey = "social_mock_scores"
    private let logger = Logger(subsystem: "com.streaksync.app", category: "MockSocialService")
    
    nonisolated var pendingScoreCount: Int { 0 }
    nonisolated var currentUserId: String? { MockSocialService.deviceUserId() }
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    // MARK: - Profile
    func ensureProfile(displayName: String?) async throws -> UserProfile {
        if let existing = try? await myProfile() { return existing }
        let id = MockSocialService.deviceUserId()
        let now = Date()
        let profile = UserProfile(
            id: id,
            displayName: displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Player",
            authProvider: "anonymous",
            createdAt: now,
            updatedAt: now
        )
        try save(profile, forKey: userKey)
        return profile
    }
    
    func myProfile() async throws -> UserProfile {
        guard let profile: UserProfile = load(UserProfile.self, forKey: userKey) else {
            throw NSError(domain: "MockSocialService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
        }
        return profile
    }
    
    func lookupUser(byId userId: String) async throws -> UserProfile? { nil }
    func updateProfile(displayName: String?, authProvider: String?) async throws { }
    
    // MARK: - Friends
    func listFriends() async throws -> [UserProfile] { return [] }
    func sendFriendRequest(toUserId: String) async throws { }
    func acceptFriendRequest(friendshipId: String) async throws { }
    func removeFriend(friendshipId: String) async throws { }
    func removeFriend(userId: String) async throws { }
    func pendingRequests() async throws -> [Friendship] { return [] }
    func generateFriendCode() async throws -> String { "MOCK01" }
    func lookupByFriendCode(_ code: String) async throws -> UserProfile? { nil }
    
    // MARK: - Scores
    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws {
        var existing = load([DailyGameScore].self, forKey: scoresKey) ?? []
        var index: [String: Int] = [:]
        for (i, s) in existing.enumerated() { index[s.id] = i }
        for score in scores {
            if let i = index[score.id] {
                existing[i] = score
            } else {
                existing.append(score)
            }
        }
        try save(existing, forKey: scoresKey)
        logger.info("📝 Stored \(scores.count) scores locally (total: \(existing.count))")
    }
    
    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow] {
        let my = try? await myProfile()
        let all = load([DailyGameScore].self, forKey: scoresKey) ?? []
        
        let cal = Calendar.current
        let localStart = cal.startOfDay(for: startDateUTC)
        let localEnd = cal.startOfDay(for: endDateUTC)
        
        let filtered = all.filter { score in
            guard let day = localDay(for: score.dateInt) else { return false }
            return day >= localStart && day <= localEnd
        }
        
        var perUser: [String: (name: String, total: Int, perGame: [UUID: Int])] = [:]
        for s in filtered {
            let game = Game.allAvailableGames.first(where: { $0.id == s.gameId })
            let p = LeaderboardScoring.points(for: s, game: game)
            let displayName = s.userId == my?.id ? (my?.displayName ?? "Me") : "Friend"
            var entry = perUser[s.userId] ?? (name: displayName, total: 0, perGame: [:])
            entry.total += p
            entry.perGame[s.gameId] = (entry.perGame[s.gameId] ?? 0) + p
            perUser[s.userId] = entry
        }
        
        return perUser.map { (userId, agg) in
            LeaderboardRow(id: userId, userId: userId, displayName: agg.name, totalPoints: agg.total, perGameBreakdown: agg.perGame, perGameStreak: [:])
        }.sorted { $0.totalPoints > $1.totalPoints }
    }
    
    // MARK: - Private Helpers
    
    private func localDay(for dateInt: Int) -> Date? {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let y = dateInt / 10_000
        let m = (dateInt / 100) % 100
        let d = dateInt % 100
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        guard let utcDate = utcCal.date(from: comps) else { return nil }
        return Calendar.current.startOfDay(for: utcDate)
    }
    
    private func save<T: Codable>(_ value: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        defaults.set(data, forKey: key)
    }
    
    private func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }
    
    // MARK: - Real-time Listeners (not supported in mock — returns nil, caller falls back to polling)
    nonisolated func addScoreListener(userIds: [String], startDateInt: Int, endDateInt: Int, onChange: @escaping @MainActor @Sendable () -> Void) -> SocialServiceListenerHandle? { nil }
    nonisolated func addFriendshipListener(onChange: @escaping @MainActor @Sendable () -> Void) -> SocialServiceListenerHandle? { nil }
    
    nonisolated private static func deviceUserId() -> String {
        let key = "social_mock_device_user_id"
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: key) { return id }
        let id = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        defaults.set(id, forKey: key)
        return id
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
