//
//  CloudKitSocialService.swift
//  StreakSync
//
//  Unified social service that uses CloudKit when available, with local caching fallback.
//

/*
 * CLOUDKITSOCIALSERVICE - UNIFIED SOCIAL FEATURES MANAGER
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
 * - AppContainer: Creates and manages the CloudKitSocialService
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
import OSLog
#if canImport(CloudKit)
import CloudKit
#endif

struct LeaderboardCacheKey: Hashable, Codable {
    let startDateInt: Int
    let endDateInt: Int
    let groupId: UUID?
}

struct LeaderboardCacheEntry: Codable {
    let rows: [LeaderboardRow]
    let timestamp: Date
}

@MainActor
final class CloudKitSocialService: SocialService, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.streaksync.app", category: "CloudKitSocialService")
    private let flags = BetaFeatureFlags.shared
    private let betaDefaultGroupId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    private let betaDefaultGroupName = "Friends"
    private let mockService: MockSocialService
    private var isCloudKitAvailable: Bool = false
    private let leaderboardSyncService: LeaderboardSyncService
    private var leaderboardCache: [LeaderboardCacheKey: LeaderboardCacheEntry]
    private let leaderboardCacheTTL: TimeInterval = 90
    private var discoveredFriendsCache: [DiscoveredFriend] = []
    private var discoveryCacheTimestamp: Date?
    private let discoveryCacheTTL: TimeInterval = 60 * 60 * 24
    private let nameFormatter = PersonNameComponentsFormatter()
    private var circles: [SocialCircle]
    private let circleStore = SocialCircleStore()
    private let socialSettingsService: SocialSettingsService
    private var pendingScoreQueue: [DailyGameScore]
    private let pendingScoreStore = PendingScoreStore()
    private let leaderboardCacheStore = LeaderboardCacheStore()
    #if canImport(CloudKit)
    private var cachedUserRecordName: String?
    #endif
    
    init(leaderboardSyncService: LeaderboardSyncService, privacyService: SocialSettingsService = .shared) {
        self.mockService = MockSocialService()
        self.leaderboardSyncService = leaderboardSyncService
        self.circles = circleStore.load()
        self.socialSettingsService = privacyService
        self.leaderboardCache = leaderboardCacheStore.load()
        self.pendingScoreQueue = pendingScoreStore.load()
        if !flags.multipleCircles && LeaderboardGroupStore.selectedGroupId == nil {
            LeaderboardGroupStore.setSelectedGroup(id: betaDefaultGroupId, title: betaDefaultGroupName)
        }
        
        // Check CloudKit availability
        Task {
            await checkCloudKitAvailability()
        }
        
        Task {
            await flushPendingScores()
        }
    }
    
    // MARK: - CloudKit Availability Check
    
    private func checkCloudKitAvailability() async {
        #if canImport(CloudKit)
        do {
            let container = CKContainer(identifier: CloudKitConfiguration.containerIdentifier)
            let status = try await container.accountStatus()
            isCloudKitAvailable = (status == .available)
            if self.isCloudKitAvailable && !flags.multipleCircles {
                await ensureDefaultGroupShareIfNeeded()
            }
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
    
    func listFriends() async throws -> [UserProfile] {
        // Note: Direct friend lists not implemented; friends are discovered via CKShare participants
        return try await mockService.listFriends()
    }
    
    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws {
        logger.info("🔍 Filter check - Input scores: \(scores.count)")
        let publishableScores = scores.filter { shouldShare(score: $0) }
        logger.info("🔍 Filter check - Publishable: \(publishableScores.count)")
        
        if publishableScores.count < scores.count {
            logger.warning("⚠️ Some scores were filtered out!")
            for score in scores {
                let willShare = shouldShare(score: score)
                logger.info("  - \(score.gameName): shouldShare=\(willShare)")
                if !willShare {
                    // Check why it was filtered
                    let game = Game.allAvailableGames.first(where: { $0.id == score.gameId })
                    logger.info("    → Game found: \(game != nil)")
                    logger.info("    → Completed: \(score.completed)")
                    logger.info("    → Score value: \(score.score?.description ?? "nil")")
                    logger.info("    → Max attempts: \(score.maxAttempts)")
                    if let game = game {
                        let points = LeaderboardScoring.points(for: score, game: game)
                        logger.info("    → Calculated points: \(points)")
                    }
                }
            }
        }
        
        guard !publishableScores.isEmpty else {
            logger.warning("⚠️ All scores filtered out - nothing to publish")
            return
        }
        let normalized = await normalizeScores(publishableScores)
        logger.info("🔄 Normalized \(normalized.count) scores")
        do {
            try await sendNormalizedScores(normalized, dateUTC: dateUTC)
            await flushPendingScores()
            logger.info("✅ Successfully sent normalized scores")
        } catch {
            logger.error("❌ Failed to send scores, enqueueing: \(error.localizedDescription)")
            enqueuePending(scores: normalized)
            throw error
        }
    }
    
    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow] {
        logger.info("🔍 === FETCH LEADERBOARD ===")
        logger.info("📅 Filter range: \(startDateUTC) → \(startDateUTC.utcYYYYMMDD) to \(endDateUTC) → \(endDateUTC.utcYYYYMMDD)")
        
        let groupIdForMode = currentGroupIdentifier()
        let key = LeaderboardCacheKey(startDateInt: startDateUTC.utcYYYYMMDD,
                                      endDateInt: endDateUTC.utcYYYYMMDD,
                                      groupId: groupIdForMode)
        if let cached = cachedLeaderboard(for: key) {
            logger.info("📦 Returning cached leaderboard: \(cached.count) rows")
            return cached
        }
        
        logger.info("🔄 Cache miss - fetching fresh data")
        logger.info("☁️ CloudKit available: \(self.isCloudKitAvailable)")
        logger.info("🆔 Group ID: \(groupIdForMode?.uuidString ?? "nil")")
        
        if self.isCloudKitAvailable {
            if let groupId = groupIdForMode {
                #if canImport(CloudKit)
                // Always fetch local scores first - user's own scores are stored locally
                logger.info("📥 Fetching local scores first...")
                let localRows = try await mockService.fetchLeaderboard(startDateUTC: startDateUTC, endDateUTC: endDateUTC)
                logger.info("📥 Local rows fetched: \(localRows.count)")
                for row in localRows {
                    logger.info("  - Local: userId=\(row.userId), name=\(row.displayName), points=\(row.totalPoints)")
                }
                
                // Try to fetch from CloudKit (may fail if group/zone doesn't exist yet)
                let dbScoresRecords: [CKRecord]
                let nameMap: [String: String]
                do {
                    logger.info("☁️ Attempting CloudKit fetch...")
                    dbScoresRecords = try await leaderboardSyncService.fetchScores(groupId: groupId, dateInt: nil)
                    nameMap = await leaderboardSyncService.participantDisplayNames(for: groupId)
                    logger.info("☁️ CloudKit fetch succeeded: \(dbScoresRecords.count) records")
                } catch {
                    // Group/zone doesn't exist yet - return local scores directly
                    logger.warning("⚠️ CloudKit fetch failed (group/zone doesn't exist): \(error.localizedDescription)")
                    logger.info("📤 Returning local scores directly: \(localRows.count) rows")
                    storeLeaderboard(localRows, for: key)
                    return localRows
                }
                
                // If CloudKit has no scores, return local scores directly
                if dbScoresRecords.isEmpty {
                    logger.info("☁️ CloudKit has no scores, returning local scores: \(localRows.count) rows")
                    storeLeaderboard(localRows, for: key)
                    return localRows
                }
                
                let cloudKitScores: [DailyGameScore] = dbScoresRecords.compactMap { rec in
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
                
                let ckUserId = await currentUserRecordName()
                let myProfile = try? await myProfile()
                
                // Aggregate CloudKit scores per user. Convert stored UTC dayInts into
                // the user's *local* calendar days for filtering, to match MockSocialService.
                let cal = Calendar.current
                let localStart = cal.startOfDay(for: startDateUTC)
                let localEnd = cal.startOfDay(for: endDateUTC)
                
                func localDay(for dateInt: Int) -> Date? {
                    var utcCal = Calendar(identifier: .gregorian)
                    utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
                    let y = dateInt / 10_000
                    let m = (dateInt / 100) % 100
                    let d = dateInt % 100
                    var comps = DateComponents()
                    comps.year = y
                    comps.month = m
                    comps.day = d
                    guard let utcDate = utcCal.date(from: comps) else { return nil }
                    return cal.startOfDay(for: utcDate)
                }
                
                var perUser: [String: (name: String, total: Int, perGame: [UUID: Int])] = [:]
                for s in cloudKitScores {
                    guard let day = localDay(for: s.dateInt),
                          day >= localStart, day <= localEnd else { continue }
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
                
                // Merge local scores: ensure current user's scores are always included
                // The current user's local scores use "local_user" or device user ID
                logger.info("🔄 Merging local scores...")
                let myLocalProfile = try? await mockService.myProfile()
                logger.info("👤 My local profile ID: \(myLocalProfile?.id ?? "nil")")
                logger.info("👤 CloudKit user ID: \(ckUserId ?? "nil")")
                logger.info("👤 My profile display name: \(myProfile?.displayName ?? "nil")")
                
                // Find the current user's local row - check all possible userId formats
                let myLocalRow: LeaderboardRow? = {
                    // Try all local rows - one of them should be the current user
                    for row in localRows {
                        // Match by profile ID
                        if let myLocalProfile = myLocalProfile, row.userId == myLocalProfile.id {
                            logger.info("✅ Found local row by profile ID: \(row.userId)")
                            return row
                        }
                        // Match by "local_user" (scores are published with this)
                        if row.userId == "local_user" {
                            logger.info("✅ Found local row by 'local_user': \(row.userId)")
                            return row
                        }
                    }
                    // Fallback: if there's only one local row, it's probably the current user
                    if localRows.count == 1 {
                        logger.info("✅ Using single local row as fallback: \(localRows.first?.userId ?? "nil")")
                        return localRows.first
                    }
                    // If multiple rows, prefer the one with highest score (likely current user)
                    let maxRow = localRows.max(by: { $0.totalPoints < $1.totalPoints })
                    logger.info("✅ Using highest-scoring local row: \(maxRow?.userId ?? "nil")")
                    return maxRow
                }()
                
                if let myLocalRow = myLocalRow {
                    logger.info("📋 Found local row: userId=\(myLocalRow.userId), name=\(myLocalRow.displayName), points=\(myLocalRow.totalPoints)")
                    // Determine which user ID to use for the current user
                    // Use CloudKit user ID if available, otherwise use local user ID
                    let userIdToUse = ckUserId ?? myLocalRow.userId
                    logger.info("🆔 Using userId: \(userIdToUse) for merge")
                    
                    // Always merge local scores - they represent the current user's actual data
                    if !perUser.keys.contains(userIdToUse) {
                        // User doesn't exist in CloudKit, add from local
                        logger.info("➕ Adding local user to results (not in CloudKit)")
                        perUser[userIdToUse] = (
                            name: myProfile?.displayName ?? myLocalRow.displayName,
                            total: myLocalRow.totalPoints,
                            perGame: myLocalRow.perGameBreakdown
                        )
                    } else {
                        // User exists in CloudKit - merge scores, preferring local if CloudKit is empty
                        logger.info("🔄 Merging with existing CloudKit user")
                        var existing = perUser[userIdToUse]!
                        logger.info("  - CloudKit total: \(existing.total)")
                        logger.info("  - Local total: \(myLocalRow.totalPoints)")
                        if existing.total == 0 && myLocalRow.totalPoints > 0 {
                            // CloudKit has no scores, use local
                            logger.info("  → CloudKit empty, using local scores")
                            existing.total = myLocalRow.totalPoints
                            existing.perGame = myLocalRow.perGameBreakdown
                        } else {
                            // Merge: combine scores from both sources
                            logger.info("  → Merging scores from both sources")
                            existing.total += myLocalRow.totalPoints
                            for (gameId, points) in myLocalRow.perGameBreakdown {
                                existing.perGame[gameId] = (existing.perGame[gameId] ?? 0) + points
                            }
                        }
                        // Update name from profile if available
                        if let profileName = myProfile?.displayName, !profileName.isEmpty {
                            existing.name = profileName
                        }
                        perUser[userIdToUse] = existing
                    }
                } else {
                    logger.warning("⚠️ Could not find local row for current user!")
                    logger.warning("  - Local rows available: \(localRows.count)")
                    for row in localRows {
                        logger.warning("    → userId=\(row.userId), name=\(row.displayName)")
                    }
                }
                
                let rows = perUser.map { (userId, agg) in
                    LeaderboardRow(id: userId, userId: userId, displayName: agg.name, totalPoints: agg.total, perGameBreakdown: agg.perGame)
                }.sorted { $0.totalPoints > $1.totalPoints }
                
                logger.info("✅ Final leaderboard: \(rows.count) rows")
                for row in rows {
                    logger.info("  - \(row.displayName) (userId=\(row.userId)): \(row.totalPoints) total points")
                }
                
                storeLeaderboard(rows, for: key)
                return rows
                #else
                let rows = try await mockService.fetchLeaderboard(startDateUTC: startDateUTC, endDateUTC: endDateUTC)
                storeLeaderboard(rows, for: key)
                return rows
                #endif
            } else {
                // No group selected; show local-only
                let rows = try await mockService.fetchLeaderboard(startDateUTC: startDateUTC, endDateUTC: endDateUTC)
                storeLeaderboard(rows, for: key)
                return rows
            }
        } else {
            let rows = try await mockService.fetchLeaderboard(startDateUTC: startDateUTC, endDateUTC: endDateUTC)
            storeLeaderboard(rows, for: key)
            return rows
        }
    }
    
    // MARK: - Real-time Features
    
    var isRealTimeEnabled: Bool {
        return self.isCloudKitAvailable
    }
    
    func setupRealTimeSubscriptions() async {
        // Real-time subscriptions are handled by LeaderboardSyncService zone subscriptions
        // No additional setup needed here
    }
    
    // MARK: - Service Status
    
    var serviceStatus: ServiceStatus {
        if self.isCloudKitAvailable {
            return .cloudKit
        } else {
            return .local
        }
    }

    #if canImport(CloudKit)
    @discardableResult
    func ensureFriendsShare() async throws -> CKShare? {
        guard self.isCloudKitAvailable else { return nil }
        if !flags.multipleCircles {
            LeaderboardGroupStore.setSelectedGroup(id: betaDefaultGroupId, title: betaDefaultGroupName)
        }
        // In beta mode, force recreation to ensure share has current build number
        let forceRecreate = !flags.multipleCircles
        let result = try await leaderboardSyncService.ensureFriendsShare(forceRecreate: forceRecreate)
        if !flags.multipleCircles {
            LeaderboardGroupStore.setSelectedGroup(id: result.groupId, title: betaDefaultGroupName)
        }
        return result.share
    }

    func ensureFriendsShareURL() async throws -> URL? {
        // In beta mode, forceRecreate is handled inside ensureFriendsShare()
        return try await ensureFriendsShare()?.url
    }
    #else
    func ensureFriendsShareURL() async throws -> URL? { nil }
    #endif
}

// MARK: - Leaderboard Cache Helpers
private extension CloudKitSocialService {
    func currentGroupIdentifier() -> UUID? {
        if flags.multipleCircles {
            return LeaderboardGroupStore.selectedGroupId
        } else {
            return ensureDefaultGroupSelection()
        }
    }

    func ensureDefaultGroupSelection() -> UUID {
        if let existing = LeaderboardGroupStore.selectedGroupId {
            return existing
        }
        LeaderboardGroupStore.setSelectedGroup(id: betaDefaultGroupId, title: betaDefaultGroupName)
        return betaDefaultGroupId
    }

    func ensureDefaultGroupShareIfNeeded() async {
        #if canImport(CloudKit)
        guard !flags.multipleCircles else { return }
        do {
            LeaderboardGroupStore.setSelectedGroup(id: betaDefaultGroupId, title: betaDefaultGroupName)
            _ = try await leaderboardSyncService.ensureFriendsShare()
        } catch {
            // Best-effort; failures will retry when user attempts to share.
        }
        #endif
    }

    func cachedLeaderboard(for key: LeaderboardCacheKey) -> [LeaderboardRow]? {
        guard let entry = leaderboardCache[key] else { return nil }
        guard Date().timeIntervalSince(entry.timestamp) < leaderboardCacheTTL else {
            leaderboardCache.removeValue(forKey: key)
            return nil
        }
        return entry.rows
    }
    
    func storeLeaderboard(_ rows: [LeaderboardRow], for key: LeaderboardCacheKey) {
        leaderboardCache[key] = LeaderboardCacheEntry(rows: rows, timestamp: Date())
        leaderboardCacheStore.save(leaderboardCache)
    }
    
    func invalidateLeaderboardCache() {
        leaderboardCache.removeAll(keepingCapacity: true)
        leaderboardCacheStore.clear()
    }
    
    func persistCircles() {
        circleStore.save(circles)
    }
    
    func ownerIdentifier() async -> String {
        if let profile = try? await mockService.ensureProfile(displayName: nil) {
            return profile.id
        }
        return "local_user"
    }
    
    func shouldShare(score: DailyGameScore) -> Bool {
        let game = Game.allAvailableGames.first(where: { $0.id == score.gameId })
        return socialSettingsService.shouldShare(score: score, game: game)
    }
    
    func normalizeScores(_ scores: [DailyGameScore]) async -> [DailyGameScore] {
        #if canImport(CloudKit)
        let ckUserId = self.isCloudKitAvailable ? await self.currentUserRecordName() : nil
        #else
        let ckUserId: String? = nil
        #endif
        return scores.map { s in
            let userId = ckUserId ?? s.userId
            let compositeId = "\(userId)|\(s.dateInt)|\(s.gameId.uuidString)"
            return DailyGameScore(
                id: compositeId,
                userId: userId,
                dateInt: s.dateInt,
                gameId: s.gameId,
                gameName: s.gameName,
                score: s.score,
                maxAttempts: s.maxAttempts,
                completed: s.completed
            )
        }
    }
    
    func sendNormalizedScores(_ scores: [DailyGameScore], dateUTC: Date) async throws {
        if self.isCloudKitAvailable {
            if let groupId = self.currentGroupIdentifier() {
                #if canImport(CloudKit)
                for score in scores {
                    try await leaderboardSyncService.publishDailyScore(groupId: groupId, score: score)
                }
                #endif
            }
        }
        try await mockService.publishDailyScores(dateUTC: dateUTC, scores: scores)
        invalidateLeaderboardCache()
    }
    
    func enqueuePending(scores: [DailyGameScore]) {
        guard !scores.isEmpty else { return }
        pendingScoreQueue.append(contentsOf: scores)
        pendingScoreStore.save(pendingScoreQueue)
    }
    
    func flushPendingScores() async {
        guard self.isCloudKitAvailable, !self.pendingScoreQueue.isEmpty else { return }
        let batch = pendingScoreQueue
        pendingScoreQueue.removeAll()
        pendingScoreStore.save(pendingScoreQueue)
        do {
            try await sendNormalizedScores(batch, dateUTC: Date())
        } catch {
            pendingScoreQueue.insert(contentsOf: batch, at: 0)
            pendingScoreStore.save(pendingScoreQueue)
        }
    }
}

// MARK: - Friend Discovery
extension CloudKitSocialService: FriendDiscoveryProviding {
    func discoverFriends(forceRefresh: Bool) async throws -> [DiscoveredFriend] {
        guard self.isCloudKitAvailable else { return [] }
        if !forceRefresh,
           let timestamp = discoveryCacheTimestamp,
           Date().timeIntervalSince(timestamp) < discoveryCacheTTL,
           !discoveredFriendsCache.isEmpty {
            return discoveredFriendsCache
        }
        #if canImport(CloudKit)
        // CKShare-based discovery: Extract friends from shares the user has access to
        // This replaces the deprecated CKDiscoverAllUserIdentitiesOperation
        // Note: We cannot query cloudkit.share directly (system record type)
        // Instead, we:
        // 1. Query LeaderboardGroup records from private database (groups user created)
        // 2. Fetch shares from known shared zones (groups user accepted)
        let container = CKContainer(identifier: CloudKitConfiguration.containerIdentifier)
        let privateDB = container.privateCloudDatabase
        let sharedDB = container.sharedCloudDatabase
        let myUserId = await currentUserRecordName()
        
        var allShares: [CKShare] = []
        
        // 1. Query LeaderboardGroup records from private database (groups user created)
        // Groups are stored in custom zones, so we need to fetch zones first
        let allZones: [CKRecordZone] = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CKRecordZone], Error>) in
            let fetchZonesOperation = CKFetchRecordZonesOperation.fetchAllRecordZonesOperation()
            var collectedZones: [CKRecordZone] = []
            var hasResumed = false
            
            fetchZonesOperation.perRecordZoneResultBlock = { zoneID, result in
                guard !hasResumed else { return }
                switch result {
                case .success(let zone):
                    collectedZones.append(zone)
                case .failure(let error):
                    hasResumed = true
                    continuation.resume(throwing: error)
                }
            }
            
            fetchZonesOperation.fetchRecordZonesResultBlock = { result in
                guard !hasResumed else { return }
                hasResumed = true
                switch result {
                case .success:
                    continuation.resume(returning: collectedZones)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            privateDB.add(fetchZonesOperation)
        }
        
        // Query LeaderboardGroup records from each zone
        var groupRecords: [CKRecord] = []
        for zone in allZones {
            // Only query zones that match our leaderboard zone naming pattern
            if zone.zoneID.zoneName.hasPrefix("leaderboard_") {
                let groupQuery = CKQuery(recordType: "LeaderboardGroup", predicate: NSPredicate(value: true))
                let groupOperation = CKQueryOperation(query: groupQuery)
                groupOperation.zoneID = zone.zoneID
                groupOperation.recordMatchedBlock = { _, result in
                    if case .success(let record) = result {
                        groupRecords.append(record)
                    }
                }
                
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    groupOperation.queryResultBlock = { result in
                        switch result {
                        case .success:
                            continuation.resume()
                        case .failure(_):
                            // Zone might not have records, continue
                            continuation.resume()
                        }
                    }
                    privateDB.add(groupOperation)
                }
            }
        }
        
        // Fetch shares from group records that have share references
        for groupRecord in groupRecords {
            if let shareReference = groupRecord.share {
                do {
                    let shareRecord = try await privateDB.record(for: shareReference.recordID)
                    if let share = shareRecord as? CKShare {
                        allShares.append(share)
                    }
                } catch {
                    // Share might not exist, continue
                }
            }
        }
        
        // 2. Fetch shares from known shared zones (shares user accepted)
        // We know which groups/zones the user is part of from LeaderboardGroupStore and circles
        var knownGroupIds: [UUID] = []
        if let activeGroupId = LeaderboardGroupStore.selectedGroupId {
            knownGroupIds.append(activeGroupId)
        }
        knownGroupIds.append(contentsOf: circles.map { $0.id })
        
        // Fetch share from each known group's shared zone
        for groupId in knownGroupIds {
            let circleZoneID = CKRecordZone.ID(zoneName: "leaderboard_\(groupId.uuidString)")
            let rootID = CKRecord.ID(recordName: "group_\(groupId.uuidString)", zoneID: circleZoneID)
            do {
                let root = try await sharedDB.record(for: rootID)
                if let shareReference = root.share {
                    let shareRecord = try await sharedDB.record(for: shareReference.recordID)
                    if let share = shareRecord as? CKShare {
                        // Avoid duplicates
                        if !allShares.contains(where: { $0.recordID == share.recordID }) {
                            allShares.append(share)
                        }
                    }
                }
            } catch {
                // Share might not exist yet, continue
            }
        }
        
        // Extract unique friends from all share participants
        var friendMap: [String: DiscoveredFriend] = [:]
        let formatter = PersonNameComponentsFormatter()
        
        for share in allShares {
            // Add owner
            if let ownerId = share.owner.userIdentity.userRecordID?.recordName,
               ownerId != myUserId {
                let name = share.owner.userIdentity.nameComponents.flatMap { formatter.string(from: $0) } ?? "Friend"
                let detail = share.owner.userIdentity.lookupInfo?.emailAddress ?? share.owner.userIdentity.lookupInfo?.phoneNumber ?? "iCloud user"
                friendMap[ownerId] = DiscoveredFriend(id: ownerId, displayName: name, detail: detail)
            }
            
            // Add participants
            for participant in share.participants {
                if let participantId = participant.userIdentity.userRecordID?.recordName,
                   participantId != myUserId {
                    let name = participant.userIdentity.nameComponents.flatMap { formatter.string(from: $0) } ?? "Friend"
                    let detail = participant.userIdentity.lookupInfo?.emailAddress ?? participant.userIdentity.lookupInfo?.phoneNumber ?? "iCloud user"
                    friendMap[participantId] = DiscoveredFriend(id: participantId, displayName: name, detail: detail)
                }
            }
        }
        
        let results = Array(friendMap.values)
        self.discoveredFriendsCache = results
        self.discoveryCacheTimestamp = Date()
        return results
        #else
        return []
        #endif
    }
    
    func addFriend(usingUsername username: String) async throws {
        let sanitized = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else {
            throw NSError(domain: "CloudKitSocialService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Username cannot be empty"])
        }
        
        // For now, username-based friend addition stores locally
        // In a full implementation, this would create a CloudKit Friendship record
        // or send a friend request via CloudKit
        let defaults = UserDefaults.standard
        let key = "social_manual_friends"
        var friends = defaults.stringArray(forKey: key) ?? []
        if !friends.contains(sanitized) {
            friends.append(sanitized)
            defaults.set(friends, forKey: key)
        }
        invalidateLeaderboardCache()
    }
    
// Note: displayName and detailDescription helpers removed - no longer needed
// CKShare-based discovery extracts names directly from share participants
}

// MARK: - Circle Management
extension CloudKitSocialService: CircleManaging {
    var activeCircleId: UUID? {
        LeaderboardGroupStore.selectedGroupId
    }
    
    func listCircles() async throws -> [SocialCircle] {
        circles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    func createCircle(name: String) async throws -> SocialCircle {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CircleError.invalidName }
        var circleId = UUID()
        #if canImport(CloudKit)
        if self.isCloudKitAvailable {
            do {
                let result = try await leaderboardSyncService.createGroup(title: trimmed)
                circleId = result.groupId
            } catch {
                // Fallback to local UUID if CloudKit group creation fails
            }
        }
        #endif
        let owner = await ownerIdentifier()
        let circle = SocialCircle(id: circleId, name: trimmed, createdBy: owner, members: [owner], createdAt: Date())
        circles.append(circle)
        persistCircles()
        LeaderboardGroupStore.setSelectedGroup(id: circle.id, title: circle.name)
        invalidateLeaderboardCache()
        return circle
    }
    
    func joinCircle(using code: String) async throws -> SocialCircle {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uuid = UUID(uuidString: trimmed) else { throw CircleError.invalidInviteCode }
        if let existing = circles.first(where: { $0.id == uuid }) {
            LeaderboardGroupStore.setSelectedGroup(id: existing.id, title: existing.name)
            return existing
        }
        let owner = await ownerIdentifier()
        let newCircle = SocialCircle(id: uuid, name: "Shared Circle", createdBy: owner, members: [owner], createdAt: Date())
        circles.append(newCircle)
        persistCircles()
        LeaderboardGroupStore.setSelectedGroup(id: newCircle.id, title: newCircle.name)
        return newCircle
    }
    
    func leaveCircle(id: UUID) async throws {
        circles.removeAll { $0.id == id }
        persistCircles()
        if LeaderboardGroupStore.selectedGroupId == id {
            LeaderboardGroupStore.clearSelectedGroup()
        }
        invalidateLeaderboardCache()
    }
    
    func selectCircle(id: UUID?) async {
        if let id {
            let title = circles.first(where: { $0.id == id })?.name
            LeaderboardGroupStore.setSelectedGroup(id: id, title: title)
        } else {
            LeaderboardGroupStore.clearSelectedGroup()
        }
        invalidateLeaderboardCache()
    }
}

enum CircleError: LocalizedError {
    case invalidName
    case invalidInviteCode
    
    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Please choose a circle name."
        case .invalidInviteCode:
            return "That invite code is invalid."
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
