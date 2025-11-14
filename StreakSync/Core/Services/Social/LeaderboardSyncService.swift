//
//  LeaderboardSyncService.swift
//  StreakSync
//
//  CKShare-based friend leaderboards with one shared zone per group.
//

import Foundation
#if canImport(CloudKit)
import CloudKit
#endif
import OSLog

@MainActor
final class LeaderboardSyncService {
    private let logger = Logger(subsystem: "com.streaksync.app", category: "LeaderboardSync")
    
    #if canImport(CloudKit)
    private var container: CKContainer {
        CKContainer(identifier: CloudKitConfiguration.containerIdentifier)
    }
    private func groupZoneID(for groupId: UUID) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: "leaderboard_\(groupId.uuidString)")
    }
    
    private func groupRecordID(for groupId: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "group_\(groupId.uuidString)", zoneID: groupZoneID(for: groupId))
    }
    #endif
    
    #if canImport(CloudKit)
    // MARK: - Default "Friends" Share
    /// Ensures a default Friends share exists and returns a CKShare ready for UICloudSharingController.
    func ensureFriendsShare() async throws -> (groupId: UUID, share: CKShare) {
        let container = self.container
        let db = container.privateCloudDatabase
        if let existing = LeaderboardGroupStore.selectedGroupId {
            // Try to fetch existing share via root record's share property; if missing, recreate it
            if let share = try? await existingShare(for: existing, in: db) {
                try? await ensureZoneSubscription(for: existing, in: db)
                return (existing, share)
            } else {
                let share = try await createShare(for: existing, title: LeaderboardGroupStore.selectedGroupTitle ?? "Friends", in: db)
                try? await ensureZoneSubscription(for: existing, in: db)
                return (existing, share)
            }
        } else {
            let (gid, share) = try await createGroup(title: "Friends")
            LeaderboardGroupStore.setSelectedGroup(id: gid, title: "Friends")
            return (gid, share)
        }
    }
    
    private func existingShare(for groupId: UUID, in database: CKDatabase) async throws -> CKShare? {
        let rootID = groupRecordID(for: groupId)
        let root = try await database.record(for: rootID)
        guard let shareReference = root.share else { return nil }
        let shareRecord = try await database.record(for: shareReference.recordID)
        return shareRecord as? CKShare
    }
    
    private func createShare(for groupId: UUID, title: String, in database: CKDatabase) async throws -> CKShare {
        // Ensure zone exists
        try await modifyZones(database: database, saving: [CKRecordZone(zoneID: groupZoneID(for: groupId))], deleting: [])
        // Fetch or create root
        let rootID = groupRecordID(for: groupId)
        let groupRecord: CKRecord
        do {
            groupRecord = try await database.record(for: rootID)
        } catch {
            let rec = CKRecord(recordType: "LeaderboardGroup", recordID: rootID)
            rec["title"] = title as CKRecordValue
            rec["createdAt"] = Date() as CKRecordValue
            groupRecord = rec
        }
        let share = CKShare(rootRecord: groupRecord)
        share[CKShare.SystemFieldKey.title] = title as CKRecordValue
        _ = try await saveRecords(database: database, records: [groupRecord, share])
        return share
    }
    
    // MARK: - Create Group (Owner)
    func createGroup(title: String) async throws -> (groupId: UUID, share: CKShare) {
        let container = self.container
        let db = container.privateCloudDatabase
        let ownerStatus = try await container.accountStatus()
        guard ownerStatus == .available else {
            throw CKError(.notAuthenticated)
        }
        let groupId = UUID()
        // 1) Create zone
        let zone = CKRecordZone(zoneID: groupZoneID(for: groupId))
        try await modifyZones(database: db, saving: [zone], deleting: [])
        // 2) Create root record
        let groupRecord = CKRecord(recordType: "LeaderboardGroup", recordID: groupRecordID(for: groupId))
        groupRecord["title"] = title as CKRecordValue
        groupRecord["createdAt"] = Date() as CKRecordValue
        // 3) Create share
        let share = CKShare(rootRecord: groupRecord)
        share[CKShare.SystemFieldKey.title] = title as CKRecordValue
        
        // Save root + share
        try await saveRecords(database: db, records: [groupRecord, share])
        // 4) Create zone subscription
        try? await ensureZoneSubscription(for: groupId, in: db)
        return (groupId, share)
    }
    
    // MARK: - Accept Share (Recipient)
    func acceptShare(metadata: CKShare.Metadata) async throws {
        let op = CKAcceptSharesOperation(shareMetadatas: [metadata])
        try await withCheckedThrowingContinuation { cont in
            op.perShareResultBlock = { _, _ in }
            op.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    cont.resume()
                case .failure(let error):
                    cont.resume(throwing: error)
                }
            }
            self.container.add(op)
        }
        // Best-effort: set up subscription for this group's zone
        if let rootRecord = metadata.rootRecord,
           let groupId = parseGroupId(from: rootRecord.recordID.recordName) {
            try? await ensureZoneSubscription(for: groupId, in: container.sharedCloudDatabase)
        }
    }
    
    // MARK: - Publish / Fetch DailyScore
    func publishDailyScore(groupId: UUID, score: DailyGameScore) async throws {
        let db = container.sharedCloudDatabase
        // Build record ID (composite)
        let recordID = CKRecord.ID(recordName: score.id, zoneID: groupZoneID(for: groupId))
        let record: CKRecord
        do {
            record = try await db.record(for: recordID)
        } catch {
            record = CKRecord(recordType: "DailyScore", recordID: recordID)
            record["gameId"] = score.gameId.uuidString as CKRecordValue
            record["gameName"] = score.gameName as CKRecordValue
        }
        record["userId"] = score.userId as CKRecordValue
        record["dateInt"] = NSNumber(value: score.dateInt)
        if let s = score.score { record["score"] = NSNumber(value: s) }
        record["maxAttempts"] = NSNumber(value: score.maxAttempts)
        record["completed"] = NSNumber(value: score.completed)
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await saveRecords(database: db, records: [record])
    }
    
    func fetchScores(groupId: UUID, dateInt: Int? = nil) async throws -> [CKRecord] {
        let db = container.sharedCloudDatabase
        let zoneID = groupZoneID(for: groupId)
        let predicate: NSPredicate = {
            if let d = dateInt {
                return NSPredicate(format: "dateInt == %@", NSNumber(value: d)) // or "%lld" with Int64
            } else {
                return NSPredicate(value: true)
            }
        }()
        let query = CKQuery(recordType: "DailyScore", predicate: predicate)
        var results: [CKRecord] = []
        let op = CKQueryOperation(query: query)
        op.zoneID = zoneID
        op.recordMatchedBlock = { _, result in
            if case .success(let rec) = result {
                results.append(rec)
            }
        }
        try await withCheckedThrowingContinuation { cont in
            op.queryResultBlock = { _ in
                cont.resume(returning: ())
            }
            db.add(op)
        }
        return results
    }
    
    /// Returns a map of userRecordName -> display name for participants of the shared group.
    func participantDisplayNames(for groupId: UUID) async -> [String: String] {
        let db = container.sharedCloudDatabase
        let rootID = groupRecordID(for: groupId)
        do {
            let root = try await db.record(for: rootID)
            guard let shareReference = root.share else { return [:] }
            let shareRecord = try await db.record(for: shareReference.recordID)
            guard let share = shareRecord as? CKShare else { return [:] }
            var map: [String: String] = [:]
            let formatter = PersonNameComponentsFormatter()
            for p in share.participants {
                let recordName = p.userIdentity.userRecordID?.recordName ?? ""
                guard !recordName.isEmpty else { continue }
                let name = p.userIdentity.nameComponents.flatMap { formatter.string(from: $0) } ?? ""
                map[recordName] = name.isEmpty ? "Friend" : name
            }
            // Owner displayed as well
            let ownerId = share.owner.userIdentity.userRecordID?.recordName ?? ""
            if !ownerId.isEmpty && map[ownerId] == nil {
                let ownerName = share.owner.userIdentity.nameComponents.flatMap { formatter.string(from: $0) } ?? ""
                map[ownerId] = ownerName.isEmpty ? "Owner" : ownerName
            }
            return map
        } catch {
            return [:]
        }
    }
    
    // MARK: - Zone Subscription per group
    func ensureZoneSubscription(for groupId: UUID, in database: CKDatabase) async throws {
        let subID = "leaderboard_\(groupId.uuidString)_sub"
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        let sub = CKRecordZoneSubscription(zoneID: groupZoneID(for: groupId), subscriptionID: subID)
        sub.notificationInfo = info
        try await modifySubscriptions(database: database, saving: [sub], deleting: [])
    }
    
    // MARK: - CK helpers
    private func modifyZones(database: CKDatabase,
                             saving: [CKRecordZone],
                             deleting: [CKRecordZone.ID]) async throws {
        return try await withCheckedThrowingContinuation { cont in
            let op = CKModifyRecordZonesOperation(recordZonesToSave: saving, recordZoneIDsToDelete: deleting)
            op.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success: cont.resume()
                case .failure(let error): cont.resume(throwing: error)
                }
            }
            database.add(op)
        }
    }
    
    @discardableResult
    private func saveRecords(database: CKDatabase, records: [CKRecord]) async throws -> [CKRecord] {
        return try await withCheckedThrowingContinuation { cont in
            let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: [])
            op.savePolicy = .changedKeys
            var saved: [CKRecord] = []
            op.perRecordSaveBlock = { _, result in
                if case .success(let rec) = result {
                    saved.append(rec)
                }
            }
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success: cont.resume(returning: saved)
                case .failure(let error): cont.resume(throwing: error)
                }
            }
            database.add(op)
        }
    }
    
    private func modifySubscriptions(database: CKDatabase,
                                     saving: [CKSubscription],
                                     deleting: [CKSubscription.ID]) async throws {
        return try await withCheckedThrowingContinuation { cont in
            let op = CKModifySubscriptionsOperation(subscriptionsToSave: saving, subscriptionIDsToDelete: deleting)
            op.modifySubscriptionsResultBlock = { result in
                switch result {
                case .success: cont.resume()
                case .failure(let error): cont.resume(throwing: error)
                }
            }
            database.add(op)
        }
    }
    
    private func parseGroupId(from recordName: String) -> UUID? {
        guard recordName.hasPrefix("group_") else { return nil }
        let uuidString = String(recordName.dropFirst("group_".count))
        return UUID(uuidString: uuidString)
    }
    #endif
}


