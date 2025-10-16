//
//  SocialService.swift
//  StreakSync
//
//  Provider-agnostic social layer for friends and leaderboards.
//

import Foundation

// MARK: - Social Models
struct UserProfile: Identifiable, Codable, Hashable {
    let id: String            // Stable user identifier
    var displayName: String
    var friendCode: String
    var createdAt: Date
    var updatedAt: Date
}

struct DailyGameScore: Identifiable, Codable, Hashable {
    let id: String            // compositeKey: userId|yyyyMMdd|gameId
    let userId: String
    let dateInt: Int          // yyyyMMdd (UTC)
    let gameId: UUID
    let gameName: String
    let score: Int?
    let maxAttempts: Int
    let completed: Bool
}

struct LeaderboardRow: Identifiable, Codable, Hashable {
    let id: String            // userId
    let userId: String
    let displayName: String
    let totalPoints: Int
    let perGameBreakdown: [UUID: Int]
}

// MARK: - Social Service Protocol
protocol SocialService: Sendable {
    // Profile
    func ensureProfile(displayName: String?) async throws -> UserProfile
    func myProfile() async throws -> UserProfile
    
    // Friends
    func generateFriendCode() async throws -> String
    func addFriend(using code: String) async throws
    func listFriends() async throws -> [UserProfile]
    
    // Scores
    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws
    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow]
}

// MARK: - Helpers
extension Date {
    /// Returns an Int in the form yyyyMMdd in UTC
    var utcYYYYMMDD: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let comps = calendar.dateComponents([.year, .month, .day], from: self)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return y * 10_000 + m * 100 + d
    }
}


