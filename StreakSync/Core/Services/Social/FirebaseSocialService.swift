//
//  FirebaseSocialService.swift
//  StreakSync
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

import OSLog

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
    
    /// Whether this error indicates the operation should be retried later
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .quotaExceeded, .serverError:
            return true
        case .notAuthenticated, .permissionDenied, .documentNotFound, .invalidData:
            return false
        }
    }
    
    /// Creates a FirebaseSocialError from a Firestore error
    static func from(_ error: Error) -> FirebaseSocialError {
        let nsError = error as NSError
        
        // Check for Firestore error codes
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

@MainActor
final class FirebaseSocialService: SocialService, FriendDiscoveryProviding, CircleManaging {
    private let db: Firestore
    private let auth: Auth
    private let privacyService: SocialSettingsService
    private let circleStore = SocialCircleStore()
    private let pendingScoreStore = PendingScoreStore()
    private var pendingScores: [DailyGameScore]
    private let selectionStore = GroupSelectionStore()
    private let logger = Logger(subsystem: "com.streaksync.app", category: "FirebaseSocialService")
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    /// Number of scores waiting to be synced to Firebase (thread-safe via UserDefaults)
    nonisolated var pendingScoreCount: Int { PendingScoreStore().load().count }
    
    init(
        privacyService: SocialSettingsService = .shared,
        db: Firestore = Firestore.firestore(),
        auth: Auth = Auth.auth()
    ) {
        self.db = db
        self.auth = auth
        self.privacyService = privacyService
        self.pendingScores = pendingScoreStore.load()
        
        // Listen for auth state changes to flush pending scores when user becomes authenticated
        setupAuthStateListener()
        
        Task { await flushPendingScoresIfNeeded() }
    }
    
    // Note: No deinit needed - this service lives for the app's entire lifecycle.
    // The auth listener will be cleaned up automatically when the app terminates.
    
    /// Sets up a listener to react to auth state changes
    private func setupAuthStateListener() {
        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            
            if user != nil {
                // User just became authenticated - try to flush any pending scores
                Task { @MainActor in
                    self.logger.info("🔐 Auth state changed - user authenticated, flushing pending scores")
                    await self.flushPendingScoresIfNeeded()
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    /// The current user's UID, or nil if not authenticated
    private var uid: String? {
        auth.currentUser?.uid
    }
    
    /// Returns the current user's UID or throws if not authenticated
    private func requireUID() throws -> String {
        guard let uid = uid else {
            logger.warning("⚠️ Attempted Firebase operation without authentication")
            throw FirebaseSocialError.notAuthenticated
        }
        return uid
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
        let currentUID = try requireUID()
        let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Player"
        let now = Date()
        let doc = db.collection("users").document(currentUID)
        
        do {
            let snapshot = try await doc.getDocument()
            if let data = snapshot.data(),
               let existingName = data["displayName"] as? String,
               let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() {
                return UserProfile(id: currentUID, displayName: existingName, createdAt: createdAt, updatedAt: now)
            }
            try await doc.setData([
                "displayName": name,
                "createdAt": Timestamp(date: now),
                "updatedAt": Timestamp(date: now)
            ], merge: true)
            return UserProfile(id: currentUID, displayName: name, createdAt: now, updatedAt: now)
        } catch {
            logger.error("❌ Failed to ensure profile: \(error.localizedDescription)")
            throw FirebaseSocialError.from(error)
        }
    }
    
    func myProfile() async throws -> UserProfile {
        let currentUID = try requireUID()
        
        do {
            let doc = try await db.collection("users").document(currentUID).getDocument()
            let data = doc.data() ?? [:]
            let name = (data["displayName"] as? String)?.nonEmpty ?? "Player"
            let created = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let updated = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
            return UserProfile(id: currentUID, displayName: name, createdAt: created, updatedAt: updated)
        } catch {
            logger.error("❌ Failed to fetch profile: \(error.localizedDescription)")
            throw FirebaseSocialError.from(error)
        }
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
        let currentUID = try requireUID()
        
        let filtered = scores.filter { score in
            let game = Game.allAvailableGames.first(where: { $0.id == score.gameId })
            return privacyService.shouldShare(score: score, game: game)
        }
        guard !filtered.isEmpty else { return }
        let groupId = try requireActiveCircle()
        let batch = db.batch()
        
        for score in filtered {
            let docId = "\(currentUID)|\(score.dateInt)|\(score.gameId.uuidString)"
            let ref = db.collection("scores").document(docId)
            batch.setData([
                "userId": currentUID,
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
            logger.info("✅ Published \(filtered.count) scores to Firebase")
        } catch {
            let socialError = FirebaseSocialError.from(error)
            
            // Queue for retry if it's a retryable error
            if socialError.isRetryable {
                pendingScores.append(contentsOf: filtered)
                pendingScoreStore.save(pendingScores)
                logger.warning("⚠️ Queued \(filtered.count) scores for retry: \(socialError.localizedDescription ?? "unknown")")
            } else {
                logger.error("❌ Failed to publish scores (non-retryable): \(error.localizedDescription)")
            }
            
            throw socialError
        }
    }
    
    private func flushPendingScoresIfNeeded() async {
        guard !pendingScores.isEmpty else { return }
        guard let active = selectionStore.selectedGroupId else { return }
        
        // Silently skip if not authenticated - will retry when auth is established
        guard let currentUID = uid else {
            logger.debug("⏳ Skipping pending score flush - not authenticated")
            return
        }
        
        let filtered = pendingScores
        pendingScores.removeAll()
        pendingScoreStore.save(pendingScores)
        
        let batch = db.batch()
        for score in filtered {
            let docId = "\(currentUID)|\(score.dateInt)|\(score.gameId.uuidString)"
            let ref = db.collection("scores").document(docId)
            batch.setData([
                "userId": currentUID,
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
            logger.info("✅ Flushed \(filtered.count) pending scores")
        } catch {
            let socialError = FirebaseSocialError.from(error)
            
            // Re-queue if retryable
            if socialError.isRetryable {
                pendingScores.append(contentsOf: filtered)
                pendingScoreStore.save(pendingScores)
                logger.warning("⚠️ Re-queued \(filtered.count) scores after flush failure")
            } else {
                logger.error("❌ Lost \(filtered.count) scores due to non-retryable error: \(error.localizedDescription)")
            }
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
        
        // Collect unique user IDs and fetch their display names
        let uniqueUserIds = Array(Set(scores.map { $0.userId }))
        let userNames = await fetchDisplayNames(for: uniqueUserIds)
        
        var perUser: [String: (name: String, total: Int, perGame: [UUID: Int])] = [:]
        for s in scores {
            let game = Game.allAvailableGames.first(where: { $0.id == s.gameId })
            let points = LeaderboardScoring.points(for: s, game: game)
            let displayName = userNames[s.userId] ?? "Player"
            var entry = perUser[s.userId] ?? (name: displayName, total: 0, perGame: [:])
            entry.total += points
            entry.perGame[s.gameId] = (entry.perGame[s.gameId] ?? 0) + points
            perUser[s.userId] = entry
        }
        
        return perUser.map { (userId, agg) in
            LeaderboardRow(id: userId, userId: userId, displayName: agg.name, totalPoints: agg.total, perGameBreakdown: agg.perGame)
        }
        .sorted { $0.totalPoints > $1.totalPoints }
    }
    
    /// Fetches display names for a list of user IDs (batched for Firestore limits)
    private func fetchDisplayNames(for userIds: [String]) async -> [String: String] {
        guard !userIds.isEmpty else { return [:] }
        
        var names: [String: String] = [:]
        let chunks = userIds.chunked(into: 10) // Firestore 'in' query limit
        
        for chunk in chunks {
            do {
                let snap = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                for doc in snap.documents {
                    let data = doc.data()
                    let name = (data["displayName"] as? String)?.nonEmpty ?? "Player"
                    names[doc.documentID] = name
                }
            } catch {
                logger.warning("⚠️ Failed to fetch display names: \(error.localizedDescription)")
                // Continue with partial results
            }
        }
        
        return names
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
        let currentUID = try requireUID()
        
        do {
            let snap = try await db.collection("groups")
                .whereField("memberIds", arrayContains: currentUID)
                .getDocuments()
            let circles: [SocialCircle] = snap.documents.compactMap { doc in
                let data = doc.data()
                guard let name = data["name"] as? String else { return nil }
                let createdBy = data["ownerId"] as? String ?? ""
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let members = data["memberIds"] as? [String] ?? []
                let joinCode = data["joinCode"] as? String
                guard let uuid = UUID(uuidString: doc.documentID) else { return nil }
                return SocialCircle(id: uuid, name: name, createdBy: createdBy, members: members, createdAt: createdAt, joinCode: joinCode)
            }
            persistCircles(circles)
            logger.debug("📋 Fetched \(circles.count) circles")
            return circles
        } catch {
            logger.error("❌ Failed to list circles: \(error.localizedDescription)")
            throw FirebaseSocialError.from(error)
        }
    }
    
    func createCircle(name: String) async throws -> SocialCircle {
        let currentUID = try requireUID()
        
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CircleError.invalidName }
        
        let id = UUID()
        let joinCode = generateJoinCode()
        let now = Date()
        
        do {
            try await db.collection("groups").document(id.uuidString).setData([
                "name": trimmed,
                "ownerId": currentUID,
                "joinCode": joinCode,
                "memberIds": [currentUID],
                "createdAt": Timestamp(date: now),
                "isPublic": false
            ])
            
            let circle = SocialCircle(id: id, name: trimmed, createdBy: currentUID, members: [currentUID], createdAt: now, joinCode: joinCode)
            selectionStore.setSelectedGroup(id: id, title: trimmed, joinCode: joinCode)
            var cached = circleStore.load()
            cached.append(circle)
            persistCircles(cached)
            
            logger.info("✅ Created circle '\(trimmed)' with join code \(joinCode)")
            
            Task { await flushPendingScoresIfNeeded() }
            return circle
        } catch {
            logger.error("❌ Failed to create circle: \(error.localizedDescription)")
            throw FirebaseSocialError.from(error)
        }
    }
    
    func joinCircle(using code: String) async throws -> SocialCircle {
        let currentUID = try requireUID()
        
        let sanitized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !sanitized.isEmpty else { throw CircleError.invalidInviteCode }
        
        do {
            let snap = try await db.collection("groups")
                .whereField("joinCode", isEqualTo: sanitized)
                .limit(to: 1)
                .getDocuments()
            guard let doc = snap.documents.first else { throw CircleError.invalidInviteCode }
            
            try await doc.reference.updateData([
                "memberIds": FieldValue.arrayUnion([currentUID])
            ])
            
            let data = doc.data()
            let name = data["name"] as? String ?? "Friends"
            let owner = data["ownerId"] as? String ?? ""
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let joinCode = data["joinCode"] as? String ?? sanitized
            guard let uuid = UUID(uuidString: doc.documentID) else { throw CircleError.invalidInviteCode }
            let members = data["memberIds"] as? [String] ?? []
            let circle = SocialCircle(id: uuid, name: name, createdBy: owner, members: members, createdAt: createdAt, joinCode: joinCode)
            selectionStore.setSelectedGroup(id: uuid, title: name, joinCode: joinCode)
            var cached = circleStore.load()
            if !cached.contains(where: { $0.id == uuid }) { cached.append(circle) }
            persistCircles(cached)
            
            logger.info("✅ Joined circle '\(name)'")
            
            Task { await flushPendingScoresIfNeeded() }
            return circle
        } catch let error as CircleError {
            throw error
        } catch {
            logger.error("❌ Failed to join circle: \(error.localizedDescription)")
            throw FirebaseSocialError.from(error)
        }
    }
    
    func leaveCircle(id: UUID) async throws {
        let currentUID = try requireUID()
        
        do {
            try await db.collection("groups").document(id.uuidString).updateData([
                "memberIds": FieldValue.arrayRemove([currentUID])
            ])
            selectionStore.clearSelectedGroup()
            var cached = circleStore.load()
            cached.removeAll { $0.id == id }
            persistCircles(cached)
            
            logger.info("✅ Left circle \(id.uuidString)")
        } catch {
            logger.error("❌ Failed to leave circle: \(error.localizedDescription)")
            throw FirebaseSocialError.from(error)
        }
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

