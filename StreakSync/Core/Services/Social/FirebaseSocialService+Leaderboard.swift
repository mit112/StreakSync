//
//  FirebaseSocialService+Leaderboard.swift
//  StreakSync
//
//  Leaderboard fetching, real-time listeners, and FirestoreListenerHandle for FirebaseSocialService.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import OSLog

// MARK: - Leaderboard

extension FirebaseSocialService {

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
