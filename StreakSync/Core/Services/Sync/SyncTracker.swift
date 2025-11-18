//
//  SyncTracker.swift
//  StreakSync
//
//  Tracks GameResult IDs that still need to be synced to CloudKit.
//

import Foundation
import OSLog

/// Tracks which `GameResult` IDs are not yet known to be persisted in CloudKit.
///
/// This allows the app to recover "local-only" results after a crash or force quit:
/// - When a result is added locally, it is marked for sync.
/// - When CloudKit confirms a successful save, the ID is marked as synced.
/// - On launch, any remaining unsynced IDs can be uploaded in a recovery pass.
actor SyncTracker {
    private var unsyncedIDs: Set<UUID> = []
    private let persistenceKey = "com.streaksync.sync.unsyncedResultIDs"
    private let logger = Logger(subsystem: "com.streaksync.app", category: "SyncTracker")
    
    init() {
        if let data = UserDefaults.standard.data(forKey: persistenceKey),
           let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            unsyncedIDs = Set(ids)
        }
    }
    
    // MARK: - Public API
    
    func markForSync(_ id: UUID) {
        unsyncedIDs.insert(id)
        persist()
    }
    
    func markSynced(_ id: UUID) {
        if unsyncedIDs.remove(id) != nil {
            persist()
        }
    }
    
    /// Called when a result is deleted locally; we no longer need to sync it.
    func markDeleted(_ id: UUID) {
        if unsyncedIDs.remove(id) != nil {
            persist()
        }
    }
    
    func getUnsynced() -> Set<UUID> {
        unsyncedIDs
    }
    
    /// Clears all tracked unsynced IDs, used when the iCloud account actually
    /// changes so we do not attempt to upload results from a previous account.
    func clearAll() {
        guard !unsyncedIDs.isEmpty else { return }
        unsyncedIDs.removeAll()
        persist()
    }
    
    // MARK: - Persistence
    
    private func persist() {
        do {
            let data = try JSONEncoder().encode(Array(unsyncedIDs))
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            logger.error("⚠️ Failed to persist unsynced IDs: \(error.localizedDescription)")
        }
    }
}


