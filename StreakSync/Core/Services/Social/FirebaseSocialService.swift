//
//  FirebaseSocialService.swift
//  StreakSync
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class FirebaseSocialService: SocialService, FriendDiscoveryProviding, CircleManaging {
    private let db: Firestore
    private let auth: Auth
    private let privacyService: SocialSettingsService
    private let circleStore = SocialCircleStore()
    private let pendingScoreStore = PendingScoreStore()
    private var pendingScores: [DailyGameScore]
    private let selectionStore = GroupSelectionStore()
    
    init(
        privacyService: SocialSettingsService = .shared,
        db: Firestore = Firestore.firestore(),
        auth: Auth = Auth.auth()
    ) {
        self.db = db
        self.auth = auth
        self.privacyService = privacyService
        self.pendingScores = pendingScoreStore.load()
        
        // Best-effort: flush any pending scores on startup if we have an active circle
        Task {
            await flushPendingScoresIfNeeded()
        }
    }
    
    // MARK: - Helpers
    private var uid: String {
        auth.currentUser?.uid ?? "local_user"
    }
    
    private func requireActiveCircle() throws -> UUID {
        if let id = selectionStore.selectedGroupId {
            return id
        }
        throw NSError(domain: "FirebaseSocialService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No group selected. Create or join a group to share scores."])
    }
    
    private func generateJoinCode() -> String {
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in letters.randomElement() })
    }
    
    private func persistCircles(_ circles: [SocialCircle]) {
        circleStore.save(circles)
    }
    
    // MARK: - SocialService
    func ensureProfile(displayName: String?) async throws -> UserProfile {
        let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Player"
        let now = Date()
        let doc = db.collection("users").document(uid)
        let snapshot = try? await doc.getDocument()
        if let data = snapshot?.data(),
           let existingName = data["displayName"] as? String,
           let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() {
            return UserProfile(
                id: uid,
                displayName: existingName,
                createdAt: createdAt,
                updatedAt: now
            )
        }
        try await doc.setData([
            "displayName": name,
            "createdAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now)
        ], merge: true)
        return UserProfile(id: uid, displayName: name, createdAt: now, updatedAt: now)
    }
    
    func myProfile() async throws -> UserProfile {
        let doc = try await db.collection("users").document(uid).getDocument()
        let data = doc.data() ?? [:]
        let name = (data["displayName"] as? String)?.nonEmpty ?? "Player"
        let created = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updated = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        return UserProfile(id: uid, displayName: name, createdAt: created, updatedAt: updated)
    }
    
    func listFriends() async throws -> [UserProfile] {
        // Simple approach: derive friends from members of the active circle
        guard let activeId = selectionStore.selectedGroupId else { return [] }
        let circle = try await fetchCircleDocument(id: activeId)
        let memberIds = circle.memberIds
        guard !memberIds.isEmpty else { return [] }
        
        // Firestore "in" queries limited to 10; chunk if needed
        var profiles: [UserProfile] = []
        let chunks = memberIds.chunked(into: 10)
        for chunk in chunks {
            let snap = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            for doc in snap.documents {
                let data = doc.data()
                let name = (data["displayName"] as? String)?.nonEmpty ?? "Player"
                let created = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let updated = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                profiles.append(UserProfile(id: doc.documentID, displayName: name, createdAt: created, updatedAt: updated))
            }
        }
        return profiles
    }
    
    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws {
        let filtered = scores.filter { score in
            let game = Game.allAvailableGames.first(where: { $0.id == score.gameId })
            return privacyService.shouldShare(score: score, game: game)
        }
        guard !filtered.isEmpty else { return }
        let groupId = try requireActiveCircle()
        let batch = db.batch()
        
        for score in filtered {
            let docId = "\(uid)|\(score.dateInt)|\(score.gameId.uuidString)"
            let ref = db.collection("scores").document(docId)
            batch.setData([
                "userId": uid,
                "groupId": groupId.uuidString,
                "gameId": score.gameId.uuidString,
                "gameName": score.gameName,
                "dateInt": score.dateInt,
                "score": score.score as Any,
                "maxAttempts": score.maxAttempts,
                "completed": score.completed,
                "publishedAt": FieldValue.serverTimestamp()
            ], forDocument: ref, merge: true)
        }
        
        do {
            try await batch.commit()
            pendingScores.removeAll()
            pendingScoreStore.save(pendingScores)
        } catch {
            // Persist pending for retry
            pendingScores.append(contentsOf: filtered)
            pendingScoreStore.save(pendingScores)
            throw error
        }
    }
    
    private func flushPendingScoresIfNeeded() async {
        guard !pendingScores.isEmpty else { return }
        guard let active = selectionStore.selectedGroupId else { return }
        let filtered = pendingScores
        pendingScores.removeAll()
        pendingScoreStore.save(pendingScores)
        let batch = db.batch()
        for score in filtered {
            let docId = "\(uid)|\(score.dateInt)|\(score.gameId.uuidString)"
            let ref = db.collection("scores").document(docId)
            batch.setData([
                "userId": uid,
                "groupId": active.uuidString,
                "gameId": score.gameId.uuidString,
                "gameName": score.gameName,
                "dateInt": score.dateInt,
                "score": score.score as Any,
                "maxAttempts": score.maxAttempts,
                "completed": score.completed,
                "publishedAt": FieldValue.serverTimestamp()
            ], forDocument: ref, merge: true)
        }
        do {
            try await batch.commit()
        } catch {
            // Put them back for a later retry
            pendingScores.append(contentsOf: filtered)
            pendingScoreStore.save(pendingScores)
        }
    }
    
    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow] {
        let groupId = try requireActiveCircle()
        let startInt = startDateUTC.utcYYYYMMDD
        let endInt = endDateUTC.utcYYYYMMDD
        
        let snapshot = try await db.collection("scores")
            .whereField("groupId", isEqualTo: groupId.uuidString)
            .whereField("dateInt", isGreaterThanOrEqualTo: startInt)
            .whereField("dateInt", isLessThanOrEqualTo: endInt)
            .getDocuments()
        
        let scores: [DailyGameScore] = snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard
                let userId = data["userId"] as? String,
                let gameIdStr = data["gameId"] as? String,
                let gameId = UUID(uuidString: gameIdStr),
                let dateInt = data["dateInt"] as? Int
            else { return nil }
            let score = data["score"] as? Int
            let maxAttempts = data["maxAttempts"] as? Int ?? 6
            let completed = data["completed"] as? Bool ?? false
            let gameName = data["gameName"] as? String ?? "Game"
            return DailyGameScore(
                id: doc.documentID,
                userId: userId,
                dateInt: dateInt,
                gameId: gameId,
                gameName: gameName,
                score: score,
                maxAttempts: maxAttempts,
                completed: completed
            )
        }
        
        var perUser: [String: (name: String, total: Int, perGame: [UUID: Int])] = [:]
        for s in scores {
            let game = Game.allAvailableGames.first(where: { $0.id == s.gameId })
            let points = LeaderboardScoring.points(for: s, game: game)
            var entry = perUser[s.userId] ?? (name: s.userId, total: 0, perGame: [:])
            entry.total += points
            entry.perGame[s.gameId] = (entry.perGame[s.gameId] ?? 0) + points
            perUser[s.userId] = entry
        }
        
        let rows = perUser.map { (userId, agg) in
            LeaderboardRow(
                id: userId,
                userId: userId,
                displayName: agg.name,
                totalPoints: agg.total,
                perGameBreakdown: agg.perGame
            )
        }
        .sorted { $0.totalPoints > $1.totalPoints }
        
        return rows
    }
    
    // MARK: - Friend Discovery (stub)
    func discoverFriends(forceRefresh: Bool) async throws -> [DiscoveredFriend] {
        // For now, discovery comes from group membership
        let profiles = try await listFriends()
        return profiles.map { DiscoveredFriend(id: $0.id, displayName: $0.displayName, detail: "Friend") }
    }
    
    func addFriend(usingUsername username: String) async throws {
        // Placeholder: friends handled via groups for now
        _ = username
    }
    
    // MARK: - CircleManaging
    var activeCircleId: UUID? {
        selectionStore.selectedGroupId
    }
    
    func listCircles() async throws -> [SocialCircle] {
        let snap = try await db.collection("groups")
            .whereField("memberIds", arrayContains: uid)
            .getDocuments()
        let circles: [SocialCircle] = snap.documents.compactMap { doc in
            let data = doc.data()
            guard let name = data["name"] as? String else { return nil }
            let createdBy = data["ownerId"] as? String ?? ""
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let members = data["memberIds"] as? [String] ?? []
            guard let uuid = UUID(uuidString: doc.documentID) else { return nil }
            return SocialCircle(id: uuid, name: name, createdBy: createdBy, members: members, createdAt: createdAt)
        }
        persistCircles(circles)
        return circles
    }
    
    func createCircle(name: String) async throws -> SocialCircle {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CircleError.invalidName }
        let id = UUID()
        let joinCode = generateJoinCode()
        let now = Date()
        let ref = db.collection("groups").document(id.uuidString)
        try await ref.setData([
            "name": trimmed,
            "ownerId": uid,
            "joinCode": joinCode,
            "memberIds": [uid],
            "createdAt": Timestamp(date: now),
            "isPublic": false
        ])
        let circle = SocialCircle(id: id, name: trimmed, createdBy: uid, members: [uid], createdAt: now)
        selectionStore.setSelectedGroup(id: id, title: trimmed, joinCode: joinCode)
        var cached = circleStore.load()
        cached.append(circle)
        persistCircles(cached)
        Task { await flushPendingScoresIfNeeded() }
        return circle
    }
    
    func joinCircle(using code: String) async throws -> SocialCircle {
        let sanitized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !sanitized.isEmpty else { throw CircleError.invalidInviteCode }
        let query = db.collection("groups")
            .whereField("joinCode", isEqualTo: sanitized)
            .limit(to: 1)
        let snap = try await query.getDocuments()
        guard let doc = snap.documents.first else {
            throw CircleError.invalidInviteCode
        }
        try await doc.reference.updateData([
            "memberIds": FieldValue.arrayUnion([uid])
        ])
        let data = doc.data()
        let name = data["name"] as? String ?? "Friends"
        let owner = data["ownerId"] as? String ?? ""
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        guard let uuid = UUID(uuidString: doc.documentID) else { throw CircleError.invalidInviteCode }
        let members = data["memberIds"] as? [String] ?? []
        let circle = SocialCircle(id: uuid, name: name, createdBy: owner, members: members, createdAt: createdAt)
        selectionStore.setSelectedGroup(id: uuid, title: name, joinCode: sanitized)
        var cached = circleStore.load()
        if !cached.contains(where: { $0.id == uuid }) { cached.append(circle) }
        persistCircles(cached)
        Task { await flushPendingScoresIfNeeded() }
        return circle
    }
    
    func leaveCircle(id: UUID) async throws {
        try await db.collection("groups").document(id.uuidString).updateData([
            "memberIds": FieldValue.arrayRemove([uid])
        ])
        selectionStore.clearSelectedGroup()
        var cached = circleStore.load()
        cached.removeAll { $0.id == id }
        persistCircles(cached)
    }
    
    func selectCircle(id: UUID?) async {
        if let id {
            selectionStore.setSelectedGroup(id: id, title: nil, joinCode: nil)
        } else {
            selectionStore.clearSelectedGroup()
        }
    }
    
    // MARK: - Private Helpers
    private func fetchCircleDocument(id: UUID) async throws -> (joinCode: String, memberIds: [String]) {
        let doc = try await db.collection("groups").document(id.uuidString).getDocument()
        let data = doc.data() ?? [:]
        let code = data["joinCode"] as? String ?? ""
        let members = data["memberIds"] as? [String] ?? []
        return (code, members)
    }
}

