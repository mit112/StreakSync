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
    var authProvider: String? // "anonymous", "apple", "google" — nil for legacy profiles
    var photoURL: String?     // Profile photo URL (from auth provider)
    var friendCode: String?   // 6-char friend code for invites
    var createdAt: Date
    var updatedAt: Date

    var isAnonymous: Bool { authProvider == nil || authProvider == "anonymous" }
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
    let currentStreak: Int?   // User's streak for this game at time of publishing
}

struct LeaderboardRow: Identifiable, Codable, Hashable {
    let id: String            // userId
    let userId: String
    let displayName: String
    let totalPoints: Int
    let perGameBreakdown: [UUID: Int]
    let perGameStreak: [UUID: Int]  // currentStreak per game (from most recent score)
}

// MARK: - Friendship Model

enum FriendshipStatus: String, Codable {
    case pending   // Request sent, awaiting acceptance
    case accepted  // Both users are friends
}

struct Friendship: Identifiable, Codable, Hashable {
    let id: String            // Firestore document ID
    let userId1: String       // The user who sent the request
    let userId2: String       // The user who received the request
    let status: FriendshipStatus
    let createdAt: Date
    let senderDisplayName: String? // Display name of userId1 (sender), stored on the doc for pending request UI
    
    /// Returns the other user's ID given the current user
    func otherUserId(me: String) -> String {
        userId1 == me ? userId2 : userId1
    }
}


// MARK: - Listener Handle

/// Opaque handle for cancelling a real-time Firestore listener.
protocol SocialServiceListenerHandle: AnyObject, Sendable {
    func cancel()
}

// MARK: - Social Service Protocol
protocol SocialService: Sendable {
    // Identity — synchronous accessor for the authenticated user ID
    nonisolated var currentUserId: String? { get }
    
    // Profile
    func ensureProfile(displayName: String?) async throws -> UserProfile
    func myProfile() async throws -> UserProfile
    func lookupUser(byId userId: String) async throws -> UserProfile?
    func updateProfile(displayName: String?, authProvider: String?) async throws
    
    // Friends
    func listFriends() async throws -> [UserProfile]
    func sendFriendRequest(toUserId: String) async throws
    func acceptFriendRequest(friendshipId: String) async throws
    func removeFriend(friendshipId: String) async throws
    /// Remove a friend by their user ID (looks up the friendship document automatically)
    func removeFriend(userId: String) async throws
    func pendingRequests() async throws -> [Friendship]
    
    /// Generate a friend code for the current user (stored on their profile)
    func generateFriendCode() async throws -> String
    /// Look up a user by their friend code
    func lookupByFriendCode(_ code: String) async throws -> UserProfile?
    
    // Scores
    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws
    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow]
    
    // Sync status (nonisolated for Sendable conformance)
    nonisolated var pendingScoreCount: Int { get }
    
    // Real-time listeners (optional — returns nil if not supported, caller falls back to polling)
    /// Listens for score changes among the given user IDs in the date range. Calls onChange when data changes.
    nonisolated func addScoreListener(userIds: [String], startDateInt: Int, endDateInt: Int, onChange: @escaping @MainActor @Sendable () -> Void) -> SocialServiceListenerHandle?
    /// Listens for friendship changes involving the current user. Calls onChange when friends are added/removed.
    nonisolated func addFriendshipListener(onChange: @escaping @MainActor @Sendable () -> Void) -> SocialServiceListenerHandle?
}


// MARK: - Helpers
extension Date {
    /// Returns an Int in the form yyyyMMdd using the user's local calendar.
    /// "Today" is always the user's local date regardless of UTC offset.
    var localDateInt: Int {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: self)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return y * 10_000 + m * 100 + d
    }
    
    /// Legacy alias — prefer `localDateInt` going forward.
    var utcYYYYMMDD: Int { localDateInt }
}


