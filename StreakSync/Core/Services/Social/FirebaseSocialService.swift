//
//  FirebaseSocialService.swift
//  StreakSync
//
//  Core class definition, error types, and profile methods for the Firebase social service.
//  Friends, scores, and leaderboard logic live in extension files.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
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
    let db: Firestore
    let auth: Auth
    let privacyService: SocialSettingsService
    let pendingScoreStore = PendingScoreStore()
    var pendingScores: [DailyGameScore]
    let logger = Logger(subsystem: "com.streaksync.app", category: "FirebaseSocialService")
    private var authStateListener: AuthStateDidChangeListenerHandle?

    // MARK: - Friends Cache (TTL-based, invalidated on friendship mutations)
    var cachedFriends: [UserProfile]?
    var friendsCacheTimestamp: Date?
    let friendsCacheTTL: TimeInterval = 60 // seconds

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

    var uid: String? { auth.currentUser?.uid }

    func requireUID() throws -> String {
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
}