// MARK: - Group selection persistence
private struct GroupSelectionStore {
    private let groupIdKey = "selected_firebase_group_id"
    private let groupTitleKey = "selected_firebase_group_title"
    private let joinCodeKey = "selected_firebase_join_code"
    
    var selectedGroupId: UUID? {
        if let raw = UserDefaults.standard.string(forKey: groupIdKey) {
            return UUID(uuidString: raw)
        }
        return nil
    }
    
    func setSelectedGroup(id: UUID, title: String?, joinCode: String?) {
        UserDefaults.standard.set(id.uuidString, forKey: groupIdKey)
        if let title { UserDefaults.standard.set(title, forKey: groupTitleKey) }
        if let joinCode { UserDefaults.standard.set(joinCode, forKey: joinCodeKey) }
    }
    
    func clearSelectedGroup() {
        UserDefaults.standard.removeObject(forKey: groupIdKey)
        UserDefaults.standard.removeObject(forKey: groupTitleKey)
        UserDefaults.standard.removeObject(forKey: joinCodeKey)
    }
}

// MARK: - Utilities
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

//
//  FirebaseSocialService.swift
//  StreakSync
//
//  Firebase-backed social service for leaderboards, groups, and friends.
//

import Foundation
import OSLog
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class FirebaseSocialService: SocialService, FriendDiscoveryProviding, CircleManaging, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.streaksync.app", category: "FirebaseSocialService")
    private let db: Firestore
    private let auth: Auth
    private let mockService: MockSocialService
    private let circleStore = SocialCircleStore()
    private let selectionKey = "firebase_selected_circle_id"
    
    private var selectedCircleId: UUID? {
        get {
            if let stored = UserDefaults.standard.string(forKey: selectionKey) {
                return UUID(uuidString: stored)
            }
            return nil
        }
        set {
            if let id = newValue {
                UserDefaults.standard.set(id.uuidString, forKey: selectionKey)
            } else {
                UserDefaults.standard.removeObject(forKey: selectionKey)
            }
        }
    }
    
    init(db: Firestore = Firestore.firestore(), auth: Auth = Auth.auth()) {
        self.db = db
        self.auth = auth
        self.mockService = MockSocialService()
    }
    
    // MARK: - CircleManaging
    var activeCircleId: UUID? { selectedCircleId }
    
    func listCircles() async throws -> [SocialCircle] {
        let uid = currentUserId()
        let snapshot = try await db.collection("groups")
            .whereField("memberIds", arrayContains: uid)
            .getDocuments()
        
        let circles: [SocialCircle] = snapshot.documents.compactMap { doc in
            guard let ownerId = doc.data()["ownerId"] as? String,
                  let name = doc.data()["name"] as? String,
                  let createdAt = (doc.data()["createdAt"] as? Timestamp)?.dateValue(),
                  let members = doc.data()["memberIds"] as? [String],
                  let uuid = UUID(uuidString: doc.documentID)
            else { return nil }
            return SocialCircle(id: uuid, name: name, createdBy: ownerId, members: members, createdAt: createdAt)
        }
        circleStore.save(circles)
        return circles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    func createCircle(name: String) async throws -> SocialCircle {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CircleError.invalidName }
        let uid = currentUserId()
        let circleId = UUID()
        let joinCode = FirebaseSocialService.generateJoinCode()
        let now = Date()
        
        let data: [String: Any] = [
            "name": trimmed,
            "ownerId": uid,
            "joinCode": joinCode,
            "memberIds": [uid],
            "createdAt": Timestamp(date: now),
            "isPublic": false
        ]
        
        try await db.collection("groups").document(circleId.uuidString).setData(data)
        let circle = SocialCircle(id: circleId, name: trimmed, createdBy: uid, members: [uid], createdAt: now)
        selectedCircleId = circleId
        persistCircle(circle)
        return circle
    }
    
    func joinCircle(using code: String) async throws -> SocialCircle {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { throw CircleError.invalidInviteCode }
        let uid = currentUserId()
        
        let query = db.collection("groups").whereField("joinCode", isEqualTo: trimmed).limit(to: 1)
        let snapshot = try await query.getDocuments()
        guard let doc = snapshot.documents.first else { throw CircleError.invalidInviteCode }
        
        try await doc.reference.updateData([
            "memberIds": FieldValue.arrayUnion([uid])
        ])
        
        let data = doc.data()
        guard let name = data["name"] as? String,
              let ownerId = data["ownerId"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let members = data["memberIds"] as? [String] ?? [uid],
              let uuid = UUID(uuidString: doc.documentID)
        else { throw CircleError.invalidInviteCode }
        
        let circle = SocialCircle(id: uuid, name: name, createdBy: ownerId, members: members, createdAt: createdAt)
        selectedCircleId = uuid
        persistCircle(circle)
        return circle
    }
    
    func leaveCircle(id: UUID) async throws {
        let uid = currentUserId()
        let ref = db.collection("groups").document(id.uuidString)
        try await ref.updateData([
            "memberIds": FieldValue.arrayRemove([uid])
        ])
        if activeCircleId == id {
            selectedCircleId = nil
        }
    }
    
    func selectCircle(id: UUID?) async {
        selectedCircleId = id
    }
    
    // MARK: - SocialService
    func ensureProfile(displayName: String?) async throws -> UserProfile {
        if let existing = try? await myProfile() { return existing }
        let uid = currentUserId()
        let now = Date()
        let name = (displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? displayName! : "Player"
        let data: [String: Any] = [
            "displayName": name,
            "createdAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now)
        ]
        try await db.collection("users").document(uid).setData(data, merge: true)
        let profile = UserProfile(id: uid, displayName: name, createdAt: now, updatedAt: now)
        return profile
    }
    
    func myProfile() async throws -> UserProfile {
        let uid = currentUserId()
        let snapshot = try? await db.collection("users").document(uid).getDocument()
        if let doc = snapshot, doc.exists, let data = doc.data(),
           let name = data["displayName"] as? String {
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
            return UserProfile(id: uid, displayName: name, createdAt: createdAt, updatedAt: updatedAt)
        }
        return try await ensureProfile(displayName: nil)
    }
    
    func listFriends() async throws -> [UserProfile] {
        // For now, derive friends from members of the active circle (excluding self)
        guard let circleId = activeCircleId else { return [] }
        let ref = db.collection("groups").document(circleId.uuidString)
        let doc = try await ref.getDocument()
        guard let data = doc.data(),
              let memberIds = data["memberIds"] as? [String]
        else { return [] }
        let others = memberIds.filter { $0 != currentUserId() }
        var friends: [UserProfile] = []
        for uid in others {
            let udoc = try? await db.collection("users").document(uid).getDocument()
            if let udata = udoc?.data(),
               let name = udata["displayName"] as? String {
                let createdAt = (udata["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let updatedAt = (udata["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
                friends.append(UserProfile(id: uid, displayName: name, createdAt: createdAt, updatedAt: updatedAt))
            } else {
                friends.append(UserProfile(id: uid, displayName: "Friend", createdAt: Date(), updatedAt: Date()))
            }
        }
        return friends
    }
    
    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws {
        guard let circleId = activeCircleId else {
            try await mockService.publishDailyScores(dateUTC: dateUTC, scores: scores)
            return
        }
        let batch = db.batch()
        let uid = currentUserId()
        
        for score in scores where shouldShare(score: score) {
            let recordId = "\(uid)|\(score.dateInt)|\(score.gameId.uuidString)"
            let ref = db.collection("scores").document(recordId)
            batch.setData([
                "userId": uid,
                "groupId": circleId.uuidString,
                "gameId": score.gameId.uuidString,
                "gameName": score.gameName,
                "dateInt": score.dateInt,
                "score": score.score as Any,
                "maxAttempts": score.maxAttempts,
                "completed": score.completed,
                "metadata": [
                    "publishedAt": FieldValue.serverTimestamp()
                ]
            ], forDocument: ref, merge: true)
        }
        
        do {
            try await batch.commit()
            logger.info("✅ Published \(scores.count) scores to Firebase")
        } catch {
            logger.error("❌ Firebase publish failed: \(error.localizedDescription)")
            try await mockService.publishDailyScores(dateUTC: dateUTC, scores: scores)
            throw error
        }
    }
    
    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow] {
        guard let circleId = activeCircleId else {
            return try await mockService.fetchLeaderboard(startDateUTC: startDateUTC, endDateUTC: endDateUTC)
        }
        let startInt = startDateUTC.utcYYYYMMDD
        let endInt = endDateUTC.utcYYYYMMDD
        
        let snapshot = try await db.collection("scores")
            .whereField("groupId", isEqualTo: circleId.uuidString)
            .whereField("dateInt", isGreaterThanOrEqualTo: startInt)
            .whereField("dateInt", isLessThanOrEqualTo: endInt)
            .getDocuments()
        
        let userDisplayNames = try await fetchDisplayNames(for: snapshot.documents)
        var perUser: [String: (name: String, total: Int, perGame: [UUID: Int])] = [:]
        
        for doc in snapshot.documents {
            let data = doc.data()
            guard let uid = data["userId"] as? String,
                  let gameIdString = data["gameId"] as? String,
                  let gameId = UUID(uuidString: gameIdString),
                  let dateInt = data["dateInt"] as? Int,
                  dateInt >= startInt, dateInt <= endInt
            else { continue }
            let scoreVal = data["score"] as? Int
            let maxAttempts = data["maxAttempts"] as? Int ?? 6
            let completed = data["completed"] as? Bool ?? false
            let gameName = data["gameName"] as? String ?? ""
            let displayName = userDisplayNames[uid] ?? uid
            let dgs = DailyGameScore(id: doc.documentID, userId: uid, dateInt: dateInt, gameId: gameId, gameName: gameName, score: scoreVal, maxAttempts: maxAttempts, completed: completed)
            let game = Game.allAvailableGames.first(where: { $0.id == gameId })
            let points = LeaderboardScoring.points(for: dgs, game: game)
            var agg = perUser[uid] ?? (name: displayName, total: 0, perGame: [:])
            agg.total += points
            agg.perGame[gameId] = (agg.perGame[gameId] ?? 0) + points
            perUser[uid] = agg
        }
        
        let rows = perUser.map { (userId, agg) in
            LeaderboardRow(id: userId, userId: userId, displayName: agg.name, totalPoints: agg.total, perGameBreakdown: agg.perGame)
        }.sorted { $0.totalPoints > $1.totalPoints }
        
        if rows.isEmpty {
            return try await mockService.fetchLeaderboard(startDateUTC: startDateUTC, endDateUTC: endDateUTC)
        }
        return rows
    }
    
    // MARK: - FriendDiscoveryProviding
    func discoverFriends(forceRefresh: Bool) async throws -> [DiscoveredFriend] {
        // Minimal implementation: derive from groups the user belongs to
        let circles = try await listCircles()
        let uid = currentUserId()
        var friends: [DiscoveredFriend] = []
        for circle in circles {
            for member in circle.members where member != uid {
                friends.append(DiscoveredFriend(id: member, displayName: "Friend", detail: circle.name))
            }
        }
        return friends
    }
    
    func addFriend(usingUsername username: String) async throws {
        // Placeholder: in this design, friends are derived from groups. No-op.
        logger.info("ℹ️ addFriend(usingUsername:) is not implemented; use join codes instead.")
    }
    
    // MARK: - Helpers
    private func currentUserId() -> String {
        auth.currentUser?.uid ?? "local_user"
    }
    
    private func fetchDisplayNames(for docs: [QueryDocumentSnapshot]) async throws -> [String: String] {
        let userIds = Set(docs.compactMap { $0.data()["userId"] as? String })
        var map: [String: String] = [:]
        for uid in userIds {
            let udoc = try? await db.collection("users").document(uid).getDocument()
            if let name = udoc?.data()?["displayName"] as? String {
                map[uid] = name
            }
        }
        return map
    }
    
    private func shouldShare(score: DailyGameScore) -> Bool {
        let game = Game.allAvailableGames.first(where: { $0.id == score.gameId })
        return SocialSettingsService.shared.shouldShare(score: score, game: game)
    }
    
    private func persistCircle(_ circle: SocialCircle) {
        var circles = circleStore.load()
        if let idx = circles.firstIndex(where: { $0.id == circle.id }) {
            circles[idx] = circle
        } else {
            circles.append(circle)
        }
        circleStore.save(circles)
    }
    
    private static func generateJoinCode(length: Int = 6) -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }
}
//
//  FirebaseSocialService.swift
//  StreakSync
//
//  Firebase-backed social service (groups, join codes, scores).
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class FirebaseSocialService: SocialService, FriendDiscoveryProviding, CircleManaging, @unchecked Sendable {
    private let db: Firestore
    private let auth: Auth
    private let settingsService: SocialSettingsService
    private let groupStoreKey = "social_firebase_active_group"
    
    private(set) var activeCircleId: UUID? {
        didSet {
            if let id = activeCircleId {
                UserDefaults.standard.set(id.uuidString, forKey: groupStoreKey)
            } else {
                UserDefaults.standard.removeObject(forKey: groupStoreKey)
            }
        }
    }
    
    init(settingsService: SocialSettingsService = .shared, db: Firestore = Firestore.firestore(), auth: Auth = Auth.auth()) {
        self.db = db
        self.auth = auth
        self.settingsService = settingsService
        if let stored = UserDefaults.standard.string(forKey: groupStoreKey),
           let gid = UUID(uuidString: stored) {
            self.activeCircleId = gid
        } else {
            self.activeCircleId = nil
        }
    }
    
    // MARK: - SocialService
    func ensureProfile(displayName: String?) async throws -> UserProfile {
        let uid = try currentUserId()
        let now = Date()
        let profile = UserProfile(id: uid, displayName: displayName?.nonEmpty ?? "Player", createdAt: now, updatedAt: now)
        try await db.collection("users").document(uid).setData([
            "displayName": profile.displayName,
            "createdAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now)
        ], merge: true)
        return profile
    }
    
    func myProfile() async throws -> UserProfile {
        let uid = try currentUserId()
        let snap = try await db.collection("users").document(uid).getDocument()
        let now = Date()
        if let data = snap.data(),
           let name = data["displayName"] as? String,
           let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
           let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() {
            return UserProfile(id: uid, displayName: name, createdAt: createdAt, updatedAt: updatedAt)
        } else {
            let profile = UserProfile(id: uid, displayName: "Player", createdAt: now, updatedAt: now)
            try await db.collection("users").document(uid).setData([
                "displayName": profile.displayName,
                "createdAt": Timestamp(date: now),
                "updatedAt": Timestamp(date: now)
            ], merge: true)
            return profile
        }
    }
    
    func listFriends() async throws -> [UserProfile] {
        // Simple placeholder: friends derived from group membership
        guard let gid = activeCircleId else { return [] }
        let groupDoc = try await db.collection("groups").document(gid.uuidString).getDocument()
        guard let data = groupDoc.data(),
              let memberIds = data["memberIds"] as? [String] else { return [] }
        var profiles: [UserProfile] = []
        for uid in memberIds {
            let snap = try? await db.collection("users").document(uid).getDocument()
            let name = snap?.data()?["displayName"] as? String ?? "Friend"
            let now = Date()
            profiles.append(UserProfile(id: uid, displayName: name, createdAt: now, updatedAt: now))
        }
        return profiles
    }
    
    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws {
        guard let gid = activeCircleId else { return }
        let uid = try currentUserId()
        let batch = db.batch()
        let dateInt = dateUTC.utcYYYYMMDD
        for score in scores where settingsService.shouldShare(score: score, game: Game.allAvailableGames.first(where: { $0.id == score.gameId })) {
            let docId = "\(uid)|\(dateInt)|\(score.gameId.uuidString)"
            let ref = db.collection("scores").document(docId)
            batch.setData([
                "userId": uid,
                "groupId": gid.uuidString,
                "gameId": score.gameId.uuidString,
                "gameName": score.gameName,
                "dateInt": dateInt,
                "score": score.score ?? 0,
                "maxAttempts": score.maxAttempts,
                "completed": score.completed,
                "publishedAt": Timestamp(date: Date())
            ], forDocument: ref, merge: true)
        }
        try await batch.commit()
    }
    
    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow] {
        guard let gid = activeCircleId else { return [] }
        let startInt = startDateUTC.utcYYYYMMDD
        let endInt = endDateUTC.utcYYYYMMDD
        let snapshot = try await db.collection("scores")
            .whereField("groupId", isEqualTo: gid.uuidString)
            .whereField("dateInt", isGreaterThanOrEqualTo: startInt)
            .whereField("dateInt", isLessThanOrEqualTo: endInt)
            .getDocuments()
        
        var perUser: [String: (name: String, total: Int, perGame: [UUID: Int])] = [:]
        for doc in snapshot.documents {
            let data = doc.data()
            guard let userId = data["userId"] as? String,
                  let gameIdString = data["gameId"] as? String,
                  let gameId = UUID(uuidString: gameIdString),
                  let dateInt = data["dateInt"] as? Int,
                  let maxAttempts = data["maxAttempts"] as? Int else { continue }
            let scoreVal = data["score"] as? Int
            let completed = data["completed"] as? Bool ?? false
            let gameName = data["gameName"] as? String ?? "Game"
            let score = DailyGameScore(id: doc.documentID, userId: userId, dateInt: dateInt, gameId: gameId, gameName: gameName, score: scoreVal, maxAttempts: maxAttempts, completed: completed)
            let game = Game.allAvailableGames.first(where: { $0.id == gameId })
            let points = LeaderboardScoring.points(for: score, game: game)
            var entry = perUser[userId] ?? (name: userId, total: 0, perGame: [:])
            entry.total += points
            entry.perGame[gameId] = (entry.perGame[gameId] ?? 0) + points
            perUser[userId] = entry
        }
        
        let rows = perUser.map { (userId, agg) in
            LeaderboardRow(id: userId, userId: userId, displayName: agg.name, totalPoints: agg.total, perGameBreakdown: agg.perGame)
        }.sorted { $0.totalPoints > $1.totalPoints }
        return rows
    }
    
    // MARK: - CircleManaging
    func listCircles() async throws -> [SocialCircle] {
        let uid = try currentUserId()
        let snapshot = try await db.collection("groups")
            .whereField("memberIds", arrayContains: uid)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            guard let name = doc.data()["name"] as? String,
                  let ownerId = doc.data()["ownerId"] as? String,
                  let ts = doc.data()["createdAt"] as? Timestamp else { return nil }
            return SocialCircle(id: UUID(uuidString: doc.documentID) ?? UUID(), name: name, createdBy: ownerId, members: [], createdAt: ts.dateValue())
        }
    }
    
    func createCircle(name: String) async throws -> SocialCircle {
        let uid = try currentUserId()
        let gid = UUID()
        let joinCode = Self.makeJoinCode()
        let now = Date()
        let ref = db.collection("groups").document(gid.uuidString)
        try await ref.setData([
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "ownerId": uid,
            "joinCode": joinCode,
            "memberIds": [uid],
            "createdAt": Timestamp(date: now),
            "isPublic": false
        ])
        let circle = SocialCircle(id: gid, name: name, createdBy: uid, members: [uid], createdAt: now)
        activeCircleId = gid
        return circle
    }
    
    func joinCircle(using code: String) async throws -> SocialCircle {
        let uid = try currentUserId()
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let query = try await db.collection("groups")
            .whereField("joinCode", isEqualTo: normalized)
            .limit(to: 1)
            .getDocuments()
        guard let doc = query.documents.first else { throw SocialServiceError.invalidJoinCode }
        try await doc.reference.updateData([
            "memberIds": FieldValue.arrayUnion([uid])
        ])
        let data = doc.data()
        let name = data["name"] as? String ?? "Friends"
        let ownerId = data["ownerId"] as? String ?? uid
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let circle = SocialCircle(id: UUID(uuidString: doc.documentID) ?? UUID(), name: name, createdBy: ownerId, members: [], createdAt: createdAt)
        activeCircleId = circle.id
        return circle
    }
    
    func leaveCircle(id: UUID) async throws {
        let uid = try currentUserId()
        let ref = db.collection("groups").document(id.uuidString)
        try await ref.updateData([
            "memberIds": FieldValue.arrayRemove([uid])
        ])
        if activeCircleId == id {
            activeCircleId = nil
        }
    }
    
    func selectCircle(id: UUID?) async {
        activeCircleId = id
    }
    
    // MARK: - FriendDiscoveryProviding
    func discoverFriends(forceRefresh: Bool) async throws -> [DiscoveredFriend] {
        // Derive from current group membership
        let circles = try await listCircles()
        var map: [String: DiscoveredFriend] = [:]
        for circle in circles {
            let doc = try await db.collection("groups").document(circle.id.uuidString).getDocument()
            let members = doc.data()?["memberIds"] as? [String] ?? []
            for uid in members {
                let name = try? await db.collection("users").document(uid).getDocument().data()?["displayName"] as? String
                map[uid] = DiscoveredFriend(id: uid, displayName: name ?? "Friend", detail: circle.name)
            }
        }
        return Array(map.values)
    }
    
    func addFriend(usingUsername username: String) async throws {
        // Username-based friend requests not yet implemented for Firebase; no-op
        throw SocialServiceError.notSupported
    }
    
    // MARK: - Helpers
    private func currentUserId() throws -> String {
        if let uid = auth.currentUser?.uid { return uid }
        throw SocialServiceError.notAuthenticated
    }
    
    private static func makeJoinCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var code = ""
        for _ in 0..<6 { code.append(chars.randomElement() ?? "A") }
        return code
    }
}

enum SocialServiceError: LocalizedError {
    case notAuthenticated
    case noActiveGroup
    case invalidJoinCode
    case notSupported
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue."
        case .noActiveGroup:
            return "Select or create a group first."
        case .invalidJoinCode:
            return "That join code is invalid."
        case .notSupported:
            return "This action is not supported yet."
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

