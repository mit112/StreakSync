//
//  FirebaseSocialService.swift
//  StreakSync
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Errors
enum CircleError: LocalizedError {
    case invalidName
    case invalidInviteCode
    
    var errorDescription: String? {
        switch self {
        case .invalidName: return "Please enter a group name."
        case .invalidInviteCode: return "That join code is invalid."
        }
    }
}

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
        Task { await flushPendingScoresIfNeeded() }
    }
    
    // MARK: - Helpers
    private var uid: String {
        auth.currentUser?.uid ?? "local_user"
    }
    
    private func requireActiveCircle() throws -> UUID {
        guard let id = selectionStore.selectedGroupId else { throw CircleError.invalidInviteCode }
        return id
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
            return UserProfile(id: uid, displayName: existingName, createdAt: createdAt, updatedAt: now)
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
        guard let activeId = selectionStore.selectedGroupId else { return [] }
        let circle = try await fetchCircleDocument(id: activeId)
        let memberIds = circle.memberIds
        guard !memberIds.isEmpty else { return [] }
        
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
        
        return perUser.map { (userId, agg) in
            LeaderboardRow(id: userId, userId: userId, displayName: agg.name, totalPoints: agg.total, perGameBreakdown: agg.perGame)
        }
        .sorted { $0.totalPoints > $1.totalPoints }
    }
    
    // MARK: - Friend Discovery
    func discoverFriends(forceRefresh: Bool) async throws -> [DiscoveredFriend] {
        let profiles = try await listFriends()
        return profiles.map { DiscoveredFriend(id: $0.id, displayName: $0.displayName, detail: "Friend") }
    }
    
    func addFriend(usingUsername username: String) async throws {
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
        try await db.collection("groups").document(id.uuidString).setData([
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
        let snap = try await db.collection("groups")
            .whereField("joinCode", isEqualTo: sanitized)
            .limit(to: 1)
            .getDocuments()
        guard let doc = snap.documents.first else { throw CircleError.invalidInviteCode }
        
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

