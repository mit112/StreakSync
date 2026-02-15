//
//  SyncServiceProtocols.swift
//  StreakSync
//
//  Protocols for sync services to enable testability and abstraction.
//

import Foundation

// MARK: - Game Result Sync Protocol

@MainActor
protocol GameResultSyncServiceProtocol {
    var syncState: SyncState { get }
    var isGuestModeActive: Bool { get }
    func syncIfNeeded() async
    func addResult(_ result: GameResult)
    func deleteResult(_ id: UUID) async
}

// MARK: - Achievement Sync Protocol

@MainActor
protocol AchievementSyncServiceProtocol {
    var isSyncEnabled: Bool { get }
    func enableSync(_ enabled: Bool)
    func syncIfEnabled() async
    func runConnectivityTest() async -> String
}

// MARK: - Conformance

extension FirestoreGameResultSyncService: GameResultSyncServiceProtocol {}
extension FirestoreAchievementSyncService: AchievementSyncServiceProtocol {}
