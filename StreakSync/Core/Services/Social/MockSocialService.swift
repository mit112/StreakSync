//
//  MockSocialService.swift
//  StreakSync
//
//  Zero-cost local implementation backed by UserDefaults.
//

import Foundation

@MainActor
final class MockSocialService: SocialService, @unchecked Sendable {
    private let defaults: UserDefaults
    private let userKey = "social_mock_user_profile"
    private let friendsKey = "social_mock_friends"
    private let scoresKey = "social_mock_scores" // [DailyGameScore]
    
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
            friendCode: String(id.suffix(6)),
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
    
    // MARK: - Friends
    func generateFriendCode() async throws -> String {
        let profile = try await ensureProfile(displayName: nil)
        return profile.friendCode
    }
    
    func addFriend(using code: String) async throws {
        // Local mock: store friend codes only (no remote lookup). For demo, accept any code string.
        var codes = load([String].self, forKey: friendsKey) ?? []
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !codes.contains(trimmed) {
            codes.append(trimmed)
            try save(codes, forKey: friendsKey)
        }
    }
    
    func listFriends() async throws -> [UserProfile] {
        // Local mock: represent friends as placeholder profiles.
        var codes = load([String].self, forKey: friendsKey) ?? []
        if codes.isEmpty {
            // Seed demo friends so the UI is meaningful without setup
            codes = ["ash", "zoe", "dad", "gran"]
            try save(codes, forKey: friendsKey)
        }
        return codes.map { code in
            let name: String
            switch code.lowercased() {
            case "ash": name = "AshCav"
            case "zoe": name = "zoethebest"
            case "dad": name = "Dad"
            case "gran": name = "Gran"
            default: name = "Friend \(code)"
            }
            return UserProfile(id: "friend_" + code, displayName: name, friendCode: code, createdAt: Date(), updatedAt: Date())
        }
    }
    
    // MARK: - Scores
    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws {
        var existing = load([DailyGameScore].self, forKey: scoresKey) ?? []
        // Upsert by id
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
    }
    
    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow] {
        let my = try? await myProfile()
        let all = load([DailyGameScore].self, forKey: scoresKey) ?? []
        let start = startDateUTC.utcYYYYMMDD
        let end = endDateUTC.utcYYYYMMDD
        let filtered = all.filter { $0.dateInt >= start && $0.dateInt <= end }
        var perUser: [String: (name: String, total: Int, perGame: [UUID: Int])] = [:]
        for s in filtered {
            // Map gameId to Game if available for accurate scoring
            let game = Game.allAvailableGames.first(where: { $0.id == s.gameId })
            let p = LeaderboardScoring.points(for: s, game: game)
            var entry = perUser[s.userId] ?? (name: s.userId == my?.id ? (my?.displayName ?? "Me") : "Friend", total: 0, perGame: [:])
            entry.total += p
            entry.perGame[s.gameId] = (entry.perGame[s.gameId] ?? 0) + p
            perUser[s.userId] = entry
        }
        var rows = perUser.map { (userId, agg) in
            LeaderboardRow(id: userId, userId: userId, displayName: agg.name, totalPoints: agg.total, perGameBreakdown: agg.perGame)
        }.sorted { $0.totalPoints > $1.totalPoints }

        // If still empty (no scores entered), synthesize lightweight demo rows so UI looks correct
        if rows.isEmpty {
            let friends = try await listFriends()
            let dateSeed = start
            func seeded(_ base: Int) -> Int { max(0, (base + dateSeed) % 7) }
            var demo: [LeaderboardRow] = []
            if let me = my {
                demo.append(LeaderboardRow(id: me.id, userId: me.id, displayName: me.displayName, totalPoints: seeded(3), perGameBreakdown: demoBreakdown(seed: 3)))
            }
            for (i, f) in friends.enumerated() {
                demo.append(LeaderboardRow(id: f.id, userId: f.id, displayName: f.displayName, totalPoints: seeded(i + 1), perGameBreakdown: demoBreakdown(seed: i + 1)))
            }
            rows = demo.sorted { $0.totalPoints > $1.totalPoints }
        }
        return rows
    }

    private func demoBreakdown(seed: Int) -> [UUID: Int] {
        var map: [UUID: Int] = [:]
        for (idx, g) in Game.allAvailableGames.prefix(3).enumerated() {
            map[g.id] = max(0, (seed + idx) % 4)
        }
        return map
    }
    
    // MARK: - Storage helpers
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
    
    private static func deviceUserId() -> String {
        // Stable per-device id stored in Keychain would be better; for mock use UserDefaults seed
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


