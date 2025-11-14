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
    
    // MARK: - Sync Status
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case success(Date)
        case error(String)
    }
    
    @Published var status: SyncStatus = .idle
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Public API
    func syncIfEnabled() async {
        guard AppConstants.Flags.cloudSyncEnabled else { return }
        do {
            let container = CKContainer(identifier: CloudKitConfiguration.containerIdentifier)
            let database = container.privateCloudDatabase
            
            // Log container configuration for debugging
            let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
            logger.info("CloudKit sync starting - Bundle ID: \(bundleID), Container: \(CloudKitConfiguration.containerIdentifier)")
            
            // Verify container is accessible (lightweight check)
            do {
                _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord.ID, Error>) in
                    container.fetchUserRecordID { recordID, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let recordID = recordID {
                            continuation.resume(returning: recordID)
                        } else {
                            continuation.resume(throwing: NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch user record ID"]))
                        }
                    }
                }
                logger.info("✅ Container accessible - user record ID fetched successfully")
            } catch {
                // If we can't fetch user record ID, container configuration is likely wrong
                if let ckError = error as? CKError, ckError.code == .invalidArguments {
                    let diagnosticMsg = """
                    Container configuration error detected.
                    Bundle ID: \(bundleID)
                    Container: \(CloudKitConfiguration.containerIdentifier)
                    
                    Troubleshooting steps:
                    1. Verify container '\(CloudKitConfiguration.containerIdentifier)' exists in Developer Portal
                    2. Ensure container is associated with App ID '\(bundleID)'
                    3. Regenerate provisioning profiles in Xcode
                    4. Clean build folder and reinstall app
                    5. Check entitlements file has correct container identifier
                    """
                    logger.error("⚠️ \(diagnosticMsg)")
                    self.status = .error("Container configuration error - see logs for details")
                    return
                }
                // Other errors (like notAuthenticated) will be caught below
                throw error
            }
            
            let status = try await container.accountStatus()
            guard status == .available else {
                let statusMsg = "iCloud not available: \(String(describing: status))"
                logger.info("\(statusMsg)")
                self.status = .error(statusMsg)
                return
            }
            self.status = .syncing
            
            // Ensure custom zone exists (idempotent)
            logger.info("Creating AchievementsZone...")
            do {
                try await CloudKitZoneSetup.ensureAchievementsZone(in: database)
                logger.info("✅ AchievementsZone created/verified")
            } catch {
                logger.error("❌ Failed to create AchievementsZone: \(error.localizedDescription)")
                if let ckError = error as? CKError {
                    logger.error("Zone creation error - Code: \(ckError.code.rawValue) (\(String(describing: ckError.code)))")
                }
                throw error
            }
            
            // Optional: ensure subscription (idempotent)
            try? await CloudKitZoneSetup.ensureAchievementsZoneSubscription(in: database)
            
            try await pull(database: database)
            
            logger.info("Pushing achievements to CloudKit...")
            try await push(database: database)
            self.status = .success(Date())
            logger.info("✅ CloudKit sync completed successfully")
        } catch {
            // Enhanced error logging with CKError details
            let errorMessage: String
            if let ckError = error as? CKError {
                let errorCode = ckError.code.rawValue
                let errorCodeName = String(describing: ckError.code)
                let errorDescription = ckError.localizedDescription
                // Extract additional error context from userInfo if available
                let additionalInfo = ckError.userInfo.isEmpty ? "none" : "\(ckError.userInfo.count) items"
                
                logger.error("CloudKit sync failed - Code: \(errorCode) (\(errorCodeName)), Description: \(errorDescription), UserInfo: \(additionalInfo)")
                
                // Provide user-friendly messages for common errors
                switch ckError.code {
                case .notAuthenticated:
                    errorMessage = "Sign into iCloud to sync"
                case .quotaExceeded:
                    errorMessage = "iCloud storage full - sync paused"
                case .networkUnavailable, .networkFailure:
                    errorMessage = "Network unavailable - will sync when connected"
                case .invalidArguments:
                    // This includes "Invalid bundle ID for container"
                    let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
                    let detailedMsg = "Invalid container configuration"
                    logger.error("⚠️ \(detailedMsg): \(errorDescription)")
                    logger.error("⚠️ Bundle ID: \(bundleID), Container: \(CloudKitConfiguration.containerIdentifier)")
                    logger.error("⚠️ Fix: Verify in Developer Portal that container '\(CloudKitConfiguration.containerIdentifier)' is associated with App ID '\(bundleID)' and CloudKit capability is enabled")
                    errorMessage = "Container configuration error - check Developer Portal"
                case .permissionFailure:
                    errorMessage = "CloudKit permission denied"
                default:
                    errorMessage = "Sync error: \(errorDescription) (Code: \(errorCodeName))"
                }
            } else {
                logger.error("CloudKit sync failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
            
            self.status = .error(errorMessage)
            
            // Simple transient retry/backoff
            if let ck = error as? CKError, shouldRetry(ck) {
                await retryAfterBackoff()
            }
        }
    }
    
    func enableSync(_ enabled: Bool) {
        AppConstants.Flags.cloudSyncEnabled = enabled
    }
    
    // MARK: - Pull
    private func pull(database: CKDatabase) async throws {
        let recordID = CKRecord.ID(recordName: AppConstants.CloudKitKeys.recordID,
                                   zoneID: CloudKitZones.achievementsZoneID)
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
        let recordID = CKRecord.ID(recordName: AppConstants.CloudKitKeys.recordID,
                                   zoneID: CloudKitZones.achievementsZoneID)
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
        // Use JSON encoding instead of NSKeyedArchiver for better robustness and debugging
        let summaryData = (try? encoder.encode(summary)) ?? Data()
        record[AppConstants.CloudKitKeys.fieldSummary] = summaryData as CKRecordValue
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
    
    /// Merges local and remote tiered achievements with conflict resolution.
    ///
    /// Merge Strategy (Priority Order):
    /// 1. **Tier Unlock Priority**: If achievement is unlocked on either device → mark as unlocked
    ///    - Takes the higher tier unlocked (e.g., Tier 2 > Tier 1)
    ///    - If one device has Tier 1 unlocked and other has 80% progress but not unlocked → Tier 1 wins
    /// 2. **Progress Value**: Takes the higher progress value for the current tier
    /// 3. **Unlock Dates**: Unions all unlock dates, keeping the latest date for each tier
    /// 4. **Missing Achievements**: Adds any achievements from remote that don't exist locally
    ///
    /// Example:
    /// - Device A: 50% progress, Tier 1 unlocked
    /// - Device B: 80% progress, Tier 1 NOT unlocked
    /// - Result: Tier 1 unlocked with 80% progress (unlock status wins, but higher progress is kept)
    internal func merge(local: [TieredAchievement], remote: [TieredAchievement]) -> [TieredAchievement] {
        var map: [UUID: TieredAchievement] = [:]
        for a in local { map[a.id] = a }
        for r in remote {
            if var l = map[r.id] {
                // Priority 1: Tier unlock status (if unlocked on either device, keep unlocked)
                // Priority 2: Take higher tier if one is unlocked
                if let rt = r.progress.currentTier {
                    if l.progress.currentTier == nil || rt.rawValue > (l.progress.currentTier?.rawValue ?? 0) {
                        l.progress.currentTier = rt
                    }
                }
                // Priority 3: Take higher progress value
                let lVal = l.progress.currentValue
                let rVal = r.progress.currentValue
                if rVal > lVal { l.progress.currentValue = rVal }
                // Priority 4: Union unlock dates (keep latest for each tier)
                for (tier, date) in r.progress.tierUnlockDates {
                    if let existing = l.progress.tierUnlockDates[tier] {
                        l.progress.tierUnlockDates[tier] = max(existing, date)
                    } else {
                        l.progress.tierUnlockDates[tier] = date
                    }
                }
                map[r.id] = l
            } else {
                // Missing achievement from remote → add it
                map[r.id] = r
            }
        }
        return Array(map.values)
    }
    
    // MARK: - Retry policy
    private func shouldRetry(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .serviceUnavailable, .requestRateLimited, .networkFailure, .zoneBusy:
            return true
        default:
            return false
        }
    }
    
    private func retryDelay(for error: CKError) -> UInt64 {
        if error.code == .requestRateLimited, let retryAfter = error.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
            return UInt64(max(1.0, retryAfter) * 1_000_000_000)
        }
        return 2_000_000_000 // 2s default
    }
    
    private func retryAfterBackoff() async {
        // Simple fixed delay retry to avoid tight loops
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await syncIfEnabled()
    }
    
    // MARK: - Diagnostics
    /// Runs a lightweight CloudKit connectivity test to help verify console setup.
    /// Does not modify user data; zone creation is idempotent and safe.
    func runConnectivityTest() async -> String {
        var lines: [String] = []
        let container = CKContainer(identifier: CloudKitConfiguration.containerIdentifier)
        let database = container.privateCloudDatabase
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        lines.append("Bundle: \(bundleID)")
        lines.append("Container: \(CloudKitConfiguration.containerIdentifier)")
        
        // Fetch user record ID
        do {
            let userRecordID: CKRecord.ID = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord.ID, Error>) in
                container.fetchUserRecordID { recordID, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let recordID = recordID {
                        continuation.resume(returning: recordID)
                    } else {
                        continuation.resume(throwing: NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch user record ID"]))
                    }
                }
            }
            lines.append("UserRecordID: \(userRecordID.recordName)")
        } catch {
            lines.append("UserRecordID: ERROR - \(error.localizedDescription)")
        }
        
        // Account status
        do {
            let status = try await container.accountStatus()
            lines.append("Account Status: \(String(describing: status))")
        } catch {
            lines.append("Account Status: ERROR - \(error.localizedDescription)")
        }
        
        // Ensure zone exists (idempotent)
        do {
            try await CloudKitZoneSetup.ensureAchievementsZone(in: database)
            lines.append("AchievementsZone: OK")
        } catch {
            lines.append("AchievementsZone: ERROR - \(error.localizedDescription)")
        }
        
        // Try lightweight read for the expected record (not failure if missing)
        do {
            let recordID = CKRecord.ID(recordName: AppConstants.CloudKitKeys.recordID,
                                       zoneID: CloudKitZones.achievementsZoneID)
            _ = try await database.record(for: recordID)
            lines.append("Record Read: Found existing achievements record")
        } catch {
            lines.append("Record Read: No existing record (this is OK on first run)")
        }
        
        return lines.joined(separator: "\n")
    }
}


