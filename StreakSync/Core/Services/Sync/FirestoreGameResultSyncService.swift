//
//  FirestoreGameResultSyncService.swift
//  StreakSync
//
//  Firestore-based sync for GameResult records.
//  Leverages Firestore's built-in offline persistence — no manual offline queue needed.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import OSLog

// MARK: - Sync State

enum SyncState: Equatable {
    case notStarted
    case syncing
    case synced(lastSyncDate: Date)
    case failed(Error)
    case offline

    static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted), (.syncing, .syncing), (.offline, .offline):
            return true
        case (.synced(let a), .synced(let b)):
            return a == b
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

// MARK: - Firestore GameResult Sync Service

@MainActor
@Observable
final class FirestoreGameResultSyncService {

    // MARK: - Public State

    var syncState: SyncState = .notStarted

    // MARK: - Private

    @ObservationIgnored private weak var appState: AppState?
    @ObservationIgnored private let logger = Logger(subsystem: "com.streaksync.app", category: "FirestoreGameResultSync")

    private var db: Firestore { Firestore.firestore() }

    private var currentUserId: String? { Auth.auth().currentUser?.uid }

    /// Key for persisting last successful sync timestamp per user.
    private var lastSyncKey: String? {
        guard let uid = currentUserId else { return nil }
        return "gameResultSync_lastTimestamp_\(uid)"
    }

    private var lastSyncTimestamp: Date? {
        guard let key = lastSyncKey else { return nil }
        let ti = UserDefaults.standard.double(forKey: key)
        return ti > 0 ? Date(timeIntervalSince1970: ti) : nil
    }

