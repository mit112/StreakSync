//
//  CloudKitConfiguration.swift
//  StreakSync
//
//  CloudKit development configuration and setup guide
//

import Foundation

/// CloudKit configuration for development
struct CloudKitConfiguration {
    
    // MARK: - Container Configuration
    
    /// The CloudKit container identifier
    /// This should match your app's bundle identifier
    static let containerIdentifier = "iCloud.com.mitsheth.StreakSync"
    
    /// The default container instance (available when CloudKit is enabled)
    // static var container: CKContainer {
    //     return CKContainer(identifier: containerIdentifier)
    // }
    
    // MARK: - Record Types
    
    /// CloudKit record types used in the app
    struct RecordTypes {
        static let userProfile = "UserProfile"
        static let dailyScore = "DailyScore"
        static let friendConnection = "FriendConnection"
    }
    
    // MARK: - Field Names
    
    /// Field names for UserProfile records
    struct UserProfileFields {
        static let id = "id"
        static let displayName = "displayName"
        static let friendCode = "friendCode"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
    }
    
    /// Field names for DailyScore records
    struct DailyScoreFields {
        static let id = "id"
        static let userId = "userId"
        static let gameId = "gameId"
        static let dateInt = "dateInt"
        static let score = "score"
        static let maxAttempts = "maxAttempts"
        static let completed = "completed"
        static let publishedAt = "publishedAt"
    }
    
    /// Field names for FriendConnection records
    struct FriendConnectionFields {
        static let friendCode = "friendCode"
        static let addedAt = "addedAt"
    }
    
    // MARK: - Development Setup
    
    /// Check if CloudKit is properly configured (available when CloudKit is enabled)
    // static func checkConfiguration() async -> CloudKitStatus {
    //     do {
    //         let container = CKContainer.default()
    //         let status = try await container.accountStatus()
    //         
    //         switch status {
    //         case .available:
    //             return .available
    //         case .noAccount:
    //             return .noAccount
    //         case .restricted:
    //             return .restricted
    //         case .couldNotDetermine:
    //             return .unknown
    //         @unknown default:
    //             return .unknown
    //         }
    //     } catch {
    //         return .error(error)
    //     }
    // }
    
    // MARK: - Schema Setup
    
    /// Instructions for setting up CloudKit schema in development
    static let setupInstructions = """
    CloudKit Development Setup:
    
    1. Open Xcode and select your project
    2. Go to Signing & Capabilities
    3. Add CloudKit capability
    4. Select your development team
    5. CloudKit will automatically create the container
    
    Record Types to Create:
    - UserProfile (Private Database)
    - DailyScore (Private Database)  
    - FriendConnection (Private Database)
    
    The app will automatically create the schema when first run.
    No manual setup required for development!
    """
}

// MARK: - CloudKit Status

enum CloudKitStatus {
    case available
    case noAccount
    case restricted
    case unknown
    case error(Error)
    
    var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }
    
    var description: String {
        switch self {
        case .available:
            return "CloudKit is available and ready"
        case .noAccount:
            return "No iCloud account signed in"
        case .restricted:
            return "CloudKit access is restricted"
        case .unknown:
            return "CloudKit status unknown"
        case .error(let error):
            return "CloudKit error: \(error.localizedDescription)"
        }
    }
}
