//
//  AchievementSyncService.swift
//  StreakSync
//
//  Private iCloud sync for tiered achievements (feature-flagged)
//

import Foundation
import CloudKit
import OSLog

@MainActor
final class AchievementSyncService: ObservableObject {
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AchievementSync")
    private unowned let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Public API
    func syncIfEnabled() async {
        guard AppConstants.Flags.cloudSyncEnabled else { return }
        do {
            let container = CKContainer.default()
            let database = container.privateCloudDatabase
            let status = try await container.accountStatus()
            guard status == .available else {
                logger.info("iCloud not available: \(String(describing: status))")
                return
            }
            try await pull(database: database)
            try await push(database: database)
        } catch {
            logger.error("CloudKit sync failed: \(error.localizedDescription)")
        }
    }
    
    func enableSync(_ enabled: Bool) {
        AppConstants.Flags.cloudSyncEnabled = enabled
    }
    
    // MARK: - Pull
    private func pull(database: CKDatabase) async throws {
        let recordID = CKRecord.ID(recordName: AppConstants.CloudKitKeys.recordID)
        do {
            let record = try await database.record(for: recordID)
            guard let payloadData = record[AppConstants.CloudKitKeys.fieldPayload] as? Data else { return }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let remote = try? decoder.decode([TieredAchievement].self, from: payloadData) {
                let merged = merge(local: appState.tieredAchievements, remote: remote)
                if merged != appState.tieredAchievements {
                    appState.tieredAchievements = merged
                    logger.info("✅ Pulled and merged tiered achievements from iCloud")
                }
            }
        } catch {
            // Missing record is not a failure on first run
            logger.info("No existing cloud record to pull (\(error.localizedDescription))")
        }
    }
    
    // MARK: - Push
    private func push(database: CKDatabase) async throws {
        let recordID = CKRecord.ID(recordName: AppConstants.CloudKitKeys.recordID)
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            record = CKRecord(recordType: AppConstants.CloudKitKeys.recordTypeUserAchievements, recordID: recordID)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = (try? encoder.encode(appState.tieredAchievements)) ?? Data()
        record[AppConstants.CloudKitKeys.fieldVersion] = 1 as CKRecordValue
        record[AppConstants.CloudKitKeys.fieldPayload] = payload as CKRecordValue
        record[AppConstants.CloudKitKeys.fieldLastUpdated] = Date() as CKRecordValue
        let summary: [String: Int] = summarize(appState.tieredAchievements)
        record[AppConstants.CloudKitKeys.fieldSummary] = try? NSKeyedArchiver.archivedData(withRootObject: summary, requiringSecureCoding: false) as CKRecordValue
        _ = try await database.save(record)
        logger.info("☁️ Pushed tiered achievements to iCloud")
    }
    
    // MARK: - Helpers
    private func summarize(_ items: [TieredAchievement]) -> [String: Int] {
        var byCategory: [String: Int] = [:]
        for a in items {
            if a.progress.currentTier != nil { byCategory[a.category.rawValue, default: 0] += 1 }
        }
        return byCategory
    }
    
    internal func merge(local: [TieredAchievement], remote: [TieredAchievement]) -> [TieredAchievement] {
        var map: [UUID: TieredAchievement] = [:]
        for a in local { map[a.id] = a }
        for r in remote {
            if var l = map[r.id] {
                // Merge by picking higher progress/currentTier and union unlock dates
                let lVal = l.progress.currentValue
                let rVal = r.progress.currentValue
                if rVal > lVal { l.progress.currentValue = rVal }
                if let rt = r.progress.currentTier {
                    if l.progress.currentTier == nil || rt.rawValue > (l.progress.currentTier?.rawValue ?? 0) {
                        l.progress.currentTier = rt
                    }
                }
                for (tier, date) in r.progress.tierUnlockDates {
                    if let existing = l.progress.tierUnlockDates[tier] {
                        l.progress.tierUnlockDates[tier] = max(existing, date)
                    } else {
                        l.progress.tierUnlockDates[tier] = date
                    }
                }
                map[r.id] = l
            } else {
                map[r.id] = r
            }
        }
        return Array(map.values)
    }
}


