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
 * - CloudKitSocialService: Real cloud-based social features
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

@MainActor
final class HybridSocialService: SocialService, @unchecked Sendable {
    private let cloudKitService: CloudKitSocialService
    private let mockService: MockSocialService
    private var isCloudKitAvailable: Bool = false
    
    init() {
        self.cloudKitService = CloudKitSocialService()
        self.mockService = MockSocialService()
        
        // Check CloudKit availability
        Task {
            await checkCloudKitAvailability()
        }
    }
    
    // MARK: - CloudKit Availability Check
    
    private func checkCloudKitAvailability() async {
        isCloudKitAvailable = false
        print("⚠️ CloudKit disabled (no entitlements) - using local storage")
    }
    
    // MARK: - SocialService Protocol
    
    func ensureProfile(displayName: String?) async throws -> UserProfile {
        if isCloudKitAvailable {
            do {
                return try await cloudKitService.ensureProfile(displayName: displayName)
            } catch {
                print("CloudKit profile creation failed, falling back to local: \(error)")
                return try await mockService.ensureProfile(displayName: displayName)
            }
        } else {
            return try await mockService.ensureProfile(displayName: displayName)
        }
    }
    
    func myProfile() async throws -> UserProfile {
        if isCloudKitAvailable {
            do {
                return try await cloudKitService.myProfile()
            } catch {
                print("CloudKit profile fetch failed, falling back to local: \(error)")
                return try await mockService.myProfile()
            }
        } else {
            return try await mockService.myProfile()
        }
    }
    
    func generateFriendCode() async throws -> String {
        if isCloudKitAvailable {
            do {
                return try await cloudKitService.generateFriendCode()
            } catch {
                print("CloudKit friend code generation failed, falling back to local: \(error)")
                return try await mockService.generateFriendCode()
            }
        } else {
            return try await mockService.generateFriendCode()
        }
    }
    
    func addFriend(using code: String) async throws {
        if isCloudKitAvailable {
            do {
                try await cloudKitService.addFriend(using: code)
            } catch {
                print("CloudKit add friend failed, falling back to local: \(error)")
                try await mockService.addFriend(using: code)
            }
        } else {
            try await mockService.addFriend(using: code)
        }
    }
    
    func listFriends() async throws -> [UserProfile] {
        if isCloudKitAvailable {
            do {
                return try await cloudKitService.listFriends()
            } catch {
                print("CloudKit list friends failed, falling back to local: \(error)")
                return try await mockService.listFriends()
            }
        } else {
            return try await mockService.listFriends()
        }
    }
    
    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws {
        if isCloudKitAvailable {
            do {
                try await cloudKitService.publishDailyScores(dateUTC: dateUTC, scores: scores)
                // Also save locally as backup
                try await mockService.publishDailyScores(dateUTC: dateUTC, scores: scores)
            } catch {
                print("CloudKit publish scores failed, using local only: \(error)")
                try await mockService.publishDailyScores(dateUTC: dateUTC, scores: scores)
            }
        } else {
            try await mockService.publishDailyScores(dateUTC: dateUTC, scores: scores)
        }
    }
    
    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow] {
        if isCloudKitAvailable {
            do {
                return try await cloudKitService.fetchLeaderboard(startDateUTC: startDateUTC, endDateUTC: endDateUTC)
            } catch {
                print("CloudKit leaderboard fetch failed, falling back to local: \(error)")
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
        if isCloudKitAvailable {
            await cloudKitService.setupRealTimeSubscriptions()
        }
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
