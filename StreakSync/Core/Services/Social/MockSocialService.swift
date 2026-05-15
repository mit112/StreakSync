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
    func sendFriendRequest(toUserId: String, recipientDisplayName: String?) async throws -> Bool { false }
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
 logger.info("Stored \(scores.count) scores locally (total: \(existing.count))")
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
        
        return perUser.map { userId, agg in
            LeaderboardRow(
                id: userId, userId: userId, displayName: agg.name,
                totalPoints: agg.total, perGameBreakdown: agg.perGame,
                perGameStreak: [:]
            )
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
    
    // MARK: - Account Deletion (no-op in mock)
    func deleteAllUserData() async throws { }

    // MARK: - Real-time Listeners (not supported in mock — returns nil, caller falls back to polling)
    nonisolated func addScoreListener(startDateInt: Int, endDateInt: Int, onChange: @escaping @MainActor @Sendable () -> Void) -> SocialServiceListenerHandle? { nil }
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

// MARK: - Review Mode Social Service

/// Pre-seeded SocialService for App Store review. Activated by tapping the version
/// label 5× in Settings → About. Returns demo friends and a hardcoded leaderboard
/// so reviewers can verify social features without a real account.
@MainActor
final class ReviewModeSocialService: SocialService {
    private let meId = "review_user_001"

    nonisolated var pendingScoreCount: Int { 0 }
    nonisolated var currentUserId: String? { "review_user_001" }

    // MARK: - Profile

    func ensureProfile(displayName: String?) async throws -> UserProfile {
        UserProfile(id: meId, displayName: "You (Demo)", authProvider: "apple",
                    createdAt: .distantPast, updatedAt: .distantPast)
    }

    func myProfile() async throws -> UserProfile { try await ensureProfile(displayName: nil) }
    func lookupUser(byId userId: String) async throws -> UserProfile? { nil }
    func updateProfile(displayName: String?, authProvider: String?) async throws { }

    // MARK: - Friends

    func listFriends() async throws -> [UserProfile] {
        let ts = Date.distantPast
        return [
            UserProfile(id: "review_friend_001", displayName: "Alex Chen",
                        authProvider: "apple", friendCode: "AX7K2P", createdAt: ts, updatedAt: ts),
            UserProfile(id: "review_friend_002", displayName: "Jordan Kim",
                        authProvider: "apple", friendCode: "JK4R9M", createdAt: ts, updatedAt: ts),
            UserProfile(id: "review_friend_003", displayName: "Sam Rivera",
                        authProvider: "google", friendCode: "SR2L8N", createdAt: ts, updatedAt: ts)
        ]
    }

    @discardableResult
    func sendFriendRequest(toUserId: String, recipientDisplayName: String?) async throws -> Bool { false }
    func acceptFriendRequest(friendshipId: String) async throws { }
    func removeFriend(friendshipId: String) async throws { }
    func removeFriend(userId: String) async throws { }
    func pendingRequests() async throws -> [Friendship] { [] }
    func generateFriendCode() async throws -> String { "DEMO01" }
    func lookupByFriendCode(_ code: String) async throws -> UserProfile? { nil }

    // MARK: - Scores

    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws { }

    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow] {
        let wordle = UUID(staticString: "550e8400-e29b-41d4-a716-446655440000")
        let connections = UUID(staticString: "550e8400-e29b-41d4-a716-446655440003")
        let strands = UUID(staticString: "550e8400-e29b-41d4-a716-446655440007")
        let miniX = UUID(staticString: "550e8400-e29b-41d4-a716-446655440005")
        return [
            LeaderboardRow(id: meId, userId: meId, displayName: "You (Demo)", totalPoints: 18,
                           perGameBreakdown: [wordle: 4, connections: 4, strands: 10],
                           perGameStreak: [wordle: 14, connections: 5]),
            LeaderboardRow(id: "review_friend_001", userId: "review_friend_001",
                           displayName: "Alex Chen", totalPoints: 9,
                           perGameBreakdown: [wordle: 5, connections: 4],
                           perGameStreak: [wordle: 22]),
            LeaderboardRow(id: "review_friend_002", userId: "review_friend_002",
                           displayName: "Jordan Kim", totalPoints: 8,
                           perGameBreakdown: [wordle: 3, miniX: 5],
                           perGameStreak: [wordle: 7, miniX: 3]),
            LeaderboardRow(id: "review_friend_003", userId: "review_friend_003",
                           displayName: "Sam Rivera", totalPoints: 3,
                           perGameBreakdown: [connections: 3],
                           perGameStreak: [:])
        ]
    }

    // MARK: - Account

    func deleteAllUserData() async throws { }

    nonisolated func addScoreListener(
        startDateInt: Int, endDateInt: Int,
        onChange: @escaping @MainActor @Sendable () -> Void
    ) -> SocialServiceListenerHandle? { nil }

    nonisolated func addFriendshipListener(
        onChange: @escaping @MainActor @Sendable () -> Void
    ) -> SocialServiceListenerHandle? { nil }
}
