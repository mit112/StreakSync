//
//  UserDataSyncService.swift
//  StreakSync
//
//  CloudKit-based sync for per-result user data (GameResult records).
//

import Foundation
import OSLog
import CloudKit

// MARK: - Sync State

/// High-level sync state exposed to the UI.
enum SyncState {
    case notStarted
    case syncing
    case synced(lastSyncDate: Date)
    case failed(Error)
    case offline
}

// MARK: - User Data Sync Service

/// Production-ready CloudKit sync service for `GameResult` records.
///
/// Responsibilities:
/// - Maintain a custom `UserDataZone` in the private database
/// - Incrementally fetch changes using `CKServerChangeToken`
/// - Queue local writes for batched upload
/// - Persist an offline queue when network/iCloud is unavailable
/// - Keep `AppState.recentResults` and streaks in sync with the cloud
@MainActor
final class UserDataSyncService: ObservableObject {
    
    // MARK: - Public API
    
    @Published private(set) var syncState: SyncState = .notStarted
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.streaksync.app", category: "UserDataSync")
    private unowned let appState: AppState
    
    private let container: CKContainer
    private let database: CKDatabase
    
    private let uploadQueue: UploadQueue
    private let offlineQueue: OfflineQueue
    private let syncTracker = SyncTracker()
    
    /// UserDefaults key for the incremental sync token.
    private let changeTokenKey = "com.streaksync.sync.serverChangeToken"
    /// UserDefaults key for the last known CloudKit userRecordID.recordName.
    private let lastUserRecordIDKey = "com.streaksync.sync.lastUserRecordID"
    
    // MARK: - Initialization
    
    init(appState: AppState) {
        self.appState = appState
        self.container = CKContainer(identifier: CloudKitConfiguration.containerIdentifier)
        self.database = container.privateCloudDatabase
        self.uploadQueue = UploadQueue()
        self.offlineQueue = OfflineQueue(persistenceKey: "com.streaksync.sync.offlineQueue")
    }
    
    // MARK: - Debug Helpers
    
    /// Returns true if an incremental sync token is currently stored.
    var hasSyncToken: Bool {
        UserDefaults.standard.data(forKey: changeTokenKey) != nil
    }
    
    /// Convenience flag for callers that need to know whether Guest Mode is
    /// currently active without holding a direct reference to AppState.
    var isGuestModeActive: Bool {
        appState.isGuestMode
    }
    
    /// Returns the last known CloudKit userRecordID.recordName this device has synced with, if any.
    func lastKnownUserRecordName() -> String? {
        UserDefaults.standard.string(forKey: lastUserRecordIDKey)
    }
    
    /// Clears the last known CloudKit userRecordID.recordName from persistent storage.
    func clearLastKnownUserRecordName() {
        storeLastKnownUserRecordName(nil)
    }
    
    // MARK: - Zone & Subscription Setup
    
