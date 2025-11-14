//
//  CloudKitZoneSetup.swift
//  StreakSync
//
//  Idempotent creation helpers for custom CloudKit zones and subscriptions.
//

import Foundation
#if canImport(CloudKit)
import CloudKit
#endif

/// Centralized CloudKit zone identifiers and setup helpers.
enum CloudKitZones {
    #if canImport(CloudKit)
    static let achievementsZoneID = CKRecordZone.ID(zoneName: "AchievementsZone")
    #endif
}

#if canImport(CloudKit)
enum CloudKitZoneSetup {
    
    /// Ensures the AchievementsZone exists in the provided database. Safe to call repeatedly.
    static func ensureAchievementsZone(in database: CKDatabase) async throws {
        let zone = CKRecordZone(zoneID: CloudKitZones.achievementsZoneID)
        do {
            try await modifyZones(database: database, saving: [zone], deleting: [])
        } catch let error as CKError {
            // If zone already exists, that's fine (idempotent)
            if error.code == .serverRecordChanged {
                // Zone already exists, which is what we want
                return
            }
            // Re-throw other errors
            throw error
        }
    }
    
    /// Ensures a CKRecordZoneSubscription exists for AchievementsZone (silent push).
    /// Safe to call repeatedly; will upsert the subscription.
    static func ensureAchievementsZoneSubscription(in database: CKDatabase) async throws {
        let subID = "achievements_zone_sub"
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        
        let subscription = CKRecordZoneSubscription(zoneID: CloudKitZones.achievementsZoneID, subscriptionID: subID)
        subscription.notificationInfo = info
        try await modifySubscriptions(database: database, saving: [subscription], deleting: [])
    }
}

// MARK: - CK Operation helpers (async wrappers)
private func modifyZones(database: CKDatabase,
                         saving: [CKRecordZone],
                         deleting: [CKRecordZone.ID]) async throws {
    let _: Void = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
        let op = CKModifyRecordZonesOperation(recordZonesToSave: saving, recordZoneIDsToDelete: deleting)
        op.modifyRecordZonesResultBlock = { result in
            switch result {
            case .success:
                // Success - zones created/updated
                cont.resume(returning: ())
            case .failure(let error):
                // Check for specific error codes
                if let ckError = error as? CKError {
                    // serverRecordChanged means zone already exists (idempotent success)
                    if ckError.code == .serverRecordChanged {
                        cont.resume(returning: ())
                        return
                    }
                }
                cont.resume(throwing: error)
            }
        }
        database.add(op)
    }
}

private func modifySubscriptions(database: CKDatabase,
                                 saving: [CKSubscription],
                                 deleting: [CKSubscription.ID]) async throws {
    let _: Void = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
        let op = CKModifySubscriptionsOperation(subscriptionsToSave: saving, subscriptionIDsToDelete: deleting)
        op.modifySubscriptionsResultBlock = { result in
            switch result {
            case .success:
                cont.resume(returning: ())
            case .failure(let error):
                cont.resume(throwing: error)
            }
        }
        database.add(op)
    }
}
#endif


