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
    /// NOTE: Changed to new container due to Apple server-side association bug
    /// Original container "iCloud.com.mitsheth.StreakSync" had permission issues
    static let containerIdentifier = "iCloud.com.mitsheth.StreakSync2"
    
    /// The default container instance (available when CloudKit is enabled)
    // static var container: CKContainer {
    //     return CKContainer(identifier: containerIdentifier)
    // }
    
    // MARK: - Record Types
    
    /// CloudKit record types used in the app
    struct RecordTypes {
        // Note: UserProfile and FriendConnection are not currently used.
        // Social features use CKShare-based leaderboards instead (see LeaderboardSyncService).
        // These are kept for potential future direct friend connections.
        // static let userProfile = "UserProfile"
        // static let friendConnection = "FriendConnection"
        
        /// DailyScore records used in CKShare-based leaderboard groups
        static let dailyScore = "DailyScore"
    }
    
    // MARK: - Field Names
    
    // Note: UserProfile and FriendConnection field names are not currently used.
    // Social features use CKShare-based leaderboards instead (see LeaderboardSyncService).
    
    /// Field names for DailyScore records (used in CKShare-based leaderboard groups)
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
    
    Record Types Used:
    - DailyScore (Shared Database, via CKShare zones)
    
    Note: UserProfile and FriendConnection are not used.
    Social features use CKShare-based leaderboards instead.
    
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