    private func saveLastSyncTimestamp(_ date: Date) {
        guard let key = lastSyncKey else { return }
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: key)
    }

    // MARK: - Init

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Sync Entry Point

    func syncIfNeeded() async {
        guard let appState else {
 logger.warning("AppState deallocated – skipping sync")
            return
        }
        if appState.isGuestMode {
 logger.info("Guest Mode active – skipping game result sync")
            return
        }
        guard let uid = currentUserId else {
 logger.warning("No authenticated user – skipping game result sync")
            syncState = .offline
            return
        }

 logger.info("Starting Firestore game result sync")
        syncState = .syncing

        do {
            let collectionRef = db.collection("users").document(uid).collection("gameResults")
            let isIncremental = lastSyncTimestamp != nil

            // Pull: incremental fetch if we have a previous sync timestamp,
            // otherwise full fetch on first sync
            var query: Query = collectionRef
            if let since = lastSyncTimestamp {
                query = collectionRef
                    .whereField("lastModified", isGreaterThan: Timestamp(date: since))
 logger.info("Incremental sync: fetching results modified after \(since.formatted())")
            }

            let snapshot = try await query.getDocuments(source: .default)
            let remoteResults = snapshot.documents.compactMap { doc -> GameResult? in
                return GameResult(fromFirestore: doc.data(), documentId: doc.documentID)
            }

 logger.info("Fetched \(remoteResults.count) game results from Firestore\(isIncremental ? " (incremental)" : " (full)")")

            // Merge: remote into local (remote is source of truth for existing IDs)
            var merged = appState.recentResults
            let localIDs = Set(merged.map { $0.id })

            // Update/add remote results (keep whichever version was modified more recently)
            for remote in remoteResults {
                if let idx = merged.firstIndex(where: { $0.id == remote.id }) {
                    if remote.lastModified >= merged[idx].lastModified {
                        merged[idx] = remote
                    }
                } else {
                    merged.append(remote)
                }
            }

            // Push: upload local-only results AND locally-modified results newer than remote
            let remoteIDs = Set(remoteResults.map { $0.id })
            let remoteByID = Dictionary(remoteResults.map { ($0.id, $0) }, uniquingKeysWith: { _, b in b })
            let toPush: [GameResult]
            if isIncremental {
                // Incremental: only push local results modified since last sync
                let since = lastSyncTimestamp!
                toPush = merged.filter { local in
                    guard localIDs.contains(local.id) else { return false }
                    if !remoteIDs.contains(local.id) && local.lastModified > since {
                        return true // local-only, created since last sync
                    }
                    if let remote = remoteByID[local.id], local.lastModified > remote.lastModified {
                        return true // locally modified after remote
                    }
                    return false
                }
            } else {
                // Full sync: push everything remote doesn't have or that's newer locally
                toPush = merged.filter { local in
                    if !remoteIDs.contains(local.id) && localIDs.contains(local.id) {
                        return true
                    }
                    if let remote = remoteByID[local.id], local.lastModified > remote.lastModified {
                        return true
                    }
                    return false
                }
            }
            if !toPush.isEmpty {
 logger.info("Uploading \(toPush.count) results to Firestore")
                for result in toPush {
                    try await uploadResult(result, to: collectionRef)
                }
            }

            // Sort newest first and apply
            merged.sort { $0.date > $1.date }
            appState.setRecentResults(merged)
            await appState.saveGameResults()
            await appState.rebuildStreaksFromResults()
            await appState.normalizeStreaksForMissedDays()

            syncState = .synced(lastSyncDate: Date())
            saveLastSyncTimestamp(Date())
 logger.info("Game result sync completed. Total: \(merged.count)")
        } catch {
 logger.error("Game result sync failed: \(error.localizedDescription)")
            syncState = .failed(error)
        }
    }

    // MARK: - Individual Result Operations

    func addResult(_ result: GameResult) {
        guard let appState else { return }
        guard !appState.isGuestMode else {
            appState.addGameResult(result)
            return
        }
        appState.addGameResult(result)

        guard let uid = currentUserId else { return }
        let collectionRef = db.collection("users").document(uid).collection("gameResults")

        // Firestore offline persistence queues this write automatically
        Task {
            do {
                try await uploadResult(result, to: collectionRef)
 logger.info("Uploaded game result \(result.id.uuidString)")
            } catch {
 logger.error("Failed to upload game result: \(error.localizedDescription)")
                // Firestore offline cache will retry automatically when back online
            }
        }
    }

    func deleteResult(_ id: UUID) async {
        appState?.removeGameResult(id)

        guard let uid = currentUserId else { return }
        do {
            try await db.collection("users").document(uid)
                .collection("gameResults").document(id.uuidString).delete()
 logger.info("Deleted game result \(id.uuidString) from Firestore")
        } catch {
 logger.error("Failed to delete game result from Firestore: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func uploadResult(_ result: GameResult, to collectionRef: CollectionReference) async throws {
        try await collectionRef.document(result.id.uuidString).setData(result.toFirestoreData())
    }

    /// Convenience flag for GuestSessionManager.
    var isGuestModeActive: Bool { appState?.isGuestMode ?? false }
}

// MARK: - GameResult ↔ Firestore Conversion

extension GameResult {

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "gameId": gameId.uuidString,
            "gameName": gameName,
            "date": Timestamp(date: date),
            "maxAttempts": maxAttempts,
            "completed": completed,
            "sharedText": sharedText,
            "parsedData": parsedData,
            "lastModified": Timestamp(date: lastModified)
        ]
        if let score = score {
            data["score"] = score
        }
        return data
    }

    init?(fromFirestore data: [String: Any], documentId: String) {
        guard
            let id = UUID(uuidString: documentId),
            let gameIdStr = data["gameId"] as? String,
            let gameId = UUID(uuidString: gameIdStr),
            let gameName = data["gameName"] as? String,
            let timestamp = data["date"] as? Timestamp,
            let maxAttempts = data["maxAttempts"] as? Int,
            let completed = data["completed"] as? Bool,
            let sharedText = data["sharedText"] as? String
        else {
            return nil
        }

        let score = data["score"] as? Int
        let parsedData = data["parsedData"] as? [String: String] ?? [:]
        let lastModified = (data["lastModified"] as? Timestamp)?.dateValue()

        self.init(
            id: id,
            gameId: gameId,
            gameName: gameName,
            date: timestamp.dateValue(),
            score: score,
            maxAttempts: maxAttempts,
            completed: completed,
            sharedText: sharedText,
            parsedData: parsedData,
            lastModified: lastModified
        )
    }
}
