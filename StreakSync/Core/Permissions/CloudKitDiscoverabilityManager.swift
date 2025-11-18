//
//  CloudKitDiscoverabilityManager.swift
//  StreakSync
//
//  NOTE: CloudKit discoverability APIs were deprecated in iOS 17.0.
//  Friend discovery now uses CKShare-based discovery instead.
//  This file is kept for backwards compatibility but always returns .unavailable.
//

import Foundation

struct CloudKitDiscoverabilityManager {
    enum Status {
        case notDetermined
        case denied
        case granted
        case unavailable
    }
    
    /// Always returns .unavailable since discoverability APIs are deprecated.
    /// Friend discovery now uses CKShare-based discovery (see CloudKitSocialService).
    func currentStatus() async -> Status {
        return .unavailable
    }
    
    /// Always returns .unavailable since discoverability APIs are deprecated.
    /// Friend discovery now uses CKShare-based discovery (see CloudKitSocialService).
    func requestPermissionIfNeeded() async -> Status {
        return .unavailable
    }
}

