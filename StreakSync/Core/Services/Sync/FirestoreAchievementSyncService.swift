//
//  FirestoreAchievementSyncService.swift
//  StreakSync
//
//  Firestore-based sync for tiered achievements.
//  Stores the full [TieredAchievement] array as a single Firestore document.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import OSLog

@MainActor
@Observable
final class FirestoreAchievementSyncService {

    // MARK: - Sync Status

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case success(Date)
        case error(String)
    }

    var status: SyncStatus = .idle

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
            status = .error("Not signed in")
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
            // Warn at 500KB raw (~667KB base64) and refuse at 750KB (~1MB base64).
            let payloadKB = payload.count / 1024
            if payloadKB > 750 {
 logger.error("Achievement payload too large (\(payloadKB)KB) — skipping sync to avoid Firestore limit")
                status = .error("Data too large to sync (\(payloadKB)KB)")
                return
            }
            if payloadKB > 500 {
 logger.warning("Achievement payload growing large (\(payloadKB)KB) — consider restructuring")
            }
            
            let summary = summarize(appState.tieredAchievements)

            try await docRef.setData([
                "payload": payload.base64EncodedString(),
                "summary": summary,
                "lastUpdated": FieldValue.serverTimestamp(),
                "version": 1
            ])

            status = .success(Date())
 logger.info("Achievement sync completed")
        } catch {
            let message = userFriendlyMessage(for: error)
 logger.error("Achievement sync failed: \(error.localizedDescription)")
            status = .error(message)
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

    // MARK: - Error Messages

    private func userFriendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == FirestoreErrorDomain,
              let code = FirestoreErrorCode(_bridgedNSError: nsError) else {
            return error.localizedDescription
        }
        switch code.code {
        case .unavailable: return "Network unavailable"
        case .permissionDenied: return "Permission denied"
        case .unauthenticated: return "Not signed in"
        case .resourceExhausted: return "Service temporarily unavailable"
        default: return "Sync error: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    private func summarize(_ items: [TieredAchievement]) -> [String: Int] {
        var byCategory: [String: Int] = [:]
        for a in items {
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
                // Priority 3: Union unlock dates
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
