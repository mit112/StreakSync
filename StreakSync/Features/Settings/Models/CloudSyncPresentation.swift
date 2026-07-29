//
//  CloudSyncPresentation.swift
//  StreakSync
//
//  Pure selector for whether cloud sync is actually available to this account
//

import Foundation

/// Anonymous accounts have no cloud sync at all, yet Data & Privacy rendered an enabled
/// toggle, a "Last synced" value, Sync Now, and Offline/Failed indicators for them — four
/// claims about a feature they do not have (DESIGN_AUDIT §4.6).
enum CloudSyncPresentation: Equatable {
    case signInRequired
    case available

    static func resolve(isAnonymous: Bool) -> Self {
        isAnonymous ? .signInRequired : .available
    }

    var showsSyncControls: Bool { self == .available }
    var showsSyncStatuses: Bool { self == .available }
}
