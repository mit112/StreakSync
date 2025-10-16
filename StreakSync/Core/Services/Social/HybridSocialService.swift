//
//  HybridSocialService.swift
//  StreakSync
//
//  Hybrid social service that uses CloudKit when available, falls back to local storage
//

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
