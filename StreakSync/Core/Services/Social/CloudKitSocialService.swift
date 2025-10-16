//
//  CloudKitSocialService.swift
//  StreakSync
//
//  Real-time social features using CloudKit
//

import Foundation
import SwiftUI
#if canImport(CloudKit)
import CloudKit
#endif

@MainActor
final class CloudKitSocialService: SocialService, @unchecked Sendable {
    // For development without CloudKit entitlements, this service will always throw errors
    // and fall back to MockSocialService through HybridSocialService
    
    // MARK: - SocialService Protocol
    
    func ensureProfile(displayName: String?) async throws -> UserProfile {
        #if canImport(CloudKit)
        // Minimal placeholder to keep compile safe; real code gated by entitlements
        // In environments where CloudKit is enabled, implement CRUD here.
        throw SocialServiceError.cloudKitUnavailable
        #else
        throw SocialServiceError.cloudKitUnavailable
        #endif
    }
    
    func myProfile() async throws -> UserProfile {
        #if canImport(CloudKit)
        throw SocialServiceError.cloudKitUnavailable
        #else
        throw SocialServiceError.cloudKitUnavailable
        #endif
    }
    
    func generateFriendCode() async throws -> String {
        #if canImport(CloudKit)
        throw SocialServiceError.cloudKitUnavailable
        #else
        throw SocialServiceError.cloudKitUnavailable
        #endif
    }
    
    func addFriend(using code: String) async throws {
        #if canImport(CloudKit)
        throw SocialServiceError.cloudKitUnavailable
        #else
        throw SocialServiceError.cloudKitUnavailable
        #endif
    }
    
    func listFriends() async throws -> [UserProfile] {
        #if canImport(CloudKit)
        throw SocialServiceError.cloudKitUnavailable
        #else
        throw SocialServiceError.cloudKitUnavailable
        #endif
    }
    
    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws {
        #if canImport(CloudKit)
        throw SocialServiceError.cloudKitUnavailable
        #else
        throw SocialServiceError.cloudKitUnavailable
        #endif
    }
    
    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow] {
        #if canImport(CloudKit)
        throw SocialServiceError.cloudKitUnavailable
        #else
        throw SocialServiceError.cloudKitUnavailable
        #endif
    }
    
    // MARK: - Real-time Subscriptions
    
    func setupRealTimeSubscriptions() async {
        #if canImport(CloudKit)
        // Set up CKDatabaseSubscription on DailyScore in Private DB (implementation when enabled)
        #endif
    }
}

// MARK: - Error Handling

enum SocialServiceError: Error, LocalizedError {
    case cloudKitUnavailable
    case profileNotFound
    case friendNotFound
    case invalidFriendCode
    
    var errorDescription: String? {
        switch self {
        case .cloudKitUnavailable:
            return "CloudKit is not available. Using local storage."
        case .profileNotFound:
            return "User profile not found."
        case .friendNotFound:
            return "Friend not found."
        case .invalidFriendCode:
            return "Invalid friend code."
        }
    }
}