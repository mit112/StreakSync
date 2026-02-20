//
//  FirebaseSocialService.swift
//  StreakSync
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import OSLog

// MARK: - Errors

/// Represents Firebase social service errors with user-friendly messages and recovery options
enum FirebaseSocialError: LocalizedError {
    case notAuthenticated
    case networkUnavailable
    case permissionDenied
    case quotaExceeded
    case serverError(underlying: Error)
    case documentNotFound
    case invalidData(reason: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please wait while we connect to the game servers."
        case .networkUnavailable:
            return "Unable to connect. Your scores will be saved and uploaded when you're back online."
        case .permissionDenied:
            return "You don't have permission to perform this action."
        case .quotaExceeded:
            return "Service temporarily unavailable. Please try again later."
        case .serverError(let error):
            return "Server error: \(error.localizedDescription)"
        case .documentNotFound:
            return "The requested data could not be found."
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .quotaExceeded, .serverError:
            return true
        case .notAuthenticated, .permissionDenied, .documentNotFound, .invalidData:
            return false
        }
    }

    static func from(_ error: Error) -> FirebaseSocialError {
        let nsError = error as NSError
        guard nsError.domain == FirestoreErrorDomain else {
            return .serverError(underlying: error)
        }
        guard let errorCode = FirestoreErrorCode(_bridgedNSError: nsError) else {
            return .serverError(underlying: error)
        }
        switch errorCode.code {
        case .unavailable, .cancelled, .deadlineExceeded:
            return .networkUnavailable
        case .permissionDenied:
            return .permissionDenied
        case .unauthenticated:
            return .notAuthenticated
        case .resourceExhausted:
            return .quotaExceeded
        case .notFound:
            return .documentNotFound
        case .invalidArgument:
            return .invalidData(reason: error.localizedDescription)
        default:
            return .serverError(underlying: error)
        }
    }
}

// MARK: - Firebase Social Service

@MainActor
final class FirebaseSocialService: SocialService {
    private let db: Firestore
    private let auth: Auth
    private let privacyService: SocialSettingsService
    private let pendingScoreStore = PendingScoreStore()
    private var pendingScores: [DailyGameScore]
    private let logger = Logger(subsystem: "com.streaksync.app", category: "FirebaseSocialService")
    private var authStateListener: AuthStateDidChangeListenerHandle?

    // MARK: - Friends Cache (TTL-based, invalidated on friendship mutations)
    private var cachedFriends: [UserProfile]?
    private var friendsCacheTimestamp: Date?
    private let friendsCacheTTL: TimeInterval = 60 // seconds

    nonisolated var pendingScoreCount: Int { PendingScoreStore().load().count }

    /// The current authenticated user ID, safe to read from any isolation context.
    nonisolated var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    init(
        privacyService: SocialSettingsService = .shared,
        db: Firestore = Firestore.firestore(),
        auth: Auth = Auth.auth()
    ) {
        self.db = db
        self.auth = auth
        self.privacyService = privacyService
        self.pendingScores = pendingScoreStore.load()
        setupAuthStateListener()
        Task { await flushPendingScoresIfNeeded() }
    }

