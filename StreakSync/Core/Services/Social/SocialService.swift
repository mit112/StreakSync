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
    let dateInt: Int          // yyyyMMdd leaderboard day — see `dayKey(for:)`
    let gameId: UUID
    let gameName: String
    let score: Int?
    let maxAttempts: Int
    let completed: Bool
    let currentStreak: Int?   // User's streak for this game at time of publishing
}

extension DailyGameScore {
    /// The leaderboard day a result belongs to: the player's own calendar day, the way
    /// Wordle and the NYT Games app date a daily puzzle. Publishing, retraction, the
    /// leaderboard query and the score listener all key off this one function.
    ///
    /// Before 1.26 publishing used the UTC date while reconcile used the local one, so a
    /// game shared after 00:00 UTC (7 pm Central) landed on tomorrow, and on two days once
    /// reconcile ran. `legacyDayKey(for:)` finds those old documents.
    static func dayKey(for date: Date, in calendar: Calendar = .current) -> Int {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return (comps.year ?? 1970) * 10_000 + (comps.month ?? 1) * 100 + (comps.day ?? 1)
    }

    /// The pre-1.26 UTC key, used only to clean up documents published under it.
    static func legacyDayKey(for date: Date) -> Int { date.utcYYYYMMDD }

    /// Decodes a `scores` document. Nil when an identifying field is missing or malformed.
    init?(documentID: String, data: [String: Any]) {
        guard
            let userId = data["userId"] as? String,
            let gameIdStr = data["gameId"] as? String,
            let gameId = UUID(uuidString: gameIdStr),
            let dateInt = data["dateInt"] as? Int
        else { return nil }
        self.init(
            id: documentID,
            userId: userId,
            dateInt: dateInt,
            gameId: gameId,
            gameName: data["gameName"] as? String ?? "Game",
            score: data["score"] as? Int,
            maxAttempts: data["maxAttempts"] as? Int ?? 6,
            completed: data["completed"] as? Bool ?? false,
            currentStreak: data["currentStreak"] as? Int
        )
    }
}

struct LeaderboardRow: Identifiable, Codable, Hashable {
    let id: String            // userId
    let userId: String
    let displayName: String
    let totalPoints: Int
    let perGameBreakdown: [UUID: Int]
    let perGameStreak: [UUID: Int]  // currentStreak per game (from most recent score)
    /// Raw `DailyGameScore.score` per game (guesses, hints, or seconds depending on
    /// `scoringModel`) — carried alongside `perGameBreakdown` so display text can render
    /// the true metric instead of reverse-deriving it from the normalized points.
    /// Only populated for games where the underlying score exists.
    let perGameRawScore: [UUID: Int]
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
    let senderDisplayName: String?    // Display name of userId1 at send time
    let recipientDisplayName: String? // Display name of userId2 — set by sender at request time, refreshed by recipient on accept

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
    /// Returns `true` when a mutual pending request was auto-accepted.
    /// `recipientDisplayName` is the recipient's display name as known to the sender
    /// (typically from `lookupByFriendCode`), denormalized onto the friendship doc.
    @discardableResult
    func sendFriendRequest(toUserId: String, recipientDisplayName: String?) async throws -> Bool
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
    /// Retracts a published score. Without this, deleting a result locally left it on
    /// friends' leaderboards forever, and editing a result's date orphaned the old entry.
    func deleteDailyScore(dateUTC: Date, gameId: UUID) async throws
    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow]
    
    // Account management
    /// Deletes ALL Firestore data for the current user (scores, friendships, friendCodes, gameResults, sync, profile).
    /// Call this before deleting the Firebase Auth account.
    func deleteAllUserData() async throws

    /// Clears the local queue of pending (failed-to-publish) scores from the Keychain.
    /// Call on sign-out so a signed-out user's scores aren't retried under the next session.
    func clearPendingScores() async
    
    // Sync status (nonisolated for Sendable conformance)
    nonisolated var pendingScoreCount: Int { get }
    
    // Real-time listeners (optional — returns nil if not supported, caller falls back to polling)
    /// Listens for score changes visible to the current user in the date range. Calls onChange when data changes.
    nonisolated func addScoreListener(startDateInt: Int, endDateInt: Int, onChange: @escaping @MainActor @Sendable () -> Void) -> SocialServiceListenerHandle?
    /// Listens for friendship changes involving the current user. Calls onChange when friends are added/removed.
    nonisolated func addFriendshipListener(onChange: @escaping @MainActor @Sendable () -> Void) -> SocialServiceListenerHandle?
}

// MARK: - Helpers
extension Date {
    /// Returns an Int in the form yyyyMMdd using the UTC calendar. Scores are no longer keyed
    /// by it (see `DailyGameScore.dayKey(for:)`); it remains for local dedup signatures and
    /// for finding documents published under the old UTC key.
    var utcYYYYMMDD: Int {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let comps = utcCalendar.dateComponents([.year, .month, .day], from: self)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return y * 10_000 + m * 100 + d
    }
}
