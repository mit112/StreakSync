//
//  FirestoreAchievementSyncService.swift
//  StreakSync
//
//  Firestore-based sync for tiered achievements.
//  Stores the full [TieredAchievement] array as a single Firestore document.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import OSLog

// MARK: - Sync Status

/// Why an achievement backup didn't land.
///
/// Structured rather than a pre-rendered English sentence so the settings row can say
/// whether retrying will help: a size overflow is permanent until the data shrinks, a
/// dropped connection clears itself. `AchievementSyncStatusPresentation` owns the copy.
enum AchievementSyncFailure: Equatable {
    /// Firestore caps a document at 1MB, base64 adds ~33%, and the document also carries
    /// `summary`, `lastUpdated` and `version`. 700KB of raw JSON is the refuse point.
    static let payloadLimitKilobytes = 700

    case notSignedIn
    case networkUnavailable
    case permissionDenied
    case serviceBusy
    /// Raw JSON size in KB, measured before base64 expansion.
    case payloadTooLarge(kilobytes: Int)
    case unknown(String)
}

enum AchievementSyncStatus: Equatable {
    case idle
    case syncing
    case success(Date)
    case error(AchievementSyncFailure)
}

// MARK: - Firestore Achievement Sync Service

@MainActor
@Observable
final class FirestoreAchievementSyncService {
    var status: AchievementSyncStatus = .idle

    // MARK: - Private

    @ObservationIgnored private weak var appState: AppState?
    @ObservationIgnored private let logger = Logger(subsystem: "com.streaksync.app", category: "FirestoreAchievementSync")
    @ObservationIgnored private let syncEnabledKey = "cloudSyncEnabled"

    private var db: Firestore { Firestore.firestore() }
    private var currentUserId: String? { Auth.auth().currentUser?.uid }

    // MARK: - Init

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Public API

