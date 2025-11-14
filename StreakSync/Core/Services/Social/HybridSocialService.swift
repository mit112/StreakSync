//
//  HybridSocialService.swift
//  StreakSync
//
//  Hybrid social service that uses CloudKit when available, falls back to local storage
//

/*
 * HYBRIDSOCIALSERVICE - ADAPTIVE SOCIAL FEATURES MANAGER
 * 
 * WHAT THIS FILE DOES:
 * This file is the "smart social manager" that automatically chooses the best way to handle
 * social features based on what's available. It's like a "smart switch" that tries to use
 * CloudKit (Apple's cloud service) for real social features when possible, but falls back
 * to local storage when CloudKit isn't available. Think of it as the "social coordinator"
 * that ensures the app always has social features, even if they're just local simulations.
 * 
 * WHY IT EXISTS:
 * Not all users have CloudKit enabled or available, but the app still needs to provide
 * social features. This hybrid service ensures that social features always work, whether
 * they're using real cloud-based social features or local simulations. It provides a
 * seamless experience regardless of the user's setup or preferences.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This ensures social features always work regardless of user setup
 * - Provides seamless fallback from cloud to local social features
 * - Handles CloudKit availability detection and configuration
 * - Manages friend relationships and leaderboards
 * - Implements compile-gated CloudKit integration: works offline now, activates with entitlements
 * - Supports real-time sync when CloudKit is available with periodic refresh and subscriptions
 * - Provides rank delta tracking for engagement (today vs yesterday rankings)
 * - Ensures consistent social experience across all users
 * - Supports both real and simulated social interactions
 * - Provides graceful degradation when cloud services are unavailable
 * 
 * WHAT IT REFERENCES:
 * - LeaderboardSyncService: CKShare-based leaderboard sync (when CloudKit available)
 * - MockSocialService: Local simulation of social features
 * - SocialService: The protocol that defines social functionality
 * - UserProfile: User information and friend data
 * - DailyGameScore: Game results for leaderboards
 * - CloudKit: Apple's cloud service for data synchronization
 * 
 * WHAT REFERENCES IT:
 * - AppContainer: Creates and manages the HybridSocialService
 * - FriendsViewModel: Uses this for all social functionality
 * - Social features: All social interactions go through this service
 * - Leaderboard system: Uses this for competitive features
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. SERVICE STRATEGY IMPROVEMENTS:
 *    - The current fallback logic is basic - could be more sophisticated
 *    - Consider adding user preferences for social service selection
 *    - Add support for multiple cloud providers
 *    - Implement smart service selection based on performance
 * 
 * 2. ERROR HANDLING ENHANCEMENTS:
 *    - The current error handling is basic - could be more robust
 *    - Add support for retry mechanisms and circuit breakers
 *    - Implement proper error recovery strategies
 *    - Add user-friendly error messages and guidance
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current service switching could be optimized
 *    - Consider caching service availability results
 *    - Add support for background service health checking
 *    - Implement efficient service selection algorithms
 * 
 * 4. USER EXPERIENCE IMPROVEMENTS:
 *    - The current fallback could be more transparent to users
 *    - Add support for service status indicators
 *    - Implement smart service recommendations
 *    - Add support for manual service selection
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for service switching logic
 *    - Test different service availability scenarios
 *    - Add integration tests with both services
 *    - Test error handling and fallback behavior
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for service selection logic
 *    - Document the fallback strategies and error handling
 *    - Add examples of how to use different services
 *    - Create service architecture diagrams
 * 
 * 7. MONITORING AND ANALYTICS:
 *    - Add monitoring for service availability and performance
 *    - Track service usage patterns and user preferences
 *    - Monitor error rates and fallback frequency
 *    - Add A/B testing support for service selection
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new social service providers
 *    - Add support for custom social service implementations
 *    - Implement plugin system for social services
 *    - Add support for third-party social integrations
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Hybrid services: Services that can work in different modes
 * - CloudKit: Apple's cloud service for data synchronization
 * - Fallback strategies: What to do when the preferred option isn't available
 * - Service abstraction: Using protocols to hide implementation details
 * - Error handling: What to do when something goes wrong
 * - Service availability: Checking if a service is working and accessible
 * - Local storage: Storing data on the device instead of in the cloud
 * - Graceful degradation: Providing reduced functionality when full features aren't available
 * - Service switching: Changing between different service providers
 * - User experience: Making sure the app works well regardless of the underlying service
 */

