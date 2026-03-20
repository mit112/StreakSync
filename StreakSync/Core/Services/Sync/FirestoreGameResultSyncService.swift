//
//  FirestoreGameResultSyncService.swift
//  StreakSync
//
//  Firestore-based sync for GameResult records.
//  Leverages Firestore's built-in offline persistence — no manual offline queue needed.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
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

    /// Clears the per-user last sync timestamp. Call on sign-out to prevent
    /// stale incremental sync when a different user signs in on the same device.
    func clearLastSyncTimestamp() {
        guard let key = lastSyncKey else { return }
        UserDefaults.standard.removeObject(forKey: key)
        syncState = .notStarted
        logger.info("Cleared last sync timestamp")
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
            let ref = db.collection("users").document(uid).collection("gameResults")
            let remoteResults = try await fetchRemoteResults(from: ref)
            var merged = mergeResults(local: appState.recentResults, remote: remoteResults)
            let toPush = resultsToPush(merged: merged, local: appState.recentResults, remote: remoteResults)

            if !toPush.isEmpty {
                logger.info("Uploading \(toPush.count) results to Firestore")
                for result in toPush {
                    try await uploadResult(result, to: ref)
                }
            }

            merged.sort { $0.date > $1.date }
            appState.setRecentResults(merged)
            await appState.saveGameResults()

            syncState = .synced(lastSyncDate: Date())
            saveLastSyncTimestamp(Date())
            logger.info("Game result sync completed. Total: \(merged.count)")
        } catch {
            logger.error("Game result sync failed: \(error.localizedDescription)")
            syncState = .failed(error)
        }
    }

    private func fetchRemoteResults(from collectionRef: CollectionReference) async throws -> [GameResult] {
        var query: Query = collectionRef
        if let since = lastSyncTimestamp {
            query = collectionRef.whereField("lastModified", isGreaterThan: Timestamp(date: since))
            logger.info("Incremental sync: fetching results modified after \(since.formatted())")
        }
        let snapshot = try await query.getDocuments(source: .default)
        let results = snapshot.documents.compactMap { doc -> GameResult? in
            GameResult(fromFirestore: doc.data(), documentId: doc.documentID)
        }
        let mode = lastSyncTimestamp != nil ? " (incremental)" : " (full)"
        logger.info("Fetched \(results.count) game results from Firestore\(mode)")
        return results
    }

    private func mergeResults(local: [GameResult], remote: [GameResult]) -> [GameResult] {
        var merged = local
        var indexById: [UUID: Int] = [:]
        for (i, result) in merged.enumerated() {
            indexById[result.id] = i
        }
        for remote in remote {
            if let idx = indexById[remote.id] {
                if remote.lastModified > merged[idx].lastModified {
                    merged[idx] = remote
                }
            } else {
                indexById[remote.id] = merged.count
                merged.append(remote)
            }
        }
        return merged
    }

    private func resultsToPush(merged: [GameResult], local: [GameResult], remote: [GameResult]) -> [GameResult] {
        let localIDs = Set(local.map { $0.id })
        let remoteIDs = Set(remote.map { $0.id })
        let remoteByID = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { _, b in b })

        return merged.filter { item in
            guard localIDs.contains(item.id) else { return false }
            if !remoteIDs.contains(item.id) { return true }
            if let r = remoteByID[item.id], item.lastModified > r.lastModified {
                return true
            }
            return false
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
            "sharedText": String(sharedText.prefix(2000)),
            "parsedData": parsedData.mapValues { String($0.prefix(500)) },
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

        // Trust Firestore data that was valid when written. Score validation
        // happens at ingestion (addGameResult → isValid) — not during sync,
        // where a scoring model change could silently drop historical results.

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
