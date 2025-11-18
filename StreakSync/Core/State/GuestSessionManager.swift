//
//  GuestSessionManager.swift
//  StreakSync
//
//  Manages Guest Mode sessions so that a friend can use the app temporarily
//  without syncing their data to iCloud or overwriting the host's data.
//

import Foundation
import OSLog
import UIKit

@MainActor
final class GuestSessionManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var isGuestMode: Bool = false
    
    // MARK: - Dependencies
    
    private let appState: AppState
    private let syncService: UserDataSyncService
    private let logger = Logger(subsystem: "com.streaksync.app", category: "GuestSession")
    private let userDefaults: UserDefaults
    
    // MARK: - Snapshot
    
    struct HostSnapshot {
        let results: [GameResult]
        let streaks: [GameStreak]
        let achievements: [TieredAchievement]
        // Favorites are owned by GameCatalog and are not mutated in guest mode.
    }
    
    private var hostSnapshot: HostSnapshot?
    
    // MARK: - Persistence Keys
    
    private let guestModeFlagKey = "com.streaksync.isGuestModeActive"
    
    // MARK: - Init
    
    init(appState: AppState, syncService: UserDataSyncService, userDefaults: UserDefaults = .standard) {
        self.appState = appState
        self.syncService = syncService
        self.userDefaults = userDefaults
    }
    
    // MARK: - Public API
    
    /// Enters Guest Mode, snapshotting the host's state and clearing visible
    /// data so the guest starts from a clean slate. No persistence is touched.
    func enterGuestMode() {
        guard !isGuestMode else {
            logger.info("Guest Mode already active – ignoring enterGuestMode()")
            return
        }
        
        logger.info("🧑‍🤝‍🧑 Entering Guest Mode – snapshotting host state")
        
        // 1. Snapshot host state (in memory only).
        hostSnapshot = HostSnapshot(
            results: appState.recentResults,
            streaks: appState.streaks,
            achievements: appState.tieredAchievements
        )
        
        // 2. Clear visible state for guest without touching persistence.
        appState.clearForGuestMode()
        
        // 3. Flip flags.
        appState.isGuestMode = true
        isGuestMode = true
        userDefaults.set(true, forKey: guestModeFlagKey)
    }
    
    /// Exits Guest Mode, optionally exporting the guest's data, and restores
    /// the host's snapshot. Optionally triggers a sync to reconcile any
    /// changes that occurred while in Guest Mode (e.g., account status).
    /// - Returns: The URL of the exported guest session file if export was
    ///   requested and succeeded, otherwise `nil`.
    func exitGuestMode(
        exportGuestData: Bool,
        shouldSyncAfterExit: Bool = true
    ) async -> URL? {
        guard isGuestMode else {
            logger.info("Guest Mode not active – ignoring exitGuestMode()")
            return nil
        }
        
        logger.info("🧑‍🤝‍🧑 Exiting Guest Mode (exportGuestData=\(exportGuestData))")
        
        var exportedURL: URL?
        if exportGuestData {
            exportedURL = await exportGuestSession()
        }
        
        // Restore host state if we still have a snapshot.
        if let snapshot = hostSnapshot {
            appState.isGuestMode = false
            appState.restoreFromSnapshot(
                results: snapshot.results,
                streaks: snapshot.streaks,
                achievements: snapshot.achievements
            )
            hostSnapshot = nil
        } else {
            // No snapshot (e.g., app was killed) – just ensure flags are reset.
            appState.isGuestMode = false
        }
        
        isGuestMode = false
        userDefaults.removeObject(forKey: guestModeFlagKey)
        
        // Trigger a sync to reconcile any host-side changes while guest mode
        // was active (e.g., account status flips), unless the caller opts out
        // (e.g., during an iCloud account change).
        if shouldSyncAfterExit {
            await syncService.syncIfNeeded()
        }
        
        return exportedURL
    }
    
    /// Called on app launch to detect if a previous guest session was
    /// interrupted (e.g., crash or force quit). Host data is loaded from
    /// persistence by the normal initialization flow; this simply clears
    /// stale flags so the app does not think Guest Mode is still active.
    func handleStrandedGuestSessionIfNeeded() {
        let wasInGuestMode = userDefaults.bool(forKey: guestModeFlagKey)
        guard wasInGuestMode else { return }
        
        logger.warning("⚠️ Detected stranded Guest Mode flag on launch – clearing and restoring host context")
        
        // Clear flag and ensure we start in host mode.
        userDefaults.removeObject(forKey: guestModeFlagKey)
        hostSnapshot = nil
        isGuestMode = false
        appState.isGuestMode = false
    }
    
    // MARK: - Guest Export
    
    /// Best-effort export of the guest's in-memory results to a JSON file in
    /// the temporary directory, then presents a share sheet so the user can
    /// save or share the file.
    /// - Returns: The URL of the exported file if export succeeds, else `nil`.
    private func exportGuestSession() async -> URL? {
        let guestResults = appState.recentResults
        guard !guestResults.isEmpty else {
            logger.info("Guest Mode export requested but there are no guest results to export")
            return nil
        }
        
        struct GuestExportData: Codable {
            let results: [GameResult]
            let exportedAt: Date
        }
        
        let export = GuestExportData(results: guestResults, exportedAt: Date())
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(export)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let timestamp = formatter.string(from: Date())
            let fileName = "StreakSync_GuestSession_\(timestamp).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
        try data.write(to: url, options: .atomic)
        logger.info("📤 Exported guest session data to \(url.absoluteString, privacy: .private)")
        
        // Present a share sheet directly so the user can save/share the JSON.
        await MainActor.run {
            let activityVC = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first(where: { $0.isKeyWindow }),
               let root = window.rootViewController {
                root.present(activityVC, animated: true)
            }
        }
        
        return url
        } catch {
            logger.error("❌ Failed to export guest session: \(error.localizedDescription)")
            return nil
        }
    }
}