    var isSyncEnabled: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: syncEnabledKey) == nil { return true }
        return defaults.bool(forKey: syncEnabledKey)
    }

    func enableSync(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: syncEnabledKey)
    }

    func syncIfEnabled() async {
        guard let appState else { return }
        if appState.isGuestMode { return }
        guard isSyncEnabled else { return }
        guard let uid = currentUserId else {
            status = .error(.notSignedIn)
            return
        }

        status = .syncing

        do {
            let docRef = db.collection("users").document(uid).collection("sync").document("achievements")

            // Pull
            let snapshot = try await docRef.getDocument(source: .default)
            if snapshot.exists, let data = snapshot.data(),
               let payloadBase64 = data["payload"] as? String,
               let payloadData = Data(base64Encoded: payloadBase64) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if let remote = try? decoder.decode([TieredAchievement].self, from: payloadData) {
                    let merged = merge(local: appState.tieredAchievements, remote: remote)
                    if merged != appState.tieredAchievements {
                        // The setter runs migrateAchievements, which strips retired
                        // categories from the merge result and appends missing new ones.
                        appState.tieredAchievements = merged
                        logger.info("Pulled and merged tiered achievements from Firestore")
                    }
                }
            }

            // Push
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let payload = (try? encoder.encode(appState.tieredAchievements)) ?? Data()
            
            // Size guard: base64 adds ~33% overhead, Firestore limit is 1MB per document.
            // The document also includes summary, lastUpdated, and version fields.
            // Warn at 450KB raw (~600KB base64) and refuse at 700KB (~933KB base64 + metadata).
            let payloadKB = payload.count / 1024
            if payloadKB > AchievementSyncFailure.payloadLimitKilobytes {
                logger.error("Achievement payload too large (\(payloadKB)KB) — skipping sync to avoid Firestore limit")
                status = .error(.payloadTooLarge(kilobytes: payloadKB))
                return
            }
            if payloadKB > 450 {
                logger.warning("Achievement payload growing large (\(payloadKB)KB) — consider restructuring")
            }
            
            let summary = summarize(appState.tieredAchievements)

            try await docRef.setData([
                "payload": payload.base64EncodedString(),
                "summary": summary,
                "lastUpdated": FieldValue.serverTimestamp(),
                "version": 2
            ])

            status = .success(Date())
            logger.info("Achievement sync completed")
        } catch {
            logger.error("Achievement sync failed: \(error.localizedDescription)")
            status = .error(failure(for: error))
        }
    }

    /// Deletes the user's cloud achievement document. Called from "Clear All Data" so a
    /// local wipe isn't immediately undone by the next pull — `syncIfEnabled` has no
    /// timestamp gate and would otherwise re-hydrate achievements from Firestore.
    /// No-op when signed out or in Guest Mode. Leaves the user's `cloudSyncEnabled`
    /// preference untouched.
    func deleteRemoteData() async {
        guard let appState, !appState.isGuestMode, let uid = currentUserId else { return }
        do {
            try await db.collection("users").document(uid)
                .collection("sync").document("achievements").delete()
            status = .idle
            logger.info("Deleted remote achievement data")
        } catch {
            logger.error("Failed to delete remote achievement data: \(error.localizedDescription)")
        }
    }

    // MARK: - Diagnostics

    func runConnectivityTest() async -> String {
        var lines: [String] = []

        guard let uid = currentUserId else {
            lines.append("Firebase UID: Not authenticated")
            return lines.joined(separator: "\n")
        }
        lines.append("Firebase UID: \(uid.prefix(8))…")

        do {
            let docRef = db.collection("users").document(uid).collection("sync").document("achievements")
            let snapshot = try await docRef.getDocument()
            if snapshot.exists {
                lines.append("Achievements doc: Found")
                if let data = snapshot.data(), let ts = data["lastUpdated"] as? Timestamp {
                    lines.append("Last updated: \(ts.dateValue().formatted())")
                }
            } else {
                lines.append("Achievements doc: Not found (OK on first run)")
            }
            lines.append("Connection: OK")
        } catch {
            lines.append("Connection: ERROR - \(error.localizedDescription)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Failure Classification

    private func failure(for error: Error) -> AchievementSyncFailure {
        let nsError = error as NSError
        guard nsError.domain == FirestoreErrorDomain,
              let code = FirestoreErrorCode(_bridgedNSError: nsError) else {
            return .unknown(error.localizedDescription)
        }
        switch code.code {
        case .unavailable: return .networkUnavailable
        case .permissionDenied: return .permissionDenied
        case .unauthenticated: return .notSignedIn
        case .resourceExhausted: return .serviceBusy
        default: return .unknown(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func summarize(_ items: [TieredAchievement]) -> [String: Int] {
        var byCategory: [String: Int] = [:]
        for a in items where !a.category.isRetired {
            if a.progress.currentTier != nil { byCategory[a.category.rawValue, default: 0] += 1 }
        }
        return byCategory
    }

    // MARK: - Merge Logic

    /// Merges local and remote tiered achievements with conflict resolution.
    ///
    /// Merge Strategy:
    /// 1. Tier Unlock Priority — takes the higher tier unlocked
    /// 2. Progress Value — takes the higher progress value
    /// 3. Unlock Dates — unions all dates, keeping latest per tier
    /// 4. Missing Achievements — adds remote-only to local
    internal func merge(local: [TieredAchievement], remote: [TieredAchievement]) -> [TieredAchievement] {
        let deduplicatedLocal = deduplicateByCategory(local)
        let deduplicatedRemote = deduplicateByCategory(remote)

        var map: [UUID: TieredAchievement] = [:]
        for a in deduplicatedLocal { map[a.id] = a }
        for r in deduplicatedRemote {
            if var l = map[r.id] {
                // Priority 1: Tier unlock status
                if let rt = r.progress.currentTier {
                    if l.progress.currentTier == nil || rt.rawValue > (l.progress.currentTier?.rawValue ?? 0) {
                        l.progress.currentTier = rt
                    }
                }
                // Priority 2: Higher progress value
                if r.progress.currentValue > l.progress.currentValue {
                    l.progress.currentValue = r.progress.currentValue
                }
                // Priority 3: Union unlock dates, keeping the earliest (first-earned) date per tier
                for (tier, date) in r.progress.tierUnlockDates {
                    if let existing = l.progress.tierUnlockDates[tier] {
                        l.progress.tierUnlockDates[tier] = min(existing, date)
                    } else {
                        l.progress.tierUnlockDates[tier] = date
                    }
                }
                map[r.id] = l
            } else {
                map[r.id] = r
            }
        }

        return deduplicateByCategory(Array(map.values))
    }

    private func deduplicateByCategory(_ achievements: [TieredAchievement]) -> [TieredAchievement] {
        var deduplicated: [TieredAchievement] = []
        var seenCategories: Set<AchievementCategory> = []
        for achievement in achievements {
            if !seenCategories.contains(achievement.category) {
                deduplicated.append(achievement)
                seenCategories.insert(achievement.category)
            }
        }
        return deduplicated
    }
}