    /// Ensures the user data zone and subscription exist. Safe to call repeatedly.
    func ensureZoneAndSubscription() async {
        do {
            try await CloudKitZoneSetup.ensureUserDataZone(in: database)
            try await CloudKitZoneSetup.ensureUserDataZoneSubscription(in: database)
            logger.info("✅ UserDataZone and subscription verified")
        } catch {
            logger.error("❌ Failed to ensure UserDataZone: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sync Entry Point
    
    /// Fetches incremental changes from CloudKit and applies them to AppState.
    func syncIfNeeded() async {
        // Never sync while Guest Mode is active – guest sessions are local-only.
        if appState.isGuestMode {
            logger.info("🧑‍🤝‍🧑 Guest Mode active – skipping UserDataSyncService.syncIfNeeded()")
            return
        }
        logger.info("☁️ Starting user data sync")
        
        do {
            let accountStatus = try await container.accountStatus()
            guard accountStatus == .available else {
                logger.info("ℹ️ iCloud account unavailable: \(String(describing: accountStatus))")
                syncState = .offline
                return
            }
            
            syncState = .syncing
            
            // Ensure zone & subscription are present
            try await CloudKitZoneSetup.ensureUserDataZone(in: database)
            try await CloudKitZoneSetup.ensureUserDataZoneSubscription(in: database)
            
            // Fetch incremental changes
            let previousToken = loadSyncToken()
            let (changedRecords, deletedIDs, newToken) = try await fetchChanges(since: previousToken)
            
            await applyChanges(added: changedRecords, deleted: deletedIDs)
            
            if let newToken {
                saveSyncToken(newToken)
            }
            
            // After applying server changes, attempt to recover any local-only results
            // that were never uploaded due to crashes or transient failures.
            await recoverUnsyncedResultsIfNeeded()
            
            // Track the current CloudKit userRecordID so we can safely detect real
            // account changes (Apple ID switches) later and avoid spurious wipes.
            await refreshLastKnownUserRecordNameFromCloud()
            
            syncState = .synced(lastSyncDate: Date())
            logger.info("✅ User data sync completed. Added: \(changedRecords.count), Deleted: \(deletedIDs.count)")
        } catch {
            logger.error("❌ User data sync failed: \(error.localizedDescription)")
            syncState = .failed(error)
        }
    }
    
    // MARK: - Upload Queue API
    
    /// Queue a new result for upload. Called when the user adds a result locally.
    func queueForUpload(_ result: GameResult) {
        // In Guest Mode, we still add to AppState but never mark for sync or
        // enqueue for CloudKit; persistence is already gated inside AppState.
        if appState.isGuestMode {
            logger.info("🧑‍🤝‍🧑 Guest Mode active – adding result locally without queuing for CloudKit")
            appState.addGameResult(result)
            return
        }
        
        // Always update local state immediately (UI is offline-first)
        appState.addGameResult(result)
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            
            // Mark this result as needing CloudKit sync for crash recovery.
            Task {
                await self.syncTracker.markForSync(result.id)
            }
            
            do {
                let accountStatus = try await self.container.accountStatus()
                guard accountStatus == .available else {
                    self.logger.info("📦 Queuing result offline (iCloud unavailable)")
                    await self.offlineQueue.enqueue(result)
                    return
                }
                
                self.uploadQueue.enqueue(result) { [weak self] batch in
                    guard let self else { return }
                    await self.uploadBatch(batch)
                }
            } catch {
                self.logger.error("⚠️ Failed to check iCloud account status, queuing offline: \(error.localizedDescription)")
                await self.offlineQueue.enqueue(result)
            }
        }
    }
    
    /// Deletes a result locally and in CloudKit.
    func deleteResult(_ id: UUID) async {
        // Remove locally first
        appState.removeGameResult(id)
        
        // No longer needs to be synced.
        Task {
            await syncTracker.markDeleted(id)
        }
        
        let recordID = CKRecord.ID(
            recordName: id.uuidString,
            zoneID: CloudKitZones.userDataZoneID
        )
        
        let operation = CKModifyRecordsOperation(
            recordsToSave: nil,
            recordIDsToDelete: [recordID]
        )
        
        operation.isAtomic = false
        
        operation.modifyRecordsResultBlock = { [logger] result in
            switch result {
            case .success:
                logger.info("🗑️ Deleted GameResult \(recordID.recordName, privacy: .public) from CloudKit")
            case .failure(let error):
                logger.error("❌ Failed to delete GameResult from CloudKit: \(error.localizedDescription)")
            }
        }
        
        database.add(operation)
    }
    
    /// Flushes any pending offline queue when network becomes available.
    func flushOfflineQueue() async {
        let batch = await offlineQueue.drain()
        guard !batch.isEmpty else { return }
        
        logger.info("📤 Flushing offline queue with \(batch.count) results")
        await uploadBatch(batch)
    }
    
    // MARK: - Change Token Management
    
    func clearSyncToken() {
        UserDefaults.standard.removeObject(forKey: changeTokenKey)
    }
    
    private func loadSyncToken() -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: changeTokenKey) else {
            return nil
        }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        } catch {
            logger.error("⚠️ Failed to unarchive sync token: \(error.localizedDescription)")
            // Corrupted token - clear it so next sync performs a full fetch
            clearSyncToken()
            return nil
        }
    }
    
    private func saveSyncToken(_ token: CKServerChangeToken) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: changeTokenKey)
        } catch {
            logger.error("⚠️ Failed to archive sync token: \(error.localizedDescription)")
        }
    }
    
    /// Clears the current sync token and performs a fresh full sync.
    func forceFullSync() async {
        clearSyncToken()
        await syncIfNeeded()
    }
    
    /// Resets all CloudKit user-data sync state when we detect a real iCloud
    /// account change (Apple ID switch).
    func resetForAccountChange() async {
        // Clear incremental sync token so the next sync performs a full fetch.
        clearSyncToken()
        // Clear any locally-persisted offline queue and unsynced ID tracker so
        // we never upload results from the previous account under the new one.
        await offlineQueue.clear()
        await syncTracker.clearAll()
        // Clear the last known userRecordID; it will be re-learned after the
        // first successful sync for the new account.
        clearLastKnownUserRecordName()
    }
    
    // MARK: - User Record Tracking
    
    /// Persists the last known CloudKit userRecordID.recordName (or clears it when nil).
    private func storeLastKnownUserRecordName(_ recordName: String?) {
        let defaults = UserDefaults.standard
        if let recordName {
            defaults.set(recordName, forKey: lastUserRecordIDKey)
        } else {
            defaults.removeObject(forKey: lastUserRecordIDKey)
        }
    }
    
    /// Fetches the current CloudKit userRecordID from the container and stores its recordName.
    private func refreshLastKnownUserRecordNameFromCloud() async {
        do {
            let recordID = try await container.userRecordID()
            storeLastKnownUserRecordName(recordID.recordName)
            logger.info("🔐 Stored last known userRecordID: \(recordID.recordName, privacy: .private)")
        } catch {
            logger.error("⚠️ Failed to fetch userRecordID for tracking: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Unsynced Recovery
    
    /// Uploads any locally-stored results that are still marked as unsynced.
    private func recoverUnsyncedResultsIfNeeded() async {
        let unsyncedIDs = await syncTracker.getUnsynced()
        guard !unsyncedIDs.isEmpty else { return }
        
        let toUpload = appState.recentResults.filter { unsyncedIDs.contains($0.id) }
        guard !toUpload.isEmpty else { return }
        
        logger.info("📦 Recovering \(toUpload.count) locally-only results marked as unsynced")
        await uploadBatch(toUpload)
    }
    
    // MARK: - Fetch Changes
    
    private func fetchChanges(
        since token: CKServerChangeToken?
    ) async throws -> (added: [CKRecord], deleted: [CKRecord.ID], newToken: CKServerChangeToken?) {
        try await withCheckedThrowingContinuation { continuation in
            var changedRecords: [CKRecord] = []
            var deletedRecordIDs: [CKRecord.ID] = []
            var newToken: CKServerChangeToken?
            
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration(previousServerChangeToken: token)
            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [CloudKitZones.userDataZoneID],
                configurationsByRecordZoneID: [CloudKitZones.userDataZoneID: config]
            )
            
            operation.recordWasChangedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    changedRecords.append(record)
                case .failure(let error):
                    self.logger.error("❌ Failed to fetch record \(recordID.recordName, privacy: .public): \(error.localizedDescription)")
                }
            }
            
            operation.recordWithIDWasDeletedBlock = { recordID, _ in
                deletedRecordIDs.append(recordID)
            }
            
            operation.recordZoneFetchResultBlock = { zoneID, result in
                switch result {
                case .success(let zoneResult):
                    newToken = zoneResult.serverChangeToken
                case .failure(let error):
                    self.logger.error("❌ Record zone fetch failed: \(error.localizedDescription)")
                }
            }
            
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: (changedRecords, deletedRecordIDs, newToken))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            self.database.add(operation)
        }
    }
    
    // MARK: - Apply Changes
    
    private func applyChanges(added: [CKRecord], deleted: [CKRecord.ID]) async {
        let newResults = added.compactMap(GameResult.init(from:))
        let deletedIDs = Set(deleted.map { $0.recordName })
        
        logger.info("🔄 Applying changes from CloudKit. Added: \(newResults.count), Deleted IDs: \(deletedIDs.count)")
        
        // Update AppState on the main actor (we are already @MainActor here).
        var updatedResults = appState.recentResults
        
        // Merge added/updated results (cloud is source of truth)
        for result in newResults {
            if let index = updatedResults.firstIndex(where: { $0.id == result.id }) {
                updatedResults[index] = result
            } else {
                updatedResults.append(result)
            }
        }
        
        // Remove any deleted records
        if !deletedIDs.isEmpty {
            updatedResults.removeAll { deletedIDs.contains($0.id.uuidString) }
        }
        
        // Sort newest first
        updatedResults.sort { $0.date > $1.date }
        
        appState.setRecentResults(updatedResults)
        
        // Persist and recompute streaks
        await appState.saveGameResults()
        await appState.rebuildStreaksFromResults()
        // Normalize streaks after rebuild to check for gaps up to today
        await appState.normalizeStreaksForMissedDays()
    }
    
    // MARK: - Upload Batch
    
    private func uploadBatch(_ results: [GameResult]) async {
        guard !results.isEmpty else { return }
        
        // CloudKit limits batches to ~400 records; split large uploads into chunks.
        let chunkSize = 400
        let chunks: [[GameResult]] = stride(from: 0, to: results.count, by: chunkSize).map {
            Array(results[$0..<min($0 + chunkSize, results.count)])
        }
        
        for chunk in chunks {
            await uploadChunk(chunk)
        }
    }
    
    /// Uploads a single chunk of results to CloudKit and handles conflicts / failures.
    private func uploadChunk(_ results: [GameResult]) async {
        guard !results.isEmpty else { return }
        
        let records = results.map { $0.toCKRecord(in: CloudKitZones.userDataZoneID) }
        
        logger.info("📤 Uploading chunk of \(records.count) GameResult records to CloudKit")
        
        let operation = CKModifyRecordsOperation(
            recordsToSave: records,
            recordIDsToDelete: nil
        )
        
        operation.savePolicy = .changedKeys
        operation.isAtomic = false
        
        var failed: [CKRecord.ID: Error] = [:]
        
        operation.perRecordSaveBlock = { [weak self] recordID, result in
            guard let self else { return }
            
            switch result {
            case .success:
                // Mark this ID as successfully synced.
                if let uuid = UUID(uuidString: recordID.recordName) {
                    Task {
                        await self.syncTracker.markSynced(uuid)
                    }
                }
            case .failure(let error):
                // Handle per-record conflicts explicitly (server wins).
                if let ckError = error as? CKError, ckError.code == .serverRecordChanged {
                    if let serverRecord = ckError.serverRecord,
                       let serverResult = GameResult(from: serverRecord) {
                        self.logger.warning("⚠️ Conflict for record \(recordID.recordName, privacy: .public) – accepting server version")
                        
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        
                        self.appState.replaceOrAppendResult(serverResult)
                        await self.appState.saveGameResults()
                        await self.appState.rebuildStreaksFromResults()
                        // Normalize streaks after rebuild to check for gaps up to today
                        await self.appState.normalizeStreaksForMissedDays()
                        await self.syncTracker.markSynced(serverResult.id)
                    }
                    }
                } else {
                    failed[recordID] = error
                }
            }
        }
        
        operation.modifyRecordsResultBlock = { [weak self] result in
            guard let self else { return }
            
            switch result {
            case .success:
                let successCount = records.count - failed.count
                self.logger.info("✅ Successfully uploaded \(successCount) GameResult records")
                
                if !failed.isEmpty {
                    self.logger.error("⚠️ \(failed.count) GameResult records failed to upload")
                    
                    // For transient network errors, move failed records into the offline queue
                    // so they are not lost and can be retried when the network returns.
                    Task { [weak self] in
                        guard let self else { return }
                        
                        for (recordID, error) in failed {
                            if let ckError = error as? CKError,
                               self.isTransientNetworkError(ckError),
                               let result = results.first(where: { $0.id.uuidString == recordID.recordName }) {
                                await self.offlineQueue.enqueue(result)
                            }
                        }
                    }
                }
            case .failure(let error):
                self.logger.error("❌ Batch upload failed: \(error.localizedDescription)")
                
                // If the whole batch failed due to a transient network error,
                // move all results into the offline queue.
                if let ckError = error as? CKError, self.isTransientNetworkError(ckError) {
                    Task { [weak self] in
                        guard let self else { return }
                        for result in results {
                            await self.offlineQueue.enqueue(result)
                        }
                    }
                }
            }
        }
        
        database.add(operation)
    }

    // MARK: - Error classification
    
    private func isTransientNetworkError(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable,
             .networkFailure,
             .serviceUnavailable,
             .requestRateLimited,
             .zoneBusy:
            return true
        default:
            return false
        }
    }
}

