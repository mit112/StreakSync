//
//  NetworkMonitor.swift
//  StreakSync
//
//  Monitors network reachability and triggers offline queue flushes
//  for the CloudKit user data sync service.
//

import Foundation
import Network
import OSLog

/// Lightweight reachability monitor that notifies `UserDataSyncService` when
/// network connectivity becomes available so it can flush the offline queue.
///
/// Marked `@unchecked Sendable` because it is only used to:
/// - Log network status (OSLog is thread-safe)
/// - Hop back to the main actor before touching `UserDataSyncService`
/// and does not mutate shared state from background threads.
final class NetworkMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.streaksync.network-monitor")
    private let logger = Logger(subsystem: "com.streaksync.app", category: "NetworkMonitor")
    
    private unowned let syncService: UserDataSyncService
    
    init(syncService: UserDataSyncService) {
        self.syncService = syncService
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            
            switch path.status {
            case .satisfied:
                self.logger.info("📶 Network reachable – flushing offline queue if needed")
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    // Do not flush the offline queue while Guest Mode is active;
                    // guest sessions are local-only and must not trigger sync.
                    if self.syncService.isGuestModeActive {
                        self.logger.info("🧑‍🤝‍🧑 Guest Mode active – skipping offline queue flush")
                        return
                    }
                    await self.syncService.flushOfflineQueue()
                }
            case .unsatisfied, .requiresConnection:
                self.logger.info("📵 Network not reachable")
            @unknown default:
                self.logger.info("ℹ️ Unknown network status")
            }
        }
        
        monitor.start(queue: queue)
        logger.info("🌐 Started network monitoring")
    }
    
    func stopMonitoring() {
        monitor.cancel()
        logger.info("🌐 Stopped network monitoring")
    }
}


