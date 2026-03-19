//
//  FirebaseSocialService+Friends.swift
//  StreakSync
//
//  Friends, friendship helpers, and account deletion logic for FirebaseSocialService.
//

import FirebaseFirestore
import Foundation

// MARK: - Friends

extension FirebaseSocialService {

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
        let matchingDoc = existing.documents.first { doc in
            let d = doc.data()
            let u1 = d["userId1"] as? String ?? ""
            let u2 = d["userId2"] as? String ?? ""
            return (u1 == currentUID && u2 == targetId) || (u1 == targetId && u2 == currentUID)
        }
        if let matchingDoc {
            let d = matchingDoc.data()
            // If the other user sent us a pending request, auto-accept it
            if d["userId1"] as? String == targetId,
               d["userId2"] as? String == currentUID,
               d["status"] as? String == FriendshipStatus.pending.rawValue {
                try await acceptFriendRequest(friendshipId: matchingDoc.documentID)
 logger.info("Auto-accepted mutual friend request from \(targetId)")
                return
            }
            // Already friends or we already sent a pending request
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

        // Validate the friendship exists
        let snapshot = try await docRef.getDocument()
        guard snapshot.exists, snapshot.data() != nil else {
            throw FirebaseSocialError.documentNotFound
        }

        // Update status to accepted
        try await docRef.updateData([
            "status": FriendshipStatus.accepted.rawValue
        ])

 logger.info("Accepted friendship \(friendshipId)")
        invalidateFriendsCache()

        // Reconcile allowedReaders on recent scores so the new friend
        // can see past scores and vice versa (best-effort, non-blocking)
        Task { [weak self] in
            guard let self else { return }
            await self.reconcileAllowedReadersForFriendshipChange()
        }
    }

    func removeFriend(friendshipId: String) async throws {
        let docRef = db.collection("friendships").document(friendshipId)
        try await docRef.delete()
 logger.info("Removed friendship \(friendshipId)")
        invalidateFriendsCache()

        // Update allowedReaders to revoke ex-friend's access to past scores
        Task { [weak self] in
            guard let self else { return }
            await self.reconcileAllowedReadersForFriendshipChange()
        }
    }

    func removeFriend(userId targetId: String) async throws {
        let currentUID = try requireUID()
        let docId = [currentUID, targetId].sorted().joined(separator: "_")
        let friendshipDoc = db.collection("friendships").document(docId)
        let snapshot = try await friendshipDoc.getDocument()
        guard snapshot.exists else {
 logger.warning("No friendship found between \(currentUID) and \(targetId)")
            return
        }
        try await friendshipDoc.delete()
 logger.info("Removed friendship with user \(targetId)")
        invalidateFriendsCache()

        // Update allowedReaders to revoke ex-friend's access to past scores
        Task { [weak self] in
            guard let self else { return }
            await self.reconcileAllowedReadersForFriendshipChange()
        }
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

    func fetchProfiles(for userIds: [String]) async -> [UserProfile] {
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
    static func parseUserProfile(id: String, data: [String: Any]) -> UserProfile {
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

    // MARK: - Account Deletion

    func deleteAllUserData() async throws {
        let uid = try requireUID()
        logger.info("Starting full account data deletion for user \(uid)")

        var errors: [Error] = []

        // 1. Delete all scores where userId == uid
        do {
            let scoreDocs = try await db.collection("scores")
                .whereField("userId", isEqualTo: uid)
                .getDocuments()
            for doc in scoreDocs.documents {
                try await doc.reference.delete()
            }
            logger.info("Deleted \(scoreDocs.documents.count) score documents")
        } catch {
            logger.error("Failed to delete scores: \(error.localizedDescription)")
            errors.append(error)
        }

        // 2. Delete all friendships
        do {
            let fs1 = try await db.collection("friendships")
                .whereField("userId1", isEqualTo: uid)
                .getDocuments()
            let fs2 = try await db.collection("friendships")
                .whereField("userId2", isEqualTo: uid)
                .getDocuments()
            let allFriendshipDocs = fs1.documents + fs2.documents
            for doc in allFriendshipDocs {
                try await doc.reference.delete()
            }
            logger.info("Deleted \(allFriendshipDocs.count) friendship documents")
        } catch {
            logger.error("Failed to delete friendships: \(error.localizedDescription)")
            errors.append(error)
        }

        // 3. Delete friend code if user has one
        do {
            let userDoc = try await db.collection("users").document(uid).getDocument()
            if let friendCode = userDoc.data()?["friendCode"] as? String, !friendCode.isEmpty {
                try await db.collection("friendCodes").document(friendCode).delete()
                logger.info("Deleted friend code \(friendCode)")
            }
        } catch {
            logger.error("Failed to delete friend code: \(error.localizedDescription)")
            errors.append(error)
        }

        // 4. Delete all gameResults subcollection docs
        do {
            let gameResultDocs = try await db.collection("users").document(uid)
                .collection("gameResults").getDocuments()
            for doc in gameResultDocs.documents {
                try await doc.reference.delete()
            }
            logger.info("Deleted \(gameResultDocs.documents.count) game result documents")
        } catch {
            logger.error("Failed to delete game results: \(error.localizedDescription)")
            errors.append(error)
        }

        // 5. Delete sync subcollection docs
        do {
            let syncDocs = try await db.collection("users").document(uid)
                .collection("sync").getDocuments()
            for doc in syncDocs.documents {
                try await doc.reference.delete()
            }
            logger.info("Deleted \(syncDocs.documents.count) sync documents")
        } catch {
            logger.error("Failed to delete sync documents: \(error.localizedDescription)")
            errors.append(error)
        }

        // 6. Delete user profile document (last — other cleanup needs it)
        do {
            try await db.collection("users").document(uid).delete()
            logger.info("Deleted user profile document")
        } catch {
            logger.error("Failed to delete user profile: \(error.localizedDescription)")
            errors.append(error)
        }

        // 7. Clear local caches (always runs regardless of remote errors)
        invalidateFriendsCache()
        pendingScores.removeAll()
        pendingScoreStore.save(pendingScores)

        if let firstError = errors.first {
            logger.error("Account deletion partially failed: \(errors.count) step(s) errored; first: \(firstError.localizedDescription)")
            throw firstError
        }

        logger.info("Account data deletion complete for user \(uid)")
    }

}
