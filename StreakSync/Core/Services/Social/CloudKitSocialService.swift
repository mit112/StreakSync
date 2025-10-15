//
//  CloudKitSocialService.swift
//  StreakSync
//
//  Real-time social features using CloudKit
//

import Foundation
import SwiftUI

@MainActor
final class CloudKitSocialService: SocialService {
    // For development without CloudKit entitlements, this service will always throw errors
    // and fall back to MockSocialService through HybridSocialService
    
    // MARK: - SocialService Protocol
    
    func ensureProfile(displayName: String?) async throws -> UserProfile {
        throw SocialServiceError.cloudKitUnavailable
    }
    
    func myProfile() async throws -> UserProfile {
        throw SocialServiceError.cloudKitUnavailable
    }
    
    func generateFriendCode() async throws -> String {
        throw SocialServiceError.cloudKitUnavailable
    }
    
    func addFriend(using code: String) async throws {
        throw SocialServiceError.cloudKitUnavailable
    }
    
    func listFriends() async throws -> [UserProfile] {
        throw SocialServiceError.cloudKitUnavailable
    }
    
    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws {
        throw SocialServiceError.cloudKitUnavailable
    }
    
    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow] {
        throw SocialServiceError.cloudKitUnavailable
    }
    
    // MARK: - Real-time Subscriptions
    
    func setupRealTimeSubscriptions() async {
        // No-op in development mode
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