    private func setupAuthStateListener() {
        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            if user != nil {
                Task { @MainActor in
 self.logger.info("Auth state changed — user authenticated, flushing pending scores")
                    await self.flushPendingScoresIfNeeded()
                }
            }
        }
    }

    // MARK: - Helpers

    private var uid: String? { auth.currentUser?.uid }

    private func requireUID() throws -> String {
        guard let uid = uid else {
 logger.warning("Attempted Firebase operation without authentication")
            throw FirebaseSocialError.notAuthenticated
        }
        return uid
    }

    // MARK: - Profile

    func ensureProfile(displayName: String?) async throws -> UserProfile {
        let currentUID = try requireUID()
        let now = Date()
        let doc = db.collection("users").document(currentUID)
        do {
            let snapshot = try await doc.getDocument()
            if let data = snapshot.data(),
               let existingName = data["displayName"] as? String,
               let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() {
                // Backfill friends array if missing (migration for pre-existing profiles)
                if data["friends"] == nil {
                    await backfillFriendsArray(for: currentUID)
                }
                return UserProfile(
                    id: currentUID,
                    displayName: existingName,
                    authProvider: data["authProvider"] as? String,
                    photoURL: data["photoURL"] as? String,
                    friendCode: data["friendCode"] as? String,
                    createdAt: createdAt,
                    updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? now
                )
            }
            // New profile — determine display name from auth or fallback
            let authUser = auth.currentUser
            let resolvedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? authUser?.displayName?.nonEmpty
                ?? "Player"
            let provider = authUser?.isAnonymous == true ? "anonymous" : "apple"
            try await doc.setData([
                "displayName": resolvedName,
                "authProvider": provider,
                "friends": [String](),
                "createdAt": Timestamp(date: now),
                "updatedAt": Timestamp(date: now)
            ], merge: true)
            return UserProfile(id: currentUID, displayName: resolvedName, authProvider: provider, createdAt: now, updatedAt: now)
        } catch {
 logger.error("Failed to ensure profile: \(error.localizedDescription)")
            throw FirebaseSocialError.from(error)
        }
    }

    func myProfile() async throws -> UserProfile {
        let currentUID = try requireUID()
        do {
            let doc = try await db.collection("users").document(currentUID).getDocument()
            let data = doc.data() ?? [:]
            return Self.parseUserProfile(id: currentUID, data: data)
        } catch {
 logger.error("Failed to fetch profile: \(error.localizedDescription)")
            throw FirebaseSocialError.from(error)
        }
    }

    func updateProfile(displayName: String?, authProvider: String?) async throws {
        let currentUID = try requireUID()
        var fields: [String: Any] = [
            "updatedAt": Timestamp(date: Date())
        ]
        if let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            fields["displayName"] = name
        }
        if let provider = authProvider {
            fields["authProvider"] = provider
        }
        if let photoURL = auth.currentUser?.photoURL?.absoluteString {
            fields["photoURL"] = photoURL
        }
        try await db.collection("users").document(currentUID).setData(fields, merge: true)
 logger.info("Updated profile (provider: \(authProvider ?? "unchanged"))")
    }

    func lookupUser(byId userId: String) async throws -> UserProfile? {
        let profiles = await fetchProfiles(for: [userId])
        return profiles.first
    }

    // MARK: - Friends

    func listFriends() async throws -> [UserProfile] {
        // Return cached result if fresh
        if let cached = cachedFriends,
           let ts = friendsCacheTimestamp,
           Date().timeIntervalSince(ts) < friendsCacheTTL {
            return cached
        }
        
        let currentUID = try requireUID()
        let friendIds = try await acceptedFriendIds(for: currentUID)
        guard !friendIds.isEmpty else {
            cachedFriends = []
            friendsCacheTimestamp = Date()
            return []
        }
        let profiles = await fetchProfiles(for: friendIds)
        cachedFriends = profiles
        friendsCacheTimestamp = Date()
        return profiles
    }
    
    private func invalidateFriendsCache() {
        cachedFriends = nil
        friendsCacheTimestamp = nil
    }

    func sendFriendRequest(toUserId targetId: String) async throws {
        let currentUID = try requireUID()
        guard currentUID != targetId else { return }
        // Check if friendship already exists
        let existing = try await db.collection("friendships")
            .whereField("userId1", in: [currentUID, targetId])
            .getDocuments()
        let alreadyExists = existing.documents.contains { doc in
            let d = doc.data()
            let u1 = d["userId1"] as? String ?? ""
            let u2 = d["userId2"] as? String ?? ""
            return (u1 == currentUID && u2 == targetId) || (u1 == targetId && u2 == currentUID)
        }
        guard !alreadyExists else {
 logger.info("Friendship already exists between \(currentUID) and \(targetId)")
            return
        }
        // Resolve sender's display name for pending request UI
        let senderName = auth.currentUser?.displayName ?? "Player"
        let docId = [currentUID, targetId].sorted().joined(separator: "_")
        try await db.collection("friendships").document(docId).setData([
            "userId1": currentUID,
            "userId2": targetId,
            "status": FriendshipStatus.pending.rawValue,
            "senderDisplayName": senderName,
            "createdAt": Timestamp(date: Date())
        ])
 logger.info("Sent friend request to \(targetId)")
    }

    func acceptFriendRequest(friendshipId: String) async throws {
        let docRef = db.collection("friendships").document(friendshipId)
        
        // Read the friendship to get both user IDs
        let snapshot = try await docRef.getDocument()
        guard let data = snapshot.data(),
              let u1 = data["userId1"] as? String,
              let u2 = data["userId2"] as? String else {
            throw FirebaseSocialError.documentNotFound
        }
        
        // Update status to accepted
        try await docRef.updateData([
            "status": FriendshipStatus.accepted.rawValue
        ])
        
        // Add each user to the other's friends array (for security rules)
        let batch = db.batch()
        batch.updateData(["friends": FieldValue.arrayUnion([u2])], forDocument: db.collection("users").document(u1))
        batch.updateData(["friends": FieldValue.arrayUnion([u1])], forDocument: db.collection("users").document(u2))
        try await batch.commit()
        
 logger.info("Accepted friendship \(friendshipId) — updated friends arrays for \(u1) and \(u2)")
        invalidateFriendsCache()
    }

    func removeFriend(friendshipId: String) async throws {
        // Read the friendship to get both user IDs for friends array cleanup
        let docRef = db.collection("friendships").document(friendshipId)
        let snapshot = try await docRef.getDocument()
        if let data = snapshot.data(),
           let u1 = data["userId1"] as? String,
           let u2 = data["userId2"] as? String {
            // Remove each user from the other's friends array
            let batch = db.batch()
            batch.updateData(["friends": FieldValue.arrayRemove([u2])], forDocument: db.collection("users").document(u1))
            batch.updateData(["friends": FieldValue.arrayRemove([u1])], forDocument: db.collection("users").document(u2))
            batch.deleteDocument(docRef)
            try await batch.commit()
        } else {
            try await docRef.delete()
        }
 logger.info("Removed friendship \(friendshipId)")
        invalidateFriendsCache()
    }

    func removeFriend(userId targetId: String) async throws {
        let currentUID = try requireUID()
        let docId = [currentUID, targetId].sorted().joined(separator: "_")
        let doc = db.collection("friendships").document(docId)
        let snapshot = try await doc.getDocument()
        guard snapshot.exists else {
 logger.warning("No friendship found between \(currentUID) and \(targetId)")
            return
        }
        // Remove from friends arrays and delete friendship in one batch
        let batch = db.batch()
        batch.updateData(["friends": FieldValue.arrayRemove([targetId])], forDocument: db.collection("users").document(currentUID))
        batch.updateData(["friends": FieldValue.arrayRemove([currentUID])], forDocument: db.collection("users").document(targetId))
        batch.deleteDocument(doc)
        try await batch.commit()
 logger.info("Removed friendship with user \(targetId)")
        invalidateFriendsCache()
    }

    func pendingRequests() async throws -> [Friendship] {
        let currentUID = try requireUID()
        let snap = try await db.collection("friendships")
            .whereField("userId2", isEqualTo: currentUID)
            .whereField("status", isEqualTo: FriendshipStatus.pending.rawValue)
            .getDocuments()
        return snap.documents.compactMap { parseFriendship($0) }
    }

    func generateFriendCode() async throws -> String {
        let currentUID = try requireUID()
        let userDoc = db.collection("users").document(currentUID)
        let snapshot = try await userDoc.getDocument()
        if let existing = snapshot.data()?["friendCode"] as? String, !existing.isEmpty {
            // Ensure friendCodes collection entry exists (migration for pre-existing codes)
            let codeDoc = db.collection("friendCodes").document(existing)
            let codeSnap = try? await codeDoc.getDocument()
            if codeSnap?.exists != true {
                let displayName = snapshot.data()?["displayName"] as? String ?? "Player"
                try? await codeDoc.setData([
                    "userId": currentUID,
                    "displayName": displayName
                ])
            }
            return existing
        }
        let code = Self.randomFriendCode()
        let displayName = auth.currentUser?.displayName ?? "Player"
        // Write to both user profile and friendCodes collection
        let batch = db.batch()
        batch.updateData(["friendCode": code], forDocument: userDoc)
        batch.setData([
            "userId": currentUID,
            "displayName": displayName
        ], forDocument: db.collection("friendCodes").document(code))
        try await batch.commit()
 logger.info("Generated friend code: \(code)")
        return code
    }

    func lookupByFriendCode(_ code: String) async throws -> UserProfile? {
        let sanitized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !sanitized.isEmpty else { return nil }
        // Read from the friendCodes collection (readable by any authenticated user)
        let doc = try await db.collection("friendCodes").document(sanitized).getDocument()
        guard doc.exists,
              let data = doc.data(),
              let userId = data["userId"] as? String else {
            return nil
        }
        let displayName = (data["displayName"] as? String)?.nonEmpty ?? "Player"
        // Return a minimal profile (full profile readable only after becoming friends)
        return UserProfile(
            id: userId,
            displayName: displayName,
            friendCode: sanitized,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Friendship Helpers

    /// One-time migration: reads accepted friendships and writes the friends array
    /// to the user's profile document so Firestore security rules can gate profile reads.
    private func backfillFriendsArray(for userId: String) async {
        do {
            let friendIds = try await acceptedFriendIds(for: userId)
            try await db.collection("users").document(userId).updateData([
                "friends": friendIds
            ])
 logger.info("Backfilled friends array for \(userId) with \(friendIds.count) friends")
        } catch {
 logger.warning("Failed to backfill friends array: \(error.localizedDescription)")
            // Non-fatal — the array will be populated when the next friendship is accepted
        }
    }

    /// Returns accepted friend user IDs for a given user
    private func acceptedFriendIds(for userId: String) async throws -> [String] {
        // Query both directions: userId1 == me OR userId2 == me, status == accepted
        let snap1 = try await db.collection("friendships")
            .whereField("userId1", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendshipStatus.accepted.rawValue)
            .getDocuments()
        let snap2 = try await db.collection("friendships")
            .whereField("userId2", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendshipStatus.accepted.rawValue)
            .getDocuments()
        var ids: Set<String> = []
        for doc in snap1.documents {
            if let u2 = doc.data()["userId2"] as? String { ids.insert(u2) }
        }
        for doc in snap2.documents {
            if let u1 = doc.data()["userId1"] as? String { ids.insert(u1) }
        }
        return Array(ids)
    }

    private func fetchProfiles(for userIds: [String]) async -> [UserProfile] {
        var profiles: [UserProfile] = []
        for chunk in userIds.chunked(into: 10) {
            do {
                let snap = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                for doc in snap.documents {
                    profiles.append(Self.parseUserProfile(id: doc.documentID, data: doc.data()))
                }
            } catch {
 logger.warning("Failed to fetch profiles: \(error.localizedDescription)")
            }
        }
        return profiles
    }

    /// Shared helper to parse a Firestore user document into a UserProfile.
    private static func parseUserProfile(id: String, data: [String: Any]) -> UserProfile {
        UserProfile(
            id: id,
            displayName: (data["displayName"] as? String)?.nonEmpty ?? "Player",
            authProvider: data["authProvider"] as? String,
            photoURL: data["photoURL"] as? String,
            friendCode: data["friendCode"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    private func parseFriendship(_ doc: QueryDocumentSnapshot) -> Friendship? {
        let data = doc.data()
        guard let u1 = data["userId1"] as? String,
              let u2 = data["userId2"] as? String,
              let statusRaw = data["status"] as? String,
              let status = FriendshipStatus(rawValue: statusRaw) else { return nil }
        return Friendship(
            id: doc.documentID,
            userId1: u1,
            userId2: u2,
            status: status,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            senderDisplayName: data["senderDisplayName"] as? String
        )
    }

    private static func randomFriendCode() -> String {
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in letters.randomElement() })
    }

    // MARK: - Allowed Readers

    /// Returns [self] + [accepted friend IDs] for the `allowedReaders` field on score documents.
    /// Falls back to [self] if friends can't be fetched (e.g., offline).
    private func currentAllowedReaders() async -> [String] {
        guard let uid = uid else { return [] }
        do {
            let friendIds = try await acceptedFriendIds(for: uid)
            return [uid] + friendIds
        } catch {
 logger.warning("Failed to fetch friends for allowedReaders, using self only")
            return [uid]
        }
    }

    // MARK: - Scores

    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws {
        let currentUID = try requireUID()
        let filtered = scores.filter { score in
            let game = Game.allAvailableGames.first(where: { $0.id == score.gameId })
            return privacyService.shouldShare(score: score, game: game)
        }
        guard !filtered.isEmpty else { return }

        let allowedReaders = await currentAllowedReaders()

        let batch = db.batch()
        for score in filtered {
            let docId = "\(currentUID)|\(score.dateInt)|\(score.gameId.uuidString)"
            let ref = db.collection("scores").document(docId)
            batch.setData([
                "userId": currentUID,
                "gameId": score.gameId.uuidString,
                "gameName": score.gameName,
                "dateInt": score.dateInt,
                "score": score.score as Any,
                "maxAttempts": score.maxAttempts,
                "completed": score.completed,
                "currentStreak": score.currentStreak as Any,
                "allowedReaders": allowedReaders,
                "publishedAt": FieldValue.serverTimestamp()
            ], forDocument: ref, merge: true)
        }
        do {
            try await batch.commit()
            pendingScores.removeAll()
            pendingScoreStore.save(pendingScores)
 logger.info("Published \(filtered.count) scores to Firebase")
        } catch {
            let socialError = FirebaseSocialError.from(error)
            // Always queue for retry — even "non-retryable" errors like permissionDenied
            // can be transient (e.g., App Check enforcement misconfiguration).
            pendingScores.append(contentsOf: filtered)
            pendingScoreStore.save(pendingScores)
 logger.warning("Queued \(filtered.count) scores for retry (error: \(error.localizedDescription))")
            throw socialError
        }
    }

    func flushPendingScoresIfNeeded() async {
        guard !pendingScores.isEmpty else { return }
        guard let currentUID = uid else {
 logger.debug("Skipping pending score flush — not authenticated")
            return
        }
        let toFlush = pendingScores
        pendingScores.removeAll()
        pendingScoreStore.save(pendingScores)

        let allowedReaders = await currentAllowedReaders()

        let batch = db.batch()
        for score in toFlush {
            let docId = "\(currentUID)|\(score.dateInt)|\(score.gameId.uuidString)"
            let ref = db.collection("scores").document(docId)
            batch.setData([
                "userId": currentUID,
                "gameId": score.gameId.uuidString,
                "gameName": score.gameName,
                "dateInt": score.dateInt,
                "score": score.score as Any,
                "maxAttempts": score.maxAttempts,
                "completed": score.completed,
                "currentStreak": score.currentStreak as Any,
                "allowedReaders": allowedReaders,
                "publishedAt": FieldValue.serverTimestamp()
            ], forDocument: ref, merge: true)
        }
        do {
            try await batch.commit()
 logger.info("Flushed \(toFlush.count) pending scores")
        } catch {
            // Always re-queue — scores are too valuable to drop
            pendingScores.append(contentsOf: toFlush)
            pendingScoreStore.save(pendingScores)
 logger.warning("Re-queued \(toFlush.count) scores after flush failure: \(error.localizedDescription)")
        }
    }

    // MARK: - Score Reconciliation

    /// Republishes recent local results to the scores collection.
    /// Covers the last 7 days to catch scores dropped by previous publish failures,
    /// timezone bugs, or offline periods.
    /// Uses `setData(merge: true)` so already-published scores are harmlessly overwritten.
    func reconcileRecentScores(results: [GameResult], streaks: [GameStreak]) async {
        guard let currentUID = uid else { return }
        let cal = Calendar.current
        let cutoff = cal.startOfDay(for: cal.date(byAdding: .day, value: -7, to: Date()) ?? Date())
        let recentResults = results.filter { $0.date >= cutoff && $0.completed }
        guard !recentResults.isEmpty else { return }

        var scores: [DailyGameScore] = []
        for result in recentResults {
            let dateInt = result.date.localDateInt
            let streak = streaks.first(where: { $0.gameId == result.gameId })
            let compositeId = "\(currentUID)|\(dateInt)|\(result.gameId.uuidString)"
            scores.append(DailyGameScore(
                id: compositeId,
                userId: currentUID,
                dateInt: dateInt,
                gameId: result.gameId,
                gameName: result.gameName,
                score: result.score,
                maxAttempts: result.maxAttempts,
                completed: result.completed,
                currentStreak: streak?.currentStreak
            ))
        }

        let filtered = scores.filter { score in
            let game = Game.allAvailableGames.first(where: { $0.id == score.gameId })
            return privacyService.shouldShare(score: score, game: game)
        }
        guard !filtered.isEmpty else { return }

        let allowedReaders = await currentAllowedReaders()

        let batch = db.batch()
        for score in filtered {
            let docId = "\(currentUID)|\(score.dateInt)|\(score.gameId.uuidString)"
            let ref = db.collection("scores").document(docId)
            batch.setData([
                "userId": currentUID,
                "gameId": score.gameId.uuidString,
                "gameName": score.gameName,
                "dateInt": score.dateInt,
                "score": score.score as Any,
                "maxAttempts": score.maxAttempts,
                "completed": score.completed,
                "currentStreak": score.currentStreak as Any,
                "allowedReaders": allowedReaders,
                "publishedAt": FieldValue.serverTimestamp()
            ], forDocument: ref, merge: true)
        }
        do {
            try await batch.commit()
 logger.info("Reconciled \(filtered.count) scores from last 7 days")
        } catch {
 logger.warning("Score reconciliation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Leaderboard

    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow] {
        let currentUID = try requireUID()
        let startInt = startDateUTC.utcYYYYMMDD
        let endInt = endDateUTC.utcYYYYMMDD

        // Single query: allowedReaders contains currentUID returns scores
        // from self + friends (set at publish time).
        let snapshot = try await db.collection("scores")
            .whereField("allowedReaders", arrayContains: currentUID)
            .whereField("dateInt", isGreaterThanOrEqualTo: startInt)
            .whereField("dateInt", isLessThanOrEqualTo: endInt)
            .getDocuments()
        let allScores: [DailyGameScore] = snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard
                let userId = data["userId"] as? String,
                let gameIdStr = data["gameId"] as? String,
                let gameId = UUID(uuidString: gameIdStr),
                let dateInt = data["dateInt"] as? Int
            else { return nil }
            return DailyGameScore(
                id: doc.documentID,
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

        // Fetch display names for all users in the results
        let uniqueUserIds = Array(Set(allScores.map { $0.userId }))
        let userNames = await fetchDisplayNames(for: uniqueUserIds)

        // Aggregate per-user
        var perUser: [String: (name: String, total: Int, perGame: [UUID: Int], perGameStreak: [UUID: Int])] = [:]
        for s in allScores {
            let game = Game.allAvailableGames.first(where: { $0.id == s.gameId })
            let points = LeaderboardScoring.points(for: s, game: game)
            let displayName = userNames[s.userId] ?? "Player"
            var entry = perUser[s.userId] ?? (name: displayName, total: 0, perGame: [:], perGameStreak: [:])
            entry.total += points
            entry.perGame[s.gameId] = (entry.perGame[s.gameId] ?? 0) + points
            if let streak = s.currentStreak, streak > 0 {
                entry.perGameStreak[s.gameId] = max(entry.perGameStreak[s.gameId] ?? 0, streak)
            }
            perUser[s.userId] = entry
        }

        return perUser.map { (userId, agg) in
            LeaderboardRow(id: userId, userId: userId, displayName: agg.name,
                           totalPoints: agg.total, perGameBreakdown: agg.perGame,
                           perGameStreak: agg.perGameStreak)
        }.sorted { $0.totalPoints > $1.totalPoints }
    }

    private func fetchDisplayNames(for userIds: [String]) async -> [String: String] {
        guard !userIds.isEmpty else { return [:] }
        var names: [String: String] = [:]
        for chunk in userIds.chunked(into: 10) {
            do {
                let snap = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                for doc in snap.documents {
                    let name = (doc.data()["displayName"] as? String)?.nonEmpty ?? "Player"
                    names[doc.documentID] = name
                }
            } catch {
 logger.warning("Failed to fetch display names: \(error.localizedDescription)")
            }
        }
        return names
    }

    // MARK: - Real-time Listeners

    nonisolated func addScoreListener(
        userIds: [String],
        startDateInt: Int,
        endDateInt: Int,
        onChange: @escaping @MainActor @Sendable () -> Void
    ) -> SocialServiceListenerHandle? {
        guard let currentUID = Auth.auth().currentUser?.uid else { return nil }
        let db = Firestore.firestore()
        let log = Logger(subsystem: "com.streaksync.app", category: "FirebaseSocialService")
        var isFirstSnapshot = true // Skip initial snapshot (we already fetched on load)

        // Single listener: allowedReaders contains currentUID returns all visible scores
        let registration = db.collection("scores")
            .whereField("allowedReaders", arrayContains: currentUID)
            .whereField("dateInt", isGreaterThanOrEqualTo: startDateInt)
            .whereField("dateInt", isLessThanOrEqualTo: endDateInt)
            .addSnapshotListener { snapshot, error in
                if let error {
                    log.warning("⚠️ Score listener error: \(error.localizedDescription)")
                    return
                }
                // Skip the initial snapshot — we already have the data from load()
                if isFirstSnapshot {
                    isFirstSnapshot = false
                    return
                }
                // Only notify if there are actual document changes
                guard let snapshot, !snapshot.documentChanges.isEmpty else { return }
                log.debug("📡 Score listener: \(snapshot.documentChanges.count) changes")
                Task { @MainActor in onChange() }
            }

        log.info("📡 Started score listener (dates \(startDateInt)–\(endDateInt))")
        return FirestoreListenerHandle(registration)
    }

    nonisolated func addFriendshipListener(
        onChange: @escaping @MainActor @Sendable () -> Void
    ) -> SocialServiceListenerHandle? {
        guard let currentUID = Auth.auth().currentUser?.uid else { return nil }
        let db = Firestore.firestore()
        let log = Logger(subsystem: "com.streaksync.app", category: "FirebaseSocialService")
        var isFirstSnapshot1 = true
        var isFirstSnapshot2 = true
        
        // Listen for friendships where I'm userId1
        let reg1 = db.collection("friendships")
            .whereField("userId1", isEqualTo: currentUID)
            .addSnapshotListener { snapshot, error in
                if let error {
                    log.warning("⚠️ Friendship listener (u1) error: \(error.localizedDescription)")
                    return
                }
                if isFirstSnapshot1 { isFirstSnapshot1 = false; return }
                guard let snapshot, !snapshot.documentChanges.isEmpty else { return }
                log.debug("📡 Friendship listener (u1): \(snapshot.documentChanges.count) changes")
                Task { @MainActor in onChange() }
            }
        
        // Listen for friendships where I'm userId2
        let reg2 = db.collection("friendships")
            .whereField("userId2", isEqualTo: currentUID)
            .addSnapshotListener { snapshot, error in
                if let error {
                    log.warning("⚠️ Friendship listener (u2) error: \(error.localizedDescription)")
                    return
                }
                if isFirstSnapshot2 { isFirstSnapshot2 = false; return }
                guard let snapshot, !snapshot.documentChanges.isEmpty else { return }
                log.debug("📡 Friendship listener (u2): \(snapshot.documentChanges.count) changes")
                Task { @MainActor in onChange() }
            }
        
        log.info("📡 Started friendship listener for user \(currentUID)")
        return FirestoreListenerHandle([reg1, reg2])
    }

}

// MARK: - Helpers

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        var result: [[Element]] = []
        var chunk: [Element] = []
        chunk.reserveCapacity(size)
        for element in self {
            chunk.append(element)
            if chunk.count == size {
                result.append(chunk)
                chunk.removeAll(keepingCapacity: true)
            }
        }
        if !chunk.isEmpty { result.append(chunk) }
        return result
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Firestore Listener Handle

/// Wraps a Firestore `ListenerRegistration` to conform to `SocialServiceListenerHandle`.
final class FirestoreListenerHandle: SocialServiceListenerHandle, @unchecked Sendable {
    private var registrations: [ListenerRegistration]
    private let lock = NSLock()
    
    init(_ registration: ListenerRegistration) {
        self.registrations = [registration]
    }
    
    init(_ registrations: [ListenerRegistration]) {
        self.registrations = registrations
    }
    
    func cancel() {
        lock.lock()
        let regs = registrations
        registrations.removeAll()
        lock.unlock()
        for reg in regs { reg.remove() }
    }
}