import Foundation
#if canImport(CloudKit)
import CloudKit
#endif

@MainActor
final class HybridSocialService: SocialService, @unchecked Sendable {
    private let mockService: MockSocialService
    private var isCloudKitAvailable: Bool = false
    private let leaderboardSyncService: LeaderboardSyncService
    #if canImport(CloudKit)
    private var cachedUserRecordName: String?
    #endif
    
    init(leaderboardSyncService: LeaderboardSyncService) {
        self.mockService = MockSocialService()
        self.leaderboardSyncService = leaderboardSyncService
        
        // Check CloudKit availability
        Task {
            await checkCloudKitAvailability()
        }
    }
    
    // MARK: - CloudKit Availability Check
    
    private func checkCloudKitAvailability() async {
        #if canImport(CloudKit)
        do {
            let container = CKContainer(identifier: CloudKitConfiguration.containerIdentifier)
            let status = try await container.accountStatus()
            isCloudKitAvailable = (status == .available)
        } catch {
            isCloudKitAvailable = false
        }
        #else
        isCloudKitAvailable = false
        #endif
    }
    
    #if canImport(CloudKit)
    private func currentUserRecordName() async -> String? {
        if let cachedUserRecordName { return cachedUserRecordName }
        do {
            let container = CKContainer(identifier: CloudKitConfiguration.containerIdentifier)
            let id = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CKRecord.ID, Error>) in
                container.fetchUserRecordID { recordID, error in
                    if let error = error { cont.resume(throwing: error); return }
                    guard let recordID else { cont.resume(throwing: NSError(domain: "CK", code: -1)); return }
                    cont.resume(returning: recordID)
                }
            }
            cachedUserRecordName = id.recordName
            return id.recordName
        } catch {
            return nil
        }
    }
    #endif
    
    // MARK: - SocialService Protocol
    
    func ensureProfile(displayName: String?) async throws -> UserProfile {
        // Note: CloudKit-based profiles not implemented; using CKShare for leaderboards instead
        return try await mockService.ensureProfile(displayName: displayName)
    }
    
    func myProfile() async throws -> UserProfile {
        // Note: CloudKit-based profiles not implemented; using CKShare for leaderboards instead
        return try await mockService.myProfile()
    }
    
    func generateFriendCode() async throws -> String {
        // Note: Friend codes not implemented; using CKShare invites for leaderboards instead
        return try await mockService.generateFriendCode()
    }
    
    func addFriend(using code: String) async throws {
        // Note: Direct friend connections not implemented; using CKShare invites for leaderboards instead
        try await mockService.addFriend(using: code)
    }
    
    func listFriends() async throws -> [UserProfile] {
        // Note: Direct friend lists not implemented; friends are discovered via CKShare participants
        return try await mockService.listFriends()
    }
    
    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws {
        if isCloudKitAvailable {
            // If a shared group is selected, publish into that group's zone
            if let groupId = LeaderboardGroupStore.selectedGroupId {
                #if canImport(CloudKit)
                // Ensure userId matches CloudKit identity when possible
                let ckUserId = await currentUserRecordName()
                let normalized: [DailyGameScore] = scores.map { s in
                    DailyGameScore(
                        id: "\(ckUserId ?? s.userId)|\(s.dateInt)|\(s.gameId.uuidString)",
                        userId: ckUserId ?? s.userId,
                        dateInt: s.dateInt,
                        gameId: s.gameId,
                        gameName: s.gameName,
                        score: s.score,
                        maxAttempts: s.maxAttempts,
                        completed: s.completed
                    )
                }
                for s in normalized {
                    try await leaderboardSyncService.publishDailyScore(groupId: groupId, score: s)
                }
                // Also store locally for offline viewing
                try await mockService.publishDailyScores(dateUTC: dateUTC, scores: normalized)
                #else
                try await mockService.publishDailyScores(dateUTC: dateUTC, scores: scores)
                #endif
            } else {
                // No group selected yet; keep local only
                try await mockService.publishDailyScores(dateUTC: dateUTC, scores: scores)
            }
        } else {
            try await mockService.publishDailyScores(dateUTC: dateUTC, scores: scores)
        }
    }
    
    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow] {
        if isCloudKitAvailable {
            if let groupId = LeaderboardGroupStore.selectedGroupId {
                #if canImport(CloudKit)
                // Fetch records and aggregate into rows
                let dbScoresRecords = try await leaderboardSyncService.fetchScores(groupId: groupId, dateInt: nil)
                let nameMap = await leaderboardSyncService.participantDisplayNames(for: groupId)
                let scores: [DailyGameScore] = dbScoresRecords.compactMap { rec in
                    guard let gameIdStr = rec["gameId"] as? String,
                          let gameId = UUID(uuidString: gameIdStr) else { return nil }
                    let gameName = (rec["gameName"] as? String) ?? ""
                    let userId = (rec["userId"] as? String) ?? "unknown"
                    let dateInt = (rec["dateInt"] as? NSNumber)?.intValue ?? 0
                    let score = (rec["score"] as? NSNumber)?.intValue
                    let maxAttempts = (rec["maxAttempts"] as? NSNumber)?.intValue ?? 6
                    let completed = (rec["completed"] as? NSNumber)?.boolValue ?? false
                    let id = "\(userId)|\(dateInt)|\(gameId.uuidString)"
                    return DailyGameScore(id: id, userId: userId, dateInt: dateInt, gameId: gameId, gameName: gameName, score: score, maxAttempts: maxAttempts, completed: completed)
                }
                // Aggregate per user
                var perUser: [String: (name: String, total: Int, perGame: [UUID: Int])] = [:]
                for s in scores where s.dateInt >= startDateUTC.utcYYYYMMDD && s.dateInt <= endDateUTC.utcYYYYMMDD {
                    let game = Game.allAvailableGames.first(where: { $0.id == s.gameId })
                    let pts = LeaderboardScoring.points(for: s, game: game)
                    let display = nameMap[s.userId] ?? s.userId
                    var entry = perUser[s.userId] ?? (name: display, total: 0, perGame: [:])
                    // Keep the name up to date if we resolve it later
                    if entry.name == s.userId, let resolved = nameMap[s.userId] { entry.name = resolved }
                    entry.total += pts
                    entry.perGame[s.gameId] = (entry.perGame[s.gameId] ?? 0) + pts
                    perUser[s.userId] = entry
                }
                let rows = perUser.map { (userId, agg) in
                    LeaderboardRow(id: userId, userId: userId, displayName: agg.name, totalPoints: agg.total, perGameBreakdown: agg.perGame)
                }.sorted { $0.totalPoints > $1.totalPoints }
                return rows
                #else
                return try await mockService.fetchLeaderboard(startDateUTC: startDateUTC, endDateUTC: endDateUTC)
                #endif
            } else {
                // No group selected; show local-only
                return try await mockService.fetchLeaderboard(startDateUTC: startDateUTC, endDateUTC: endDateUTC)
            }
        } else {
            return try await mockService.fetchLeaderboard(startDateUTC: startDateUTC, endDateUTC: endDateUTC)
        }
    }
    
    // MARK: - Real-time Features
    
    var isRealTimeEnabled: Bool {
        return isCloudKitAvailable
    }
    
    func setupRealTimeSubscriptions() async {
        // Real-time subscriptions are handled by LeaderboardSyncService zone subscriptions
        // No additional setup needed here
    }
    
    // MARK: - Service Status
    
    var serviceStatus: ServiceStatus {
        if isCloudKitAvailable {
            return .cloudKit
        } else {
            return .local
        }
    }
}

// MARK: - Service Status

enum ServiceStatus {
    case cloudKit
    case local
    
    var displayName: String {
        switch self {
        case .cloudKit:
            return "Real-time Sync"
        case .local:
            return "Local Storage"
        }
    }
    
    var description: String {
        switch self {
        case .cloudKit:
            return "Scores sync automatically across devices"
        case .local:
            return "Scores stored locally on this device"
        }
    }
}

#if canImport(CloudKit)
import CloudKit
enum CloudKitAvailability {
    static func accountStatus() async throws -> CloudKitStatus {
        let container = CKContainer.default()
        let status = try await container.accountStatus()
        switch status {
        case .available: return .available
        case .noAccount: return .noAccount
        case .restricted: return .restricted
        case .couldNotDetermine: return .unknown
        case .temporarilyUnavailable:
            return .unknown
        @unknown default: return .unknown
        }
    }
}
#endif