// MARK: - Upload Queue (In-Memory)

/// In-memory upload queue that batches frequent writes into CloudKit operations.
/// Runs on the main actor, since all `UserDataSyncService` work is main-actor isolated.
@MainActor
final class UploadQueue {
    private var pending: [GameResult] = []
    private var uploadTask: Task<Void, Never>?
    
    func enqueue(_ result: GameResult, uploader: @escaping ([GameResult]) async -> Void) {
        pending.append(result)
        scheduleFlush(uploader: uploader)
    }
    
    private func scheduleFlush(uploader: @escaping ([GameResult]) async -> Void) {
        uploadTask?.cancel()
        uploadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            if self.pending.count >= 5 {
                await self.flush(uploader: uploader)
            } else {
                // Wait briefly to accumulate a batch
                try? await Task.sleep(for: .seconds(2))
                await self.flush(uploader: uploader)
            }
        }
    }
    
    private func flush(uploader: @escaping ([GameResult]) async -> Void) async {
        guard !pending.isEmpty else { return }
        let batch = pending
        pending.removeAll()
        await uploader(batch)
    }
    
    func pendingCount() -> Int {
        pending.count
    }
}

// MARK: - Offline Queue (Persistent)

/// Persistent offline queue that survives app restarts and uploads when connectivity returns.
actor OfflineQueue {
    private var pending: [GameResult] = []
    private let persistenceKey: String
    
    init(persistenceKey: String) {
        self.persistenceKey = persistenceKey
        self.pending = Self.loadPersistedQueue(forKey: persistenceKey)
    }
    
    func enqueue(_ result: GameResult) {
        pending.append(result)
        persistQueue()
    }
    
    /// Returns all pending results and clears the queue.
    func drain() -> [GameResult] {
        guard !pending.isEmpty else { return [] }
        let batch = pending
        pending.removeAll()
        persistQueue()
        return batch
    }
    
    /// Clears all pending results without uploading, used when the iCloud
    /// account actually changes so we do not leak results across accounts.
    func clear() {
        guard !pending.isEmpty else { return }
        pending.removeAll()
        persistQueue()
    }
    
    private func persistQueue() {
        do {
            let data = try JSONEncoder().encode(pending)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            // Best-effort persistence; log but don't throw.
            let logger = Logger(subsystem: "com.streaksync.app", category: "UserDataSync")
            logger.error("⚠️ Failed to persist offline queue: \(error.localizedDescription)")
        }
    }
    
    private static func loadPersistedQueue(forKey key: String) -> [GameResult] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }
        do {
            return try JSONDecoder().decode([GameResult].self, from: data)
        } catch {
            let logger = Logger(subsystem: "com.streaksync.app", category: "UserDataSync")
            logger.error("⚠️ Failed to load offline queue: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - GameResult ↔ CKRecord Conversion

extension GameResult {
    
    /// Converts a `GameResult` into a CloudKit record in the given zone.
    func toCKRecord(in zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: self.id.uuidString,
            zoneID: zoneID
        )
        let record = CKRecord(recordType: "GameResult", recordID: recordID)
        
        record["gameID"] = self.gameId.uuidString as CKRecordValue
        record["gameName"] = self.gameName as CKRecordValue
        record["gameType"] = self.gameName.lowercased() as CKRecordValue
        record["date"] = self.date as CKRecordValue
        record["score"] = self.score as? CKRecordValue
        record["maxAttempts"] = self.maxAttempts as CKRecordValue
        record["completed"] = (self.completed ? 1 : 0) as CKRecordValue
        record["sharedText"] = self.sharedText as CKRecordValue
        
        // Encode parsedData as JSON string
        if let data = try? JSONEncoder().encode(self.parsedData),
           let json = String(data: data, encoding: .utf8) {
            record["parsedData"] = json as CKRecordValue
        }
        
        return record
    }
    
    /// Initializes a `GameResult` from a CloudKit record in `UserDataZone`.
    /// Returns `nil` if required fields are missing or malformed.
    init?(from record: CKRecord) {
        guard
            record.recordType == "GameResult",
            let gameIDString = record["gameID"] as? String,
            let gameID = UUID(uuidString: gameIDString),
            let gameName = record["gameName"] as? String,
            let _ = record["gameType"] as? String,
            let date = record["date"] as? Date,
            let maxAttempts = record["maxAttempts"] as? Int,
            let completedInt = record["completed"] as? Int,
            let sharedText = record["sharedText"] as? String
        else {
            return nil
        }
        
        let score = record["score"] as? Int
        let completed = completedInt != 0
        
        // Decode parsedData
        var parsedData: [String: String] = [:]
        if let json = record["parsedData"] as? String,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            parsedData = decoded
        }
        
        let recordUUID = UUID(uuidString: record.recordID.recordName) ?? UUID()
        
        self.init(
            id: recordUUID,
            gameId: gameID,
            gameName: gameName,
            date: date,
            score: score,
            maxAttempts: maxAttempts,
            completed: completed,
            sharedText: sharedText,
            parsedData: parsedData
        )
    }
}


