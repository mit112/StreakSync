//
//  SocialService.swift
//  StreakSync
//
//  Provider-agnostic social layer for friends and leaderboards.
//

/*
 * SOCIALSERVICE - SOCIAL FEATURES PROTOCOL AND DATA MODELS
 * 
 * WHAT THIS FILE DOES:
 * This file defines the protocol and data models for social features like friends,
 * leaderboards, and competitive gaming. It's like a "social contract" that defines
 * how different social services (CloudKit, local storage, etc.) should behave.
 * Think of it as the "social architecture blueprint" that ensures all social
 * implementations provide consistent functionality for friends, leaderboards,
 * and competitive features.
 * 
 * WHY IT EXISTS:
 * The app needs social features but should work with different backends (CloudKit,
 * local storage, etc.). This protocol defines a common interface that all social
 * services must implement, ensuring consistent behavior regardless of the underlying
 * technology. It also defines the data models that represent users, scores, and
 * leaderboards.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This defines the social features architecture
 * - Provides consistent interface for all social service implementations
 * - Defines data models for users, scores, and leaderboards
 * - Enables flexible social backend switching (CloudKit, local, etc.)
 * - Ensures social features work consistently across different implementations
 * - Supports competitive gaming and social engagement
 * - Provides foundation for friends and leaderboard systems
 * 
 * WHAT IT REFERENCES:
 * - Foundation: For basic data types and protocols
 * - Codable: For data serialization and persistence
 * - Hashable: For data comparison and storage
 * - Identifiable: For SwiftUI list management
 * - Sendable: For thread safety in concurrent environments
 * 
 * WHAT REFERENCES IT:
 * - HybridSocialService: Implements this protocol with backend selection
 * - CloudKitSocialService: Implements this protocol with CloudKit backend
 * - MockSocialService: Implements this protocol with local storage
 * - Social features: Use these models and protocols for social functionality
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. PROTOCOL ENHANCEMENTS:
 *    - The current protocol is good but could be more comprehensive
 *    - Consider adding more social features (messaging, achievements sharing, etc.)
 *    - Add support for real-time updates and notifications
 *    - Implement more sophisticated social interactions
 * 
 * 2. DATA MODEL IMPROVEMENTS:
 *    - The current models are good but could be more sophisticated
 *    - Consider adding more user profile information
 *    - Add support for social statistics and analytics
 *    - Implement more detailed leaderboard metrics
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient data serialization
 *    - Add support for data compression and caching
 *    - Implement smart data synchronization
 * 
 * 4. TESTING IMPROVEMENTS:
 *    - Add comprehensive tests for social protocol compliance
 *    - Test different social service implementations
 *    - Add integration tests with real social backends
 *    - Test data model serialization and deserialization
 * 
 * 5. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for social protocol
 *    - Document the different social service implementations
 *    - Add examples of how to use social features
 *    - Create social features usage guidelines
 * 
 * 6. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new social features
 *    - Add support for custom social service implementations
 *    - Implement social feature plugins
 *    - Add support for third-party social integrations
 * 
 * 7. SECURITY IMPROVEMENTS:
 *    - The current security could be enhanced
 *    - Add support for user authentication and authorization
 *    - Implement data encryption and privacy protection
 *    - Add support for secure social interactions
 * 
 * 8. MONITORING AND OBSERVABILITY:
 *    - Add detailed logging for social interactions
 *    - Implement metrics for social feature usage
 *    - Add support for social debugging
 *    - Monitor social performance and reliability
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Protocols: Define contracts that types must follow
 * - Data models: Structures that represent information in the app
 * - Social features: Features that involve multiple users and interaction
 * - Competitive gaming: Features that let users compete with each other
 * - Leaderboards: Lists that show user rankings and scores
 * - Friends systems: Features that let users connect with each other
 * - Backend services: Services that handle data storage and processing
 * - Thread safety: Making sure code works correctly with multiple threads
 * - Data serialization: Converting data to and from storage formats
 * - Architecture patterns: Ways of organizing code for flexibility and maintainability
 */

import Foundation

// MARK: - Social Models
struct UserProfile: Identifiable, Codable, Hashable {
    let id: String            // Stable user identifier
    var displayName: String
    var friendCode: String
    var createdAt: Date
    var updatedAt: Date
}

struct DailyGameScore: Identifiable, Codable, Hashable {
    let id: String            // compositeKey: userId|yyyyMMdd|gameId
    let userId: String
    let dateInt: Int          // yyyyMMdd (UTC)
    let gameId: UUID
    let gameName: String
    let score: Int?
    let maxAttempts: Int
    let completed: Bool
}

struct LeaderboardRow: Identifiable, Codable, Hashable {
    let id: String            // userId
    let userId: String
    let displayName: String
    let totalPoints: Int
    let perGameBreakdown: [UUID: Int]
}

// MARK: - Social Service Protocol
protocol SocialService: Sendable {
    // Profile
    func ensureProfile(displayName: String?) async throws -> UserProfile
    func myProfile() async throws -> UserProfile
    
    // Friends
    func generateFriendCode() async throws -> String
    func addFriend(using code: String) async throws
    func listFriends() async throws -> [UserProfile]
    
    // Scores
    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws
    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow]
}

// MARK: - Helpers
extension Date {
    /// Returns an Int in the form yyyyMMdd in UTC
    var utcYYYYMMDD: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let comps = calendar.dateComponents([.year, .month, .day], from: self)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return y * 10_000 + m * 100 + d
    }
}